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

        assertEq(groveBasin.redeemedCreditTokenBalance(), 1000e18);

        // totalAssets includes redeemed credit token value, credit tokens left the basin
        // redeemedCreditTokenBalance (1000e18) * 1.25 rate = 1250e18
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_partialRedemption() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        assertEq(groveBasin.redeemedCreditTokenBalance(), 400e18);

        // 600e18 credit tokens still in basin + 400e18 redeemed = 1000e18 total credit
        // 1000e18 * 1.25 = 1250e18
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_afterCompleteRedeem() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.totalAssets(), 1250e18);

        // Complete the redemption - vault returns 1000e18 collateral
        collateralToken.mint(address(vault), 1000e18);
        vault.__setMaxWithdraw(1000e18);
        groveBasin.completeRedeem(address(redeemer), 1000e18, 1000e18);

        assertEq(groveBasin.redeemedCreditTokenBalance(), 0);

        // totalAssets = 1000e18 actual collateral (at 1:1 rate)
        assertEq(groveBasin.totalAssets(), 1000e18);
    }

    function test_totalAssets_multipleInitiateRedeems() public {
        creditToken.mint(address(groveBasin), 2000e18);

        vm.startPrank(owner);
        groveBasin.initiateRedeem(address(redeemer), 500e18);
        groveBasin.initiateRedeem(address(redeemer), 300e18);
        vm.stopPrank();

        assertEq(groveBasin.redeemedCreditTokenBalance(), 800e18);

        // 1200e18 credit in basin + 800e18 redeemed = 2000e18 total credit
        // 2000e18 * 1.25 = 2500e18
        assertEq(groveBasin.totalAssets(), 2500e18);
    }

    function test_totalAssets_conversionRateChange() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.redeemedCreditTokenBalance(), 1000e18);
        // 1000e18 * 1.25 = 1250e18
        assertEq(groveBasin.totalAssets(), 1250e18);

        // Credit rate changes DO affect redeemed credit token value
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);
        assertEq(groveBasin.totalAssets(), 1500e18);

        mockCreditTokenRateProvider.__setConversionRate(0.5e27);
        assertEq(groveBasin.totalAssets(), 500e18);
    }

    function test_totalAssets_withAllAssetTypes() public {
        collateralToken.mint(address(groveBasin), 100e18);
        swapToken.mint(address(pocket), 200e6);
        creditToken.mint(address(groveBasin), 1000e18);

        // collateral: 100e18, swap: 200e18, credit: 1250e18
        assertEq(groveBasin.totalAssets(), 1550e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        // 100e18 collateral + 200e18 swap + (600e18 + 400e18 redeemed) * 1.25 = 1550e18
        assertEq(groveBasin.totalAssets(), 1550e18);
    }

    function test_totalAssets_partialComplete() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.redeemedCreditTokenBalance(), 1000e18);

        // Complete 600e18 credit tokens worth -> vault returns 600e18 collateral
        collateralToken.mint(address(vault), 600e18);
        vault.__setMaxWithdraw(600e18);
        groveBasin.completeRedeem(address(redeemer), 600e18, 600e18);

        // redeemedCreditTokenBalance = 1000e18 - 600e18 = 400e18
        assertEq(groveBasin.redeemedCreditTokenBalance(), 400e18);

        // totalAssets = 600e18 collateral + 400e18 redeemed credit * 1.25 = 1100e18
        assertEq(groveBasin.totalAssets(), 1100e18);
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

        // All credit tokens (in basin + redeemed) valued at credit rate
        uint256 expectedTotalAssets = collateralAmount
            + (swapAmount * 1e12)
            + (creditAmount * conversionRate / 1e27);

        assertEq(groveBasin.totalAssets(), expectedTotalAssets);
    }

}
