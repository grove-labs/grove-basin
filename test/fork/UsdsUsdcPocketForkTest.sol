// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }      from "src/GroveBasin.sol";
import { UsdsUsdcPocket }  from "src/pockets/UsdsUsdcPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

interface IFullRestrictionsLike {
    function updateMember(address token, address user, uint64 validUntil) external;
    function isMember(address token, address user) external view returns (bool isValid, uint64 validUntil);
}

interface IShareTokenLike {
    function balanceOf(address) external view returns (uint256);
    function hookDataOf(address) external view returns (bytes16);
}

abstract contract UsdsUsdcPocketForkTestBase is Test {

    address public owner      = makeAddr("owner");
    address public lp         = makeAddr("liquidityProvider");
    address public manager    = makeAddr("manager");
    address public groveProxy = makeAddr("groveProxy");

    GroveBasin       public groveBasin;
    UsdsUsdcPocket   public pocket;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    // Actual USDS PSM Wrapper on mainnet
    address public constant PSM = 0xA188EEC8F81263234dA3622A406892F3D630f98c;

    // JTRSY token and restrictions
    address public constant JTRSY_TOKEN       = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address public constant FULL_RESTRICTIONS = 0x8E680873b4C77e6088b4Ba0aBD59d100c3D224a4;

    IFullRestrictionsLike public fullRestrictions = IFullRestrictionsLike(FULL_RESTRICTIONS);

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1e27);

        // swapToken = USDS, collateralToken = USDC, creditToken = JTRSY
        groveBasin = new GroveBasin(
            owner,
            lp,
            Ethereum.USDS,
            Ethereum.USDC,
            JTRSY_TOKEN,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        // Add basin to JTRSY allowlist
        _addToJTRSYAllowlist(address(groveBasin));

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            Ethereum.USDC,
            Ethereum.USDS,
            PSM,
            groveProxy
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        groveBasin.setPocket(address(pocket));
        vm.stopPrank();
    }

    function _addToJTRSYAllowlist(address account) internal {
        // Give ourselves ward access on the FullRestrictions hook to call updateMember.
        // Storage slot 0 is the `wards` mapping in the Auth base contract.
        vm.store(
            FULL_RESTRICTIONS,
            keccak256(abi.encode(address(this), uint256(0))),
            bytes32(uint256(1))
        );
        fullRestrictions.updateMember(JTRSY_TOKEN, account, type(uint64).max);
    }

    function _findBalanceSlot(address account) internal returns (bytes32) {
        // Probe storage to find the slot that controls balanceOf(account)
        vm.record();
        IShareTokenLike(JTRSY_TOKEN).balanceOf(account);
        (bytes32[] memory reads,) = vm.accesses(JTRSY_TOKEN);
        require(reads.length > 0, "Could not find balance slot");
        return reads[0];
    }

    function _getBlock() internal pure virtual returns (uint256) {
        return 24_522_338;
    }

    function _deposit(address asset, address user, uint256 amount) internal virtual {
        address lp_ = groveBasin.liquidityProvider();
        vm.startPrank(lp_);
        deal(asset, lp_, amount);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** Deployment tests                                                                       ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_Deployment is UsdsUsdcPocketForkTestBase {

    function test_deployment() public view {
        assertEq(pocket.basin(),         address(groveBasin));
        assertEq(address(pocket.usdc()), Ethereum.USDC);
        assertEq(address(pocket.usds()), Ethereum.USDS);
        assertEq(pocket.psm(),           PSM);
        assertEq(groveBasin.pocket(),    address(pocket));
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity USDC tests                                                               ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_DrawLiquidityUsdc is UsdsUsdcPocketForkTestBase {

    function test_withdrawLiquidity_usdc_swapsUsdsForUsdc() public {
        deal(Ethereum.USDC, address(pocket), 0);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDC);

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 1000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 9000e18);
    }

    function test_withdrawLiquidity_usdc_existingBalancePartialSwap() public {
        deal(Ethereum.USDC, address(pocket), 400e6);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDC);

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 1000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 9400e18);
    }

    function test_withdrawLiquidity_usdc_fullBalanceNoSwap() public {
        deal(Ethereum.USDC, address(pocket), 5000e6);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDC);

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 5000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 10_000e18);
    }

}

