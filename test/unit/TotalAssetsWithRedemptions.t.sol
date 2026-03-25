// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer }  from "src/JTRSYTokenRedeemer.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockAsyncVault }     from "test/mocks/MockAsyncVault.sol";

contract TotalAssetsWithRedemptionsTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();
    }

    function test_totalAssets_noRedemptions() public {
        collateralToken.mint(address(groveBasin), 1e18);
        swapToken.mint(address(pocket), 1e6);
        creditToken.mint(address(groveBasin), 1e18);

        uint256 totalAssets = groveBasin.totalAssets();

        // 1e18 collateral + 1e18 swap (1e6 * 1e12) + 1.25e18 credit
        assertEq(totalAssets, 3.25e18);
    }

    function test_totalAssets_withPendingRedemption() public {
        creditToken.mint(address(groveBasin), 1000e18);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        // creditToken rate is 1.25, so 1000e18 credit tokens = 1250e18 value
        assertEq(totalAssetsBefore, 1250e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        // pendingCollateralTokenBalance = 1250e18 (converted from credit to collateral)
        assertEq(groveBasin.pendingCollateralTokenBalance(), 1250e18);

        // totalAssets includes pending collateral value, credit tokens left the basin
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_partialRedemption() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        // pendingCollateral = 400 * 1.25 = 500e18
        assertEq(groveBasin.pendingCollateralTokenBalance(), 500e18);

        // 600e18 credit tokens still in basin = 750e18 value
        // 500e18 pending collateral = 500e18 value
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_afterCompleteRedeem() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.totalAssets(), 1250e18);

        // Complete the redemption - vault returns 1000e18 collateral (1:1 with credit amount)
        collateralToken.mint(address(vault), 1000e18);
        vault.__setMaxWithdraw(1000e18);
        groveBasin.completeRedeem(address(redeemer), 1000e18, 1000e18);

        // pendingCollateral = 1250e18 - 1000e18 received = 250e18
        assertEq(groveBasin.pendingCollateralTokenBalance(), 250e18);

        // totalAssets = 1000e18 actual collateral + 250e18 pending = 1250e18
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_multipleInitiateRedeems() public {
        creditToken.mint(address(groveBasin), 2000e18);

        vm.startPrank(owner);
        groveBasin.initiateRedeem(address(redeemer), 500e18);
        groveBasin.initiateRedeem(address(redeemer), 300e18);
        vm.stopPrank();

        // pendingCollateral = 625e18 + 375e18 = 1000e18
        assertEq(groveBasin.pendingCollateralTokenBalance(), 1000e18);

        // 1200e18 credit in basin = 1500e18 value + 1000e18 pending collateral
        assertEq(groveBasin.totalAssets(), 2500e18);
    }

    function test_totalAssets_conversionRateChange() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        // pendingCollateral = 1250e18 (locked in at initiation rate)
        assertEq(groveBasin.pendingCollateralTokenBalance(), 1250e18);
        assertEq(groveBasin.totalAssets(), 1250e18);

        // Credit rate changes don't affect pending collateral (already converted)
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);
        assertEq(groveBasin.pendingCollateralTokenBalance(), 1250e18);
        assertEq(groveBasin.totalAssets(), 1250e18);

        // Collateral rate changes DO affect the USD value of pending collateral
        mockCollateralTokenRateProvider.__setConversionRate(2e27);
        assertEq(groveBasin.totalAssets(), 2500e18);

        mockCollateralTokenRateProvider.__setConversionRate(0.5e27);
        assertEq(groveBasin.totalAssets(), 625e18);
    }

    function test_totalAssets_withAllAssetTypes() public {
        collateralToken.mint(address(groveBasin), 100e18);
        swapToken.mint(address(pocket), 200e6);
        creditToken.mint(address(groveBasin), 1000e18);

        // collateral: 100e18, swap: 200e18, credit: 1250e18
        assertEq(groveBasin.totalAssets(), 1550e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        // pendingCollateral = 500e18
        // totalAssets: (100e18 + 500e18) collateral + 200e18 swap + 750e18 credit = 1550e18
        assertEq(groveBasin.totalAssets(), 1550e18);
    }

    function test_totalAssets_partialComplete() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.pendingCollateralTokenBalance(), 1250e18);

        // Complete only 600e18 credit tokens -> vault returns 600e18 collateral
        collateralToken.mint(address(vault), 600e18);
        vault.__setMaxWithdraw(600e18);
        groveBasin.completeRedeem(address(redeemer), 600e18, 600e18);

        // pendingCollateral = 1250e18 - 600e18 = 650e18
        assertEq(groveBasin.pendingCollateralTokenBalance(), 650e18);

        // totalAssets = 600e18 actual collateral + 650e18 pending = 1250e18
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function testFuzz_totalAssets(
        uint256 collateralAmount,
        uint256 swapAmount,
        uint256 creditAmount,
        uint256 redeemAmount,
        uint256 conversionRate
    ) public {
        collateralAmount = _bound(collateralAmount, 0,         COLLATERAL_TOKEN_MAX);
        swapAmount       = _bound(swapAmount,       0,         SWAP_TOKEN_MAX);
        creditAmount     = _bound(creditAmount,     0,         CREDIT_TOKEN_MAX);
        conversionRate   = _bound(conversionRate,   0.0001e27, 1000e27);
        redeemAmount     = _bound(redeemAmount,     0,         creditAmount);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        collateralToken.mint(address(groveBasin), collateralAmount);
        swapToken.mint(address(pocket), swapAmount);
        creditToken.mint(address(groveBasin), creditAmount);

        if (redeemAmount > 0) {
            vm.prank(owner);
            groveBasin.initiateRedeem(address(redeemer), redeemAmount);
        }

        // pendingCollateral = redeemAmount * conversionRate / 1e27 (collateral rate is 1e27)
        uint256 pendingCollateral = redeemAmount * conversionRate / 1e27;

        uint256 expectedTotalAssets = collateralAmount
            + pendingCollateral
            + (swapAmount * 1e12)
            + ((creditAmount - redeemAmount) * conversionRate / 1e27);

        assertEq(groveBasin.totalAssets(), expectedTotalAssets);
    }

}
