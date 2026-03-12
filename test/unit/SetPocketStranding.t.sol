// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { IGroveBasinPocket }   from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

/**********************************************************************************************/
/*** Mock pocket that simulates a paused external protocol                                  ***/
/**********************************************************************************************/

contract MockRevertingPocket is IGroveBasinPocket {

    address public override immutable basin;

    MockERC20 public immutable swapToken;
    MockERC20 public immutable yieldToken;

    bool public withdrawReverts;

    constructor(address basin_, address swapToken_, address yieldToken_) {
        basin     = basin_;
        swapToken = MockERC20(swapToken_);
        yieldToken = MockERC20(yieldToken_);

        // Approve basin for max so transferFrom works
        MockERC20(swapToken_).approve(basin_, type(uint256).max);
    }

    function setWithdrawReverts(bool reverts_) external {
        withdrawReverts = reverts_;
    }

    function depositLiquidity(uint256, address) external pure override returns (uint256) {
        return 0;
    }

    function withdrawLiquidity(uint256, address) external view override returns (uint256) {
        if (withdrawReverts) {
            revert("MockRevertingPocket/protocol-paused");
        }
        return 0;
    }

    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(swapToken)) {
            // Available balance includes both idle swapToken AND yield tokens
            // (converted to swapToken equivalent, like real pockets do)
            return swapToken.balanceOf(address(this))
                + yieldToken.balanceOf(address(this));
        }
        return 0;
    }

}

/**********************************************************************************************/
/*** Pocket that properly withdraws (converts yield to swap token)                          ***/
/**********************************************************************************************/

contract MockWorkingPocket is IGroveBasinPocket {

    address public override immutable basin;

    MockERC20 public immutable swapToken;
    MockERC20 public immutable yieldToken;

    constructor(address basin_, address swapToken_, address yieldToken_) {
        basin      = basin_;
        swapToken  = MockERC20(swapToken_);
        yieldToken = MockERC20(yieldToken_);

        // Approve basin for max so transferFrom works
        MockERC20(swapToken_).approve(basin_, type(uint256).max);
    }

    function depositLiquidity(uint256, address) external pure override returns (uint256) {
        return 0;
    }

    function withdrawLiquidity(uint256, address) external override returns (uint256) {
        // Simulate converting all yield tokens to swap tokens (like a real pocket does)
        uint256 yieldBal = yieldToken.balanceOf(address(this));
        if (yieldBal > 0) {
            // Burn yield tokens and mint equivalent swap tokens (1:1 for simplicity)
            yieldToken.burn(address(this), yieldBal);
            swapToken.mint(address(this), yieldBal);
        }
        return swapToken.balanceOf(address(this));
    }

    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(swapToken)) {
            return swapToken.balanceOf(address(this))
                + yieldToken.balanceOf(address(this));
        }
        return 0;
    }

}

/**********************************************************************************************/
/*** Test: setPocket strands yield tokens when external protocol is paused                  ***/
/**********************************************************************************************/

contract SetPocketStrandingTests is Test {

    address public owner = makeAddr("owner");

    GroveBasin public groveBasin;

    MockERC20 public swapToken;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;
    MockERC20 public yieldToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockRevertingPocket public pocket1;
    MockWorkingPocket   public pocket2;

    function setUp() public {
        swapToken       = new MockERC20("USDC", "USDC", 6);
        collateralToken = new MockERC20("USDT", "USDT", 6);
        creditToken     = new MockERC20("CREDIT", "CREDIT", 18);
        yieldToken      = new MockERC20("aUSDC", "aUSDC", 6);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        pocket1 = new MockRevertingPocket(
            address(groveBasin),
            address(swapToken),
            address(yieldToken)
        );

        pocket2 = new MockWorkingPocket(
            address(groveBasin),
            address(swapToken),
            address(yieldToken)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket1));
        vm.stopPrank();
    }

    function test_setPocket_strandsYieldTokens_whenProtocolPaused() public {
        // Simulate: pocket1 has 500 idle USDC + 1000 yield tokens (aUSDC)
        swapToken.mint(address(pocket1), 500e6);
        yieldToken.mint(address(pocket1), 1000e6);

        // Pause the external protocol so withdrawLiquidity reverts
        pocket1.setWithdrawReverts(true);

        // setPocket should revert because yield tokens would be stranded
        vm.prank(owner);
        vm.expectRevert("GroveBasin/pocket-funds-stranded");
        groveBasin.setPocket(address(pocket2));
    }

    function test_setPocket_strandsYieldTokens_noIdleSwapTokens() public {
        // Pocket1 has only yield tokens (no idle swap tokens)
        yieldToken.mint(address(pocket1), 1000e6);

        // Pause the external protocol
        pocket1.setWithdrawReverts(true);

        // setPocket should revert because yield tokens would be stranded
        vm.prank(owner);
        vm.expectRevert("GroveBasin/pocket-funds-stranded");
        groveBasin.setPocket(address(pocket2));
    }

    function test_setPocket_succeedsWhenNoFundsInPocket() public {
        // Empty pocket — no yield tokens, no swap tokens
        // Protocol is paused but doesn't matter since there's nothing to strand
        pocket1.setWithdrawReverts(true);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(groveBasin.pocket(), address(pocket2));
    }

    function test_setPocket_succeedsWhenOnlyIdleSwapTokens() public {
        // Pocket has only idle swap tokens, no yield tokens
        swapToken.mint(address(pocket1), 500e6);

        // Protocol is paused but all funds are idle swap tokens (no yield to strand)
        pocket1.setWithdrawReverts(true);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(groveBasin.pocket(), address(pocket2));
        // Idle swap tokens should have been transferred
        assertEq(swapToken.balanceOf(address(pocket1)), 0);
        assertEq(swapToken.balanceOf(address(pocket2)), 500e6);
    }

    function test_setPocket_succeedsWhenWithdrawalFullyCompletes() public {
        // Set pocket to a working pocket that properly converts yield tokens
        MockWorkingPocket workingPocket1 = new MockWorkingPocket(
            address(groveBasin),
            address(swapToken),
            address(yieldToken)
        );
        MockWorkingPocket workingPocket2 = new MockWorkingPocket(
            address(groveBasin),
            address(swapToken),
            address(yieldToken)
        );

        vm.prank(owner);
        groveBasin.setPocket(address(workingPocket1));

        // Fund the working pocket with idle swap tokens + yield tokens
        swapToken.mint(address(workingPocket1), 500e6);
        yieldToken.mint(address(workingPocket1), 1000e6);

        // setPocket should succeed: withdrawLiquidity converts yield → swap, then transfers
        vm.prank(owner);
        groveBasin.setPocket(address(workingPocket2));

        assertEq(groveBasin.pocket(), address(workingPocket2));
        // All funds should be in workingPocket2 as swap tokens (1500 total)
        assertEq(swapToken.balanceOf(address(workingPocket1)), 0);
        assertEq(yieldToken.balanceOf(address(workingPocket1)), 0);
        assertEq(swapToken.balanceOf(address(workingPocket2)), 1500e6);
    }

}
