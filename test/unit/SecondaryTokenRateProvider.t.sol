// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract SecondaryTokenRateProviderTests is GroveBasinTestBase {

    function test_secondaryTokenAtPeg() public {
        // Secondary token (USDT) is at $1 (1e27)
        mockSecondaryTokenRateProvider.__setConversionRate(1e27);

        // Deposit 100 USDT (6 decimals)
        _deposit(address(secondaryToken), address(this), 100e6);

        // Value should be $100 (100e18 in 18 decimal precision)
        assertEq(groveBasin.totalAssets(), 100e18);

        // Deposit 100 credit token ($125 worth at 18 decimals, since credit token rate is 1.25e27)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $225 (100 from secondary + 125 from credit)
        assertEq(groveBasin.totalAssets(), 225e18);

        // Swapping USDT to credit: 10 USDT ($10) should get 8 credit tokens ($10 / $1.25)
        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 10e6), 8e18);
        // Swapping credit to USDT: 10 credit token ($12.50) should get 12.5 USDT
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 10e18), 12.5e6);
    }

    function test_secondaryTokenAbovePeg() public {
        // Secondary token (USDT) is trading at $1.01 (1.01e27)
        mockSecondaryTokenRateProvider.__setConversionRate(1.01e27);

        // Deposit 100 USDT
        _deposit(address(secondaryToken), address(this), 100e6);

        // Value should be $101 (100 * 1.01 = 101e18)
        assertEq(groveBasin.totalAssets(), 101e18);

        // Deposit 100 credit token ($125 worth)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $226 (101 from USDT + 125 from credit)
        assertEq(groveBasin.totalAssets(), 226e18);

        // 10 USDT ($10.10) should get credit tokens worth $10.10 / $1.25 = 8.08
        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 10e6);
        assertApproxEqRel(creditOut, 8.08e18, 1e14);
    }

    function test_secondaryTokenBelowPeg() public {
        // Secondary token (USDT) is trading at $0.99 (0.99e27)
        mockSecondaryTokenRateProvider.__setConversionRate(0.99e27);

        // Deposit 100 USDT
        _deposit(address(secondaryToken), address(this), 100e6);

        // Value should be $99 (100 * 0.99 = 99e18)
        assertEq(groveBasin.totalAssets(), 99e18);

        // Deposit 100 credit token ($125 worth)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $224 (99 from USDT + 125 from credit)
        assertEq(groveBasin.totalAssets(), 224e18);

        // Swapping: 10 credit token ($12.50) should get more USDT since USDT is worth less
        // $12.50 / $0.99 = ~12.626... USDT
        uint256 secondaryOut = groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 10e18);
        assertGt(secondaryOut, 12e6);
        assertApproxEqRel(secondaryOut, 12.626262e6, 1e14);

        // 10 USDT ($9.90) should get less credit token ($9.90 / $1.25 = 7.92)
        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 10e6);
        assertLt(creditOut, 8e18);
        assertApproxEqRel(creditOut, 7.92e18, 1e14);
    }

    function test_secondaryTokenValueChangesAffectShares() public {
        // Start at peg
        mockSecondaryTokenRateProvider.__setConversionRate(1e27);

        // User1 deposits 100 USDT at $1
        address user1 = makeAddr("user1");
        _deposit(address(secondaryToken), user1, 100e6);

        uint256 user1Shares = groveBasin.shares(user1);
        assertEq(user1Shares, 100e18); // First depositor gets 1:1 shares

        // Price increases to $1.10
        mockSecondaryTokenRateProvider.__setConversionRate(1.10e27);

        // Total assets should now be $110
        assertEq(groveBasin.totalAssets(), 110e18);

        // User1's share value increased
        assertEq(groveBasin.convertToAssetValue(user1Shares), 110e18);

        // User2 deposits 88 credit token ($110 worth: 88 * 1.25 = 110)
        address user2 = makeAddr("user2");
        _deposit(address(creditToken), user2, 88e18);

        // User2 should get same shares as user1 since they deposited same value
        uint256 user2Shares = groveBasin.shares(user2);
        assertEq(user2Shares, user1Shares);

        // Both users have equal shares and equal value
        assertEq(groveBasin.convertToAssetValue(user1Shares), groveBasin.convertToAssetValue(user2Shares));
    }

    function test_secondaryTokenSwapWithCreditToken() public {
        // USDT at $0.995 (slightly below peg)
        mockSecondaryTokenRateProvider.__setConversionRate(0.995e27);

        // Seed liquidity
        _deposit(address(secondaryToken), address(this), 1000e6);
        _deposit(address(creditToken), address(this), 1000e18);

        // Credit token rate is 1.25e27, so 1 credit token = $1.25
        // USDT is $0.995

        // Swap 100 USDT -> credit token
        // Value in: 100 * 0.995 = $99.50
        // Credit token out: $99.50 / $1.25 = 79.6 credit tokens
        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 100e6);
        assertApproxEqRel(creditOut, 79.6e18, 1e14);

        // Swap 100 credit token -> USDT
        // Value in: 100 * 1.25 = $125
        // USDT out: $125 / $0.995 = ~125.628 USDT
        uint256 secondaryOut = groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 100e18);
        assertApproxEqRel(secondaryOut, 125.628140e6, 1e14);
    }

    function testFuzz_secondaryTokenRateProvider(uint256 rate, uint256 amount) public {
        // Bound rate between $0.90 and $1.10 (realistic stablecoin range)
        rate = bound(rate, 0.90e27, 1.10e27);
        amount = bound(amount, 1e6, 1_000_000e6);

        mockSecondaryTokenRateProvider.__setConversionRate(rate);

        _deposit(address(secondaryToken), address(this), amount);

        // Total assets should equal amount * rate / 1e15
        assertEq(groveBasin.totalAssets(), amount * rate / 1e15);

        // Convert to shares and back should be approximately equal
        uint256 shares = groveBasin.shares(address(this));
        uint256 assetValue = groveBasin.convertToAssetValue(shares);
        assertApproxEqAbs(assetValue, amount * rate / 1e15, 1);
    }

    function test_secondaryTokenRateProviderGetter() public view {
        assertEq(groveBasin.secondaryTokenRateProvider(), address(mockSecondaryTokenRateProvider));
    }

    function testFuzz_swapSecondaryForCredit(uint256 secondaryRate, uint256 swapAmount) public {
        // Bound secondary rate between $0.90 and $1.10 (realistic stablecoin range)
        secondaryRate = bound(secondaryRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e6, 10_000e6);

        mockSecondaryTokenRateProvider.__setConversionRate(secondaryRate);

        // Seed liquidity with both tokens
        _deposit(address(secondaryToken), address(this), 100_000e6);
        _deposit(address(creditToken), address(this), 100_000e18);

        // Calculate expected credit out
        // swapAmount * secondaryRate / creditRate * creditPrecision / secondaryPrecision
        uint256 expectedCreditOut = swapAmount * secondaryRate / 1.25e27 * 1e18 / 1e6;

        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), swapAmount);

        // Allow small rounding differences
        assertApproxEqAbs(creditOut, expectedCreditOut, 2);
    }

    function testFuzz_swapCreditForSecondary(uint256 secondaryRate, uint256 swapAmount) public {
        // Bound secondary rate between $0.90 and $1.10 (realistic stablecoin range)
        secondaryRate = bound(secondaryRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 10_000e18);

        mockSecondaryTokenRateProvider.__setConversionRate(secondaryRate);

        // Seed liquidity with both tokens
        _deposit(address(secondaryToken), address(this), 100_000e6);
        _deposit(address(creditToken), address(this), 100_000e18);

        // Calculate expected secondary out
        // swapAmount * creditRate (1.25e27) / secondaryRate * 1e6 / 1e18
        uint256 expectedSecondaryOut = swapAmount * 1.25e27 / secondaryRate * 1e6 / 1e18;

        uint256 secondaryOut = groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), swapAmount);

        // Allow small rounding differences
        assertApproxEqAbs(secondaryOut, expectedSecondaryOut, 2);
    }

    function testFuzz_roundTripSwapSecondaryCredit(uint256 secondaryRate, uint256 swapAmount) public {
        // Bound secondary rate between $0.90 and $1.10 (realistic stablecoin range)
        secondaryRate = bound(secondaryRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e6, 1_000e6);

        mockSecondaryTokenRateProvider.__setConversionRate(secondaryRate);

        // Seed liquidity with both tokens
        _deposit(address(secondaryToken), address(this), 100_000e6);
        _deposit(address(creditToken), address(this), 100_000e18);

        // Swap secondary -> credit
        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), swapAmount);

        // Swap credit back -> secondary
        uint256 secondaryBack = groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), creditOut);

        // Should get approximately the same amount back (accounting for rounding)
        assertApproxEqAbs(secondaryBack, swapAmount, 2);
    }

    function testFuzz_swapSecondaryForCredit_largeAmounts(uint256 secondaryRate, uint256 swapAmount) public {
        // Bound secondary rate between $0.90 and $1.10 (realistic stablecoin range)
        secondaryRate = bound(secondaryRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e6, 1_000_000_000e6);

        mockSecondaryTokenRateProvider.__setConversionRate(secondaryRate);

        // Seed liquidity with very large amounts
        _deposit(address(secondaryToken), address(this), 2_000_000_000e6);
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Calculate expected credit out
        // swapAmount * secondaryRate / creditRate * creditPrecision / secondaryPrecision
        uint256 expectedCreditOut = swapAmount * secondaryRate / 1.25e27 * 1e18 / 1e6;

        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), swapAmount);

        // Using relative comparison (within 0.000001%)
        assertApproxEqRel(creditOut, expectedCreditOut, 1e10);
    }

    function testFuzz_swapCreditForSecondary_largeAmounts(uint256 secondaryRate, uint256 swapAmount) public {
        // Bound secondary rate between $0.90 and $1.10 (realistic stablecoin range)
        secondaryRate = bound(secondaryRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e18, 1_000_000_000e18);

        mockSecondaryTokenRateProvider.__setConversionRate(secondaryRate);

        // Seed liquidity with very large amounts
        _deposit(address(secondaryToken), address(this), 2_000_000_000e6);
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Calculate expected secondary out
        // swapAmount * creditRate (1.25e27) / secondaryRate * 1e6 / 1e18
        uint256 expectedSecondaryOut = swapAmount * 1.25e27 / secondaryRate * 1e6 / 1e18;

        uint256 secondaryOut = groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), swapAmount);

        // Using relative comparison (within 0.000001%)
        assertApproxEqRel(secondaryOut, expectedSecondaryOut, 1e10);
    }

    function testFuzz_roundTripSwapSecondaryCredit_largeAmounts(uint256 secondaryRate, uint256 swapAmount) public {
        // Bound secondary rate between $0.90 and $1.10 (realistic stablecoin range)
        secondaryRate = bound(secondaryRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e6, 1_000_000_000e6);

        mockSecondaryTokenRateProvider.__setConversionRate(secondaryRate);

        // Seed liquidity with very large amounts
        _deposit(address(secondaryToken), address(this), 2_000_000_000e6);
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Swap secondary -> credit
        uint256 creditOut = groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), swapAmount);

        // Swap credit back -> secondary
        uint256 secondaryBack = groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), creditOut);

        // Should get approximately the same amount back (accounting for rounding)
        // Using relative comparison for large amounts (within 0.000001%)
        assertApproxEqRel(secondaryBack, swapAmount, 1e10);
    }

}
