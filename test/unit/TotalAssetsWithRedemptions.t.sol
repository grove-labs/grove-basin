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

        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault.__setPermissioned(predictedRedeemer, true);

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();
    }

    function test_totalAssetsWithRedemptions_noRedemptions() public {
        collateralToken.mint(address(groveBasin), 1e18);
        swapToken.mint(address(pocket), 1e6);
        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssetsWithRedemptions(), groveBasin.totalAssets());
    }

    function test_totalAssetsWithRedemptions_withPendingRedemption() public {
        creditToken.mint(address(groveBasin), 1000e18);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        // creditToken rate is 1.25, so 1000e18 credit tokens = 1250e18 value
        assertEq(totalAssetsBefore, 1250e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        // totalAssets drops because credit tokens left the basin
        assertEq(groveBasin.totalAssets(), 0);

        // totalAssetsWithRedemptions includes the pending redemption value
        assertEq(groveBasin.totalAssetsWithRedemptions(), 1250e18);
    }

    function test_totalAssetsWithRedemptions_partialRedemption() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        // 600e18 credit tokens still in basin = 750e18 value
        // 400e18 credit tokens pending = 500e18 value
        assertEq(groveBasin.totalAssets(),                750e18);
        assertEq(groveBasin.totalAssetsWithRedemptions(), 1250e18);
    }

    function test_totalAssetsWithRedemptions_afterCompleteRedeem() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.totalAssetsWithRedemptions(), 1250e18);

        // Complete the redemption - collateral tokens come back
        collateralToken.mint(address(vault),         1000e18);
        groveBasin.completeRedeem(address(redeemer), 1000e18);

        // redeemedCreditTokenBalance decremented, collateral received
        assertEq(groveBasin.redeemedCreditTokenBalance(), 0);
        assertEq(groveBasin.totalAssets(), groveBasin.totalAssetsWithRedemptions());
    }

    function test_totalAssetsWithRedemptions_multipleInitiateRedeems() public {
        creditToken.mint(address(groveBasin), 2000e18);

        vm.startPrank(owner);
        groveBasin.initiateRedeem(address(redeemer), 500e18);
        groveBasin.initiateRedeem(address(redeemer), 300e18);
        vm.stopPrank();

        // 1200e18 credit in basin = 1500e18 value
        // 800e18 credit pending = 1000e18 value
        assertEq(groveBasin.totalAssets(),                1500e18);
        assertEq(groveBasin.totalAssetsWithRedemptions(), 2500e18);
        assertEq(groveBasin.redeemedCreditTokenBalance(), 800e18);
    }

    function test_totalAssetsWithRedemptions_conversionRateChange() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        // At rate 1.25: pending value = 1250e18
        assertEq(groveBasin.totalAssetsWithRedemptions(), 1250e18);

        // Rate increases to 1.5
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.totalAssetsWithRedemptions(), 1500e18);

        // Rate decreases to 0.8
        mockCreditTokenRateProvider.__setConversionRate(0.8e27);

        assertEq(groveBasin.totalAssetsWithRedemptions(), 800e18);
    }

    function test_totalAssetsWithRedemptions_withAllAssetTypes() public {
        collateralToken.mint(address(groveBasin), 100e18);
        swapToken.mint(address(pocket), 200e6);
        creditToken.mint(address(groveBasin), 1000e18);

        // collateral: 100e18, swap: 200e18, credit: 1250e18
        assertEq(groveBasin.totalAssets(), 1550e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        // totalAssets: 100e18 + 200e18 + 750e18 = 1050e18
        assertEq(groveBasin.totalAssets(), 1050e18);

        // totalAssetsWithRedemptions: 1050e18 + 500e18 = 1550e18
        assertEq(groveBasin.totalAssetsWithRedemptions(), 1550e18);
    }

    function test_totalAssetsWithRedemptions_partialComplete() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.redeemedCreditTokenBalance(), 1000e18);

        // Complete only 600e18
        collateralToken.mint(address(vault), 600e18);
        groveBasin.completeRedeem(address(redeemer), 600e18);

        assertEq(groveBasin.redeemedCreditTokenBalance(), 400e18);

        // totalAssets has 600e18 collateral from completed redeem
        assertEq(groveBasin.totalAssets(), 600e18);

        // totalAssetsWithRedemptions: 600e18 + 400e18 * 1.25 = 1100e18
        assertEq(groveBasin.totalAssetsWithRedemptions(), 1100e18);
    }

    function testFuzz_totalAssetsWithRedemptions(
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

        uint256 expectedTotalAssets = collateralAmount
            + (swapAmount * 1e12)
            + ((creditAmount - redeemAmount) * conversionRate / 1e27);

        uint256 expectedWithRedemptions = expectedTotalAssets
            + (redeemAmount * conversionRate / 1e27);

        assertEq(groveBasin.totalAssets(),                expectedTotalAssets);
        assertEq(groveBasin.totalAssetsWithRedemptions(), expectedWithRedemptions);
    }

}
