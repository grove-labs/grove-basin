// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { GroveBasinPocket }  from "src/GroveBasinPocket.sol";

import { GroveBasinTestBase }    from "test/GroveBasinTestBase.sol";
import { MockGroveBasinPocket }  from "test/mocks/MockGroveBasinPocket.sol";
import { MockRateProvider }      from "test/mocks/MockRateProvider.sol";
import { MockPSM }               from "test/mocks/MockPSM.sol";
import { MockAaveV3Pool }        from "test/mocks/MockAaveV3Pool.sol";

contract GroveBasinSetPocketFailureTests is GroveBasinTestBase {

    function test_setPocket_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        groveBasin.setPocket(address(1));
    }

    function test_setPocket_invalidPocket() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/invalid-pocket");
        groveBasin.setPocket(address(0));
    }

    function test_setPocket_samePocket() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/same-pocket");
        groveBasin.setPocket(address(groveBasin));
    }

    function test_setPocket_notContract() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/pocket-not-contract");
        groveBasin.setPocket(makeAddr("eoa"));
    }

    // NOTE: In practice this won't happen because pockets will infinite approve GroveBasin
    function test_setPocket_insufficientAllowanceBoundary() public {
        MockGroveBasinPocket pocket1 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));
        MockGroveBasinPocket pocket2 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        // Override the max approval with a limited one
        vm.prank(address(pocket1));
        swapToken.approve(address(groveBasin), 1_000_000e6);

        deal(address(swapToken), address(pocket1), 1_000_000e6 + 1);

        vm.prank(owner);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.setPocket(address(pocket2));

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));
    }

}

contract GroveBasinSetPocketSuccessTests is GroveBasinTestBase {

    MockGroveBasinPocket pocket1;
    MockGroveBasinPocket pocket2;

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function setUp() public override {
        super.setUp();
        pocket1 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));
        pocket2 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));
    }

    function test_setPocket_pocketIsGroveBasin() public {
        deal(address(swapToken), address(groveBasin), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(groveBasin)), 1_000_000e6);
        assertEq(swapToken.balanceOf(address(pocket1)),    0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(groveBasin));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(groveBasin), address(pocket1), 1_000_000e6);
        groveBasin.setPocket(address(pocket1));

        assertEq(swapToken.balanceOf(address(groveBasin)), 0);
        assertEq(swapToken.balanceOf(address(pocket1)),    1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket1));
    }

    function test_setPocket_pocketIsNotGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(pocket1)), 1_000_000e6);
        assertEq(swapToken.balanceOf(address(pocket2)), 0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket1));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(pocket1), address(pocket2), 1_000_000e6);
        groveBasin.setPocket(address(pocket2));

        assertEq(swapToken.balanceOf(address(pocket1)), 0);
        assertEq(swapToken.balanceOf(address(pocket2)), 1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket2));
    }

    function test_setPocket_valueStaysConstant() public {
        _deposit(address(swapToken),   owner, 1_000_000e6);
        _deposit(address(collateralToken),  owner, 1_000_000e18);
        _deposit(address(creditToken), owner, 800_000e18);

        assertEq(groveBasin.totalAssets(), 3_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        assertEq(groveBasin.totalAssets(), 3_000_000e18);
    }

}

contract GroveBasinSetPocketYieldDeployedTests is Test {

    address public owner = makeAddr("owner");

    GroveBasin       public groveBasin;
    GroveBasinPocket public pocket1;
    GroveBasinPocket public pocket2;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public usdt;
    MockERC20 public aUsdt;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM        public psm;
    MockAaveV3Pool public aaveV3Pool;

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function setUp() public {
        usds        = new MockERC20("USDS",   "USDS",   18);
        usdc        = new MockERC20("USDC",   "USDC",   6);
        usdt        = new MockERC20("USDT",   "USDT",   6);
        aUsdt       = new MockERC20("aUSDT",  "aUSDT",  6);
        creditToken = new MockERC20("CREDIT", "CREDIT", 18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(usdc),
            address(usdt),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        psm        = new MockPSM(address(usds), address(usdc));
        aaveV3Pool = new MockAaveV3Pool(address(aUsdt), address(usdt));

        usds.mint(address(psm), 1_000_000_000e18);
        usdc.mint(address(psm), 1_000_000_000e6);
        usdt.mint(address(aaveV3Pool), 1_000_000_000e6);
        aUsdt.mint(address(aaveV3Pool), 1_000_000_000e6);

        pocket1 = new GroveBasinPocket(
            address(groveBasin),
            owner,
            address(usdc),
            address(usdt),
            address(usds),
            address(aUsdt),
            address(psm),
            address(aaveV3Pool)
        );

        pocket2 = new GroveBasinPocket(
            address(groveBasin),
            owner,
            address(usdc),
            address(usdt),
            address(usds),
            address(aUsdt),
            address(psm),
            address(aaveV3Pool)
        );

        vm.prank(owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));
    }

    function test_setPocket_swapTokenFullyDeployedToYield() public {
        uint256 depositAmount = 1_000_000e6;

        // Deposit USDC into basin - pocket deploys it to USDS via PSM
        usdc.mint(owner, depositAmount);
        vm.startPrank(owner);
        usdc.approve(address(groveBasin), depositAmount);
        groveBasin.deposit(address(usdc), owner, depositAmount);
        vm.stopPrank();

        // Verify USDC is fully deployed: pocket holds USDS, not USDC
        assertEq(usdc.balanceOf(address(pocket1)), 0);
        assertGt(usds.balanceOf(address(pocket1)), 0);

        uint256 totalAssetsBefore = groveBasin.totalAssets();
        assertEq(totalAssetsBefore, 1_000_000e18);

        // setPocket should transfer the full value to pocket2
        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        // After setPocket, totalAssets should be preserved
        assertEq(groveBasin.totalAssets(), totalAssetsBefore);

        // The new pocket should have the full USDC value
        assertGe(usdc.balanceOf(address(pocket2)), depositAmount);
    }

}
