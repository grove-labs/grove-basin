// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer }  from "src/redeemers/JTRSYTokenRedeemer.sol";

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

        // pendingCreditTokenBalance = 1000e18
        assertEq(groveBasin.pendingCreditTokenBalance(), 1000e18);

        // totalAssets includes pending credit token value (1000 * 1.25 = 1250), credit tokens left the basin
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_partialRedemption() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 400e18);

        // pendingCreditTokenBalance = 400e18
        assertEq(groveBasin.pendingCreditTokenBalance(), 400e18);

        // 600e18 credit tokens still in basin + 400e18 pending = 1000e18 total credit, value = 1250e18
        assertEq(groveBasin.totalAssets(), 1250e18);
    }

    function test_totalAssets_afterCompleteRedeem() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.totalAssets(), 1250e18);

        // Complete the redemption - vault returns 1000e18 collateral (redeem returns shares 1:1)
        collateralToken.mint(address(vault), 1000e18);
        groveBasin.completeRedeem(requestId);

        // pendingCreditTokenBalance fully zeroed
        assertEq(groveBasin.pendingCreditTokenBalance(), 0);

        // totalAssets = 1000e18 actual collateral
        assertEq(groveBasin.totalAssets(), 1000e18);
    }

    function test_totalAssets_multipleInitiateRedeems() public {
        creditToken.mint(address(groveBasin), 2000e18);

        vm.startPrank(owner);
        groveBasin.initiateRedeem(address(redeemer), 500e18);

        vm.roll(block.number + 1);
        groveBasin.initiateRedeem(address(redeemer), 300e18);
        vm.stopPrank();

        // pendingCreditTokenBalance = 500e18 + 300e18 = 800e18
        assertEq(groveBasin.pendingCreditTokenBalance(), 800e18);

        // 1200e18 credit in basin + 800e18 pending = 2000e18 total credit, value = 2500e18
        assertEq(groveBasin.totalAssets(), 2500e18);
    }

    function test_totalAssets_conversionRateChange() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);

        // pendingCreditTokenBalance = 1000e18
        assertEq(groveBasin.pendingCreditTokenBalance(), 1000e18);
        // value = 1000 * 1.25 = 1250
        assertEq(groveBasin.totalAssets(), 1250e18);

        // Credit rate changes DO affect pending credit token value
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);
        // value = 1000 * 1.5 = 1500
        assertEq(groveBasin.totalAssets(), 1500e18);

        mockCreditTokenRateProvider.__setConversionRate(0.5e27);
        // value = 1000 * 0.5 = 500
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

        // pendingCredit = 400e18
        // totalAssets: 100e18 collateral + 200e18 swap + (600 + 400) * 1.25 credit = 1550e18
        assertEq(groveBasin.totalAssets(), 1550e18);
    }

    function test_totalAssets_partialComplete() public {
        creditToken.mint(address(groveBasin), 1000e18);

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), 1000e18);

        assertEq(groveBasin.pendingCreditTokenBalance(), 1000e18);

        // Complete - vault returns 1000e18 collateral (redeem 1:1)
        collateralToken.mint(address(vault), 1000e18);
        groveBasin.completeRedeem(requestId);

        // pendingCreditTokenBalance fully zeroed for this request
        assertEq(groveBasin.pendingCreditTokenBalance(), 0);

        // totalAssets = 1000e18 actual collateral
        assertEq(groveBasin.totalAssets(), 1000e18);
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

        // totalAssets = collateral + swap + (creditInBasin + pendingCredit) * creditRate
        // pendingCredit = redeemAmount, creditInBasin = creditAmount - redeemAmount
        // total credit = creditAmount, so value = creditAmount * conversionRate / 1e27
        uint256 expectedTotalAssets = collateralAmount
            + (swapAmount * 1e12)
            + (creditAmount * conversionRate / 1e27);

        assertEq(groveBasin.totalAssets(), expectedTotalAssets);
    }

}
