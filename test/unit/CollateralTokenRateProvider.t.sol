// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract CollateralTokenRateProviderTests is GroveBasinTestBase {

    function test_collateralTokenAtPeg() public {
        // Collateral token (USDC) is at $1 (1e27)
        mockCollateralTokenRateProvider.__setConversionRate(1e27);

        // Deposit 100 USDC (18 decimals)
        _deposit(address(collateralToken), address(this), 100e18);

        // Value should be $100 (100e18 in 18 decimal precision)
        assertEq(groveBasin.totalAssets(), 100e18);

        // Deposit 100 credit token ($125 worth at 18 decimals, since credit token rate is 1.25e27)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $225 (100 from USDC + 125 from credit)
        assertEq(groveBasin.totalAssets(), 225e18);

        // Swapping USDC to credit: 10 USDC ($10) should get 8 credit tokens ($10 / $1.25)
        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 10e18), 8e18);
        // Swapping credit to USDC: 10 credit token ($12.50) should get 12.5 USDC
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 10e18), 12.5e18);
    }

    function test_collateralTokenAbovePeg() public {
        // Collateral token (USDC) is trading at $1.01 (1.01e27)
        mockCollateralTokenRateProvider.__setConversionRate(1.01e27);

        // Deposit 100 USDC
        _deposit(address(collateralToken), address(this), 100e18);

        // Value should be $101 (100 * 1.01 = 101e18)
        assertEq(groveBasin.totalAssets(), 101e18);

        // Deposit 100 credit token ($125 worth)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $226 (101 from USDC + 125 from credit)
        assertEq(groveBasin.totalAssets(), 226e18);

        // 10 USDC ($10.10) should get credit tokens worth $10.10 / $1.25 = 8.08
        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 10e18);
        assertApproxEqRel(creditOut, 8.08e18, 1e14); // ~8.08 with tolerance
    }

    function test_collateralTokenBelowPeg() public {
        // Collateral token (USDC) is trading at $0.99 (0.99e27)
        mockCollateralTokenRateProvider.__setConversionRate(0.99e27);

        // Deposit 100 USDC
        _deposit(address(collateralToken), address(this), 100e18);

        // Value should be $99 (100 * 0.99 = 99e18)
        assertEq(groveBasin.totalAssets(), 99e18);

        // Deposit 100 credit token ($125 worth)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $224 (99 from USDC + 125 from credit)
        assertEq(groveBasin.totalAssets(), 224e18);

        // Swapping: 10 credit token ($12.50) should get more USDC since USDC is worth less
        // $12.50 / $0.99 = ~12.626... USDC
        uint256 collateralOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 10e18);
        assertGt(collateralOut, 12e18);
        assertApproxEqRel(collateralOut, 12.626262626262626262e18, 1e14); // ~12.626 with tolerance

        // 10 USDC ($9.90) should get less credit token ($9.90 / $1.25 = 7.92)
        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 10e18);
        assertLt(creditOut, 8e18);
        assertApproxEqRel(creditOut, 7.92e18, 1e14); // ~7.92 with tolerance
    }

    function test_collateralTokenValueChangesAffectShares() public {
        // Start at peg
        mockCollateralTokenRateProvider.__setConversionRate(1e27);

        // User1 deposits 100 USDC at $1
        address user1 = makeAddr("user1");
        _deposit(address(collateralToken), user1, 100e18);

        uint256 user1Shares = groveBasin.shares(user1);
        assertEq(user1Shares, 100e18); // First depositor gets 1:1 shares

        // Price increases to $1.10
        mockCollateralTokenRateProvider.__setConversionRate(1.10e27);

        // Total assets should now be $110
        assertEq(groveBasin.totalAssets(), 110e18);

        // User1's share value increased
        assertEq(groveBasin.convertToAssetValue(user1Shares), 110e18);

        // User2 deposits credit tokens worth the same value as user1's shares
        address user2 = makeAddr("user2");
        uint256 user1Value = groveBasin.convertToAssetValue(user1Shares);
        uint256 creditAmount = user1Value * 1e27 / 1.25e27;
        _deposit(address(creditToken), user2, creditAmount);

        // User2 should get approximately same shares as user1
        uint256 user2Shares = groveBasin.shares(user2);
        assertApproxEqAbs(user2Shares, user1Shares, 1);

        // Both users have approximately equal value
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(user1Shares),
            groveBasin.convertToAssetValue(user2Shares),
            2
        );
    }

    function test_collateralTokenSwapWithCreditToken() public {
        // USDC at $0.995 (slightly below peg)
        mockCollateralTokenRateProvider.__setConversionRate(0.995e27);

        // Seed liquidity
        _deposit(address(collateralToken), address(this), 1000e18);
        _deposit(address(creditToken),     address(this), 1000e18);

        // Credit token rate is 1.25e27, so 1 credit token = $1.25
        // USDC is $0.995

        // Swap 100 USDC -> credit token
        // Value in: 100 * 0.995 = $99.50
        // Credit token out: $99.50 / $1.25 = 79.6 credit tokens
        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 100e18);
        assertApproxEqRel(creditOut, 79.6e18, 1e14);

        // Swap 100 credit token -> USDC
        // Value in: 100 * 1.25 = $125
        // USDC out: $125 / $0.995 = ~125.628 USDC
        uint256 collateralOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 100e18);
        assertApproxEqRel(collateralOut, 125.628140703517587940e18, 1e14);
    }

    function testFuzz_collateralTokenRateProvider(uint256 rate, uint256 amount) public {
        // Bound rate between $0.90 and $1.10 (realistic stablecoin range)
        rate   = bound(rate, 0.90e27, 1.10e27);
        amount = bound(amount, 1e18, 1_000_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(rate);

        _deposit(address(collateralToken), address(this), amount);

        // Total assets should equal amount * rate / 1e27
        assertEq(groveBasin.totalAssets(), amount * rate / 1e27);

        // Convert to shares and back should be approximately equal
        uint256 shares     = groveBasin.shares(address(this));
        uint256 assetValue = groveBasin.convertToAssetValue(shares);
        assertApproxEqAbs(assetValue, amount * rate / 1e27, 1);
    }

    function test_collateralTokenRateProviderGetter() public view {
        assertEq(groveBasin.collateralTokenRateProvider(), address(mockCollateralTokenRateProvider));
    }

    function testFuzz_swapCollateralForCredit(uint256 collateralRate, uint256 swapAmount) public {
        // Bound collateral rate between $0.90 and $1.10 (realistic stablecoin range)
        collateralRate = bound(collateralRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 10_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(collateralRate);

        // Seed liquidity with both tokens
        _deposit(address(collateralToken), address(this), 100_000e18);
        _deposit(address(creditToken),     address(this), 100_000e18);

        // Calculate expected credit out
        // swapAmount * collateralRate / creditRate (1.25e27)
        uint256 expectedCreditOut = swapAmount * collateralRate / 1.25e27;

        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), swapAmount);

        // Allow small rounding differences
        assertApproxEqAbs(creditOut, expectedCreditOut, 2);
    }

    function testFuzz_swapCreditForCollateral(uint256 collateralRate, uint256 swapAmount) public {
        // Bound collateral rate between $0.90 and $1.10 (realistic stablecoin range)
        collateralRate = bound(collateralRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 10_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(collateralRate);

        // Seed liquidity with both tokens
        _deposit(address(collateralToken), address(this), 100_000e18);
        _deposit(address(creditToken),     address(this), 100_000e18);

        // Calculate expected collateral out
        // swapAmount * creditRate (1.25e27) / collateralRate
        uint256 expectedCollateralOut = swapAmount * 1.25e27 / collateralRate;

        uint256 collateralOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), swapAmount);

        // Allow small rounding differences
        assertApproxEqAbs(collateralOut, expectedCollateralOut, 2);
    }

    function testFuzz_roundTripSwapCollateralCredit(uint256 collateralRate, uint256 swapAmount) public {
        // Bound collateral rate between $0.90 and $1.10 (realistic stablecoin range)
        collateralRate = bound(collateralRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 1_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(collateralRate);

        // Seed liquidity with both tokens
        _deposit(address(collateralToken), address(this), 100_000e18);
        _deposit(address(creditToken),     address(this), 100_000e18);

        // Swap collateral -> credit
        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), swapAmount);

        // Swap credit back -> collateral
        uint256 collateralBack = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), creditOut);

        // Should get approximately the same amount back (accounting for rounding)
        assertApproxEqAbs(collateralBack, swapAmount, 2);
    }

    function testFuzz_swapCollateralForCredit_largeAmounts(uint256 collateralRate, uint256 swapAmount) public {
        // Bound collateral rate between $0.90 and $1.10 (realistic stablecoin range)
        collateralRate = bound(collateralRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e18, 1_000_000_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(collateralRate);

        // Seed liquidity with very large amounts
        _deposit(address(collateralToken), address(this), 2_000_000_000e18);
        _deposit(address(creditToken),     address(this), 2_000_000_000e18);

        // Calculate expected credit out
        // swapAmount * collateralRate / creditRate (1.25e27)
        uint256 expectedCreditOut = swapAmount * collateralRate / 1.25e27;

        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), swapAmount);

        // Allow slightly larger rounding differences for very large amounts
        // Using relative comparison (within 0.000001%)
        assertApproxEqRel(creditOut, expectedCreditOut, 1e10);
    }

    function testFuzz_swapCreditForCollateral_largeAmounts(uint256 collateralRate, uint256 swapAmount) public {
        // Bound collateral rate between $0.90 and $1.10 (realistic stablecoin range)
        collateralRate = bound(collateralRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e18, 1_000_000_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(collateralRate);

        // Seed liquidity with very large amounts
        _deposit(address(collateralToken), address(this), 2_000_000_000e18);
        _deposit(address(creditToken),     address(this), 2_000_000_000e18);

        // Calculate expected collateral out
        // swapAmount * creditRate (1.25e27) / collateralRate
        uint256 expectedCollateralOut = swapAmount * 1.25e27 / collateralRate;

        uint256 collateralOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), swapAmount);

        // Allow slightly larger rounding differences for very large amounts
        // Using relative comparison (within 0.000001%)
        assertApproxEqRel(collateralOut, expectedCollateralOut, 1e10);
    }

    function testFuzz_roundTripSwapCollateralCredit_largeAmounts(uint256 collateralRate, uint256 swapAmount) public {
        // Bound collateral rate between $0.90 and $1.10 (realistic stablecoin range)
        collateralRate = bound(collateralRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e18, 1_000_000_000e18);

        mockCollateralTokenRateProvider.__setConversionRate(collateralRate);

        // Seed liquidity with very large amounts
        _deposit(address(collateralToken), address(this), 2_000_000_000e18);
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Swap collateral -> credit
        uint256 creditOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), swapAmount);

        // Swap credit back -> collateral
        uint256 collateralBack = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), creditOut);

        // Should get approximately the same amount back (accounting for rounding)
        // Using relative comparison for large amounts (within 0.000001%)
        assertApproxEqRel(collateralBack, swapAmount, 1e10);
    }

}