/**********************************************************************************************/
/*** setPocket migration tests                                                              ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_SetPocket is UsdsUsdcPocketForkTestBase {

    function test_setPocket_withdrawsAllAssetsToNewPocket() public {
        deal(Ethereum.USDS, address(pocket), 5000e18);
        deal(Ethereum.USDC, address(pocket), 1000e6);

        UsdsUsdcPocket pocket2 = new UsdsUsdcPocket(
            address(groveBasin),
            Ethereum.USDC,
            Ethereum.USDS,
            PSM,
            groveProxy
        );

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        // Old pocket should have withdrawn swapToken (USDS) to the basin
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 0);

        // USDC remains in the pocket since it's not the swapToken
        // Basin only withdraws swapToken on setPocket
        assertGt(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 0);

        assertEq(groveBasin.pocket(), address(pocket2));
    }

}

/**********************************************************************************************/
/*** End-to-end swap tests                                                                  ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_SwapE2E is UsdsUsdcPocketForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        address lp_ = groveBasin.liquidityProvider();

        // Do initial deposit first
        vm.startPrank(lp_);
        deal(Ethereum.USDC, lp_, 100_000e6);
        SafeERC20.safeApprove(IERC20(Ethereum.USDC), address(groveBasin), 100_000e6);
        groveBasin.depositInitial(Ethereum.USDC, 100_000e6);
        vm.stopPrank();

        // Add LP addresses to JTRSY allowlist (must be done outside of prank)
        _addToJTRSYAllowlist(lp_);
        _addToJTRSYAllowlist(swapper);
        _addToJTRSYAllowlist(receiver);

        // Deposit collateralToken (USDC) and creditToken (JTRSY)
        _deposit(Ethereum.USDC, lp_, 100_000e6);
        _deposit(JTRSY_TOKEN, lp_, 100_000e6);

        // Give pocket USDS so it can provide liquidity for swaps
        deal(Ethereum.USDS, address(pocket), 100_000e18);
    }

    function test_swapExactIn_creditToSwapToken_e2e() public {
        // swapToken is now USDS, so swap JTRSY -> USDS
        uint256 amountIn = 1000e6;
        _dealJTRSY(swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            JTRSY_TOKEN,
            Ethereum.USDS,
            amountIn,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        // With 1.00 JTRSY rate, 1000e6 JTRSY should give 1000e18 USDS
        assertEq(amountOut, 1000e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), 1000e18);
    }

    function test_swapExactIn_drawsLiquidityFromPsmWhenPocketLacksUsdc() public {
        deal(Ethereum.USDC, address(pocket), 0);
        deal(Ethereum.USDS, address(pocket), 100_000e18);

        // Swap JTRSY -> USDS
        uint256 amountIn = 1000e6;
        _dealJTRSY(swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            JTRSY_TOKEN,
            Ethereum.USDS,
            amountIn,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        // With 1.00 JTRSY rate, 1000e6 JTRSY should give 1000e18 USDS
        assertEq(amountOut, 1000e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), 1000e18);
    }

    function _deposit(address asset, address user, uint256 amount) internal override {
        address lp_ = groveBasin.liquidityProvider();
        if (asset == JTRSY_TOKEN) {
            _dealJTRSY(lp_, amount);
        } else {
            deal(asset, lp_, amount);
        }
        vm.startPrank(lp_);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

    function _dealJTRSY(address to, uint256 amount) internal {
        require(amount <= type(uint128).max, "JTRSY balance overflow");

        _addToJTRSYAllowlist(to);

        // Find the packed storage slot by probing balanceOf
        IShareTokenLike token = IShareTokenLike(JTRSY_TOKEN);
        bytes16 hookData      = token.hookDataOf(to);
        bytes32 slot          = _findBalanceSlot(to);

        // Write combined hookData (upper 128 bits) + balance (lower 128 bits)
        bytes32 packed = bytes32(uint256(uint128(hookData)) << 128 | uint256(amount));
        vm.store(JTRSY_TOKEN, slot, packed);

        assertEq(token.balanceOf(to), amount);
    }

}
