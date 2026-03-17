// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockERC20 } from "erc20-helpers/MockERC20.sol";

/**
 * @title RateProviderTestTemplate
 * @notice Parameterized test template for testing rate providers with different tokens
 * @dev This template reduces code duplication by accepting token parameters and running
 *      identical test logic for both swapToken and collateralToken rate providers
 */
abstract contract RateProviderTestTemplate is GroveBasinTestBase {

    // Abstract functions to be implemented by concrete test contracts
    function getTestToken() internal view virtual returns (MockERC20);
    function getTestTokenDecimals() internal pure virtual returns (uint256);
    function getMockRateProvider() internal view virtual returns (MockRateProvider);
    function getTokenName() internal pure virtual returns (string memory);

    function test_tokenAtPeg() public {
        // Token is at $1 (1e27)
        getMockRateProvider().__setConversionRate(1e27);

        // Deposit 100 tokens
        _deposit(address(getTestToken()), address(this), 100 * 10**getTestTokenDecimals());

        // Value should be $100 (100e18 in 18 decimal precision)
        assertEq(groveBasin.totalAssets(), 100e18);

        // Deposit 100 credit token ($125 worth at 18 decimals, since credit token rate is 1.25e27)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $225 (100 from token + 125 from credit)
        assertEq(groveBasin.totalAssets(), 225e18);

        // Swapping token to credit: 10 token ($10) should get 8 credit tokens ($10 / $1.25)
        if (getTestTokenDecimals() == 18) {
            assertEq(groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), 10e18), 8e18);
        } else {
            assertEq(groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), 10e6), 8e18);
        }

        // Swapping credit to token: 10 credit token ($12.50) should get 12.5 token
        uint256 expectedTokenAmount = getTestTokenDecimals() == 18 ? 125e17 : 125e5;
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), 10e18), expectedTokenAmount);
    }

    function test_tokenAbovePeg() public {
        // Token is trading at $1.01 (1.01e27)
        getMockRateProvider().__setConversionRate(1.01e27);

        // Deposit 100 token
        _deposit(address(getTestToken()), address(this), 100 * 10**getTestTokenDecimals());

        // Value should be $101 (100 * 1.01 = 101e18)
        assertEq(groveBasin.totalAssets(), 101e18);

        // Deposit 100 credit token ($125 worth)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $226 (101 from token + 125 from credit)
        assertEq(groveBasin.totalAssets(), 226e18);

        // 10 token ($10.10) should get credit tokens worth $10.10 / $1.25 = 8.08
        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), 10 * 10**getTestTokenDecimals());
        assertApproxEqRel(creditOut, 8.08e18, 1e14);
    }

    function test_tokenBelowPeg() public {
        // Token is trading at $0.99 (0.99e27)
        getMockRateProvider().__setConversionRate(0.99e27);

        // Deposit 100 token
        _deposit(address(getTestToken()), address(this), 100 * 10**getTestTokenDecimals());

        // Value should be $99 (100 * 0.99 = 99e18)
        assertEq(groveBasin.totalAssets(), 99e18);

        // Deposit 100 credit token ($125 worth)
        _deposit(address(creditToken), address(this), 100e18);

        // Total should be $224 (99 from token + 125 from credit)
        assertEq(groveBasin.totalAssets(), 224e18);

        // Swapping: 10 credit token ($12.50) should get more tokens since token is worth less
        // $12.50 / $0.99 = ~12.626...
        uint256 tokenOut = groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), 10e18);
        assertGt(tokenOut, 12 * 10**getTestTokenDecimals());

        if (getTestTokenDecimals() == 18) {
            assertApproxEqRel(tokenOut, 12.626262626262626262e18, 1e14);
        } else {
            assertApproxEqRel(tokenOut, 12.626262e6, 1e14);
        }

        // 10 token ($9.90) should get less credit token ($9.90 / $1.25 = 7.92)
        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), 10 * 10**getTestTokenDecimals());
        assertLt(creditOut, 8e18);
        assertApproxEqRel(creditOut, 7.92e18, 1e14);
    }

    function test_tokenValueChangesAffectShares() public {
        // Start at peg
        getMockRateProvider().__setConversionRate(1e27);

        // User1 deposits 100 tokens at $1
        address user1 = makeAddr("user1");
        _deposit(address(getTestToken()), user1, 100 * 10**getTestTokenDecimals());

        uint256 user1Shares = groveBasin.shares(user1);
        assertEq(user1Shares, 100e18); // First depositor gets 1:1 shares

        // Price increases to $1.10
        getMockRateProvider().__setConversionRate(1.10e27);

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

    function test_tokenSwapWithCreditToken() public {
        // Token at $0.995 (slightly below peg)
        getMockRateProvider().__setConversionRate(0.995e27);

        // Seed liquidity
        _deposit(address(getTestToken()), address(this), 1000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 1000e18);

        // Credit token rate is 1.25e27, so 1 credit token = $1.25
        // Token is $0.995

        // Swap 100 token -> credit token
        // Value in: 100 * 0.995 = $99.50
        // Credit token out: $99.50 / $1.25 = 79.6 credit tokens
        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), 100 * 10**getTestTokenDecimals());
        assertApproxEqRel(creditOut, 79.6e18, 1e14);

        // Swap 100 credit token -> token
        // Value in: 100 * 1.25 = $125
        // Token out: $125 / $0.995 = ~125.628
        uint256 tokenOut = groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), 100e18);

        if (getTestTokenDecimals() == 18) {
            assertApproxEqRel(tokenOut, 125.628140703517587940e18, 1e14);
        } else {
            assertApproxEqRel(tokenOut, 125.628140e6, 1e14);
        }
    }

    function testFuzz_tokenRateProvider(uint256 rate, uint256 amount) public {
        // Bound rate between $0.90 and $1.10 (realistic stablecoin range)
        rate = bound(rate, 0.90e27, 1.10e27);

        uint256 minAmount = 1 * 10**getTestTokenDecimals();
        uint256 maxAmount = 1_000_000 * 10**getTestTokenDecimals();
        amount = bound(amount, minAmount, maxAmount);

        getMockRateProvider().__setConversionRate(rate);

        _deposit(address(getTestToken()), address(this), amount);

        // Total assets should equal amount * rate / precision adjustment
        uint256 precisionAdjustment = getTestTokenDecimals() == 18 ? 1e27 : 1e15;
        assertEq(groveBasin.totalAssets(), amount * rate / precisionAdjustment);

        // Convert to shares and back should be approximately equal
        uint256 shares = groveBasin.shares(address(this));
        uint256 assetValue = groveBasin.convertToAssetValue(shares);
        assertApproxEqAbs(assetValue, amount * rate / precisionAdjustment, 1);
    }

    function testFuzz_swapTokenForCredit(uint256 tokenRate, uint256 swapAmount) public {
        // Bound token rate between $0.90 and $1.10 (realistic stablecoin range)
        tokenRate = bound(tokenRate, 0.90e27, 1.10e27);

        uint256 minAmount = 1 * 10**getTestTokenDecimals();
        uint256 maxAmount = 10_000 * 10**getTestTokenDecimals();
        swapAmount = bound(swapAmount, minAmount, maxAmount);

        getMockRateProvider().__setConversionRate(tokenRate);

        // Seed liquidity with both tokens
        _deposit(address(getTestToken()), address(this), 100_000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 100_000e18);

        // Calculate expected credit out
        uint256 expectedCreditOut;
        if (getTestTokenDecimals() == 18) {
            expectedCreditOut = swapAmount * tokenRate / 1.25e27;
        } else {
            expectedCreditOut = swapAmount * tokenRate / 1.25e27 * 1e18 / 1e6;
        }

        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), swapAmount);

        // Allow small rounding differences
        assertApproxEqAbs(creditOut, expectedCreditOut, 2);
    }

    function testFuzz_swapCreditForToken(uint256 tokenRate, uint256 swapAmount) public {
        // Bound token rate between $0.90 and $1.10 (realistic stablecoin range)
        tokenRate = bound(tokenRate, 0.90e27, 1.10e27);
        // Bound swap amount to reasonable range
        swapAmount = bound(swapAmount, 1e18, 10_000e18);

        getMockRateProvider().__setConversionRate(tokenRate);

        // Seed liquidity with both tokens
        _deposit(address(getTestToken()), address(this), 100_000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 100_000e18);

        // Calculate expected token out
        uint256 expectedTokenOut;
        if (getTestTokenDecimals() == 18) {
            expectedTokenOut = swapAmount * 1.25e27 / tokenRate;
        } else {
            expectedTokenOut = swapAmount * 1.25e27 / tokenRate * 1e6 / 1e18;
        }

        uint256 tokenOut = groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), swapAmount);

        // Allow small rounding differences
        assertApproxEqAbs(tokenOut, expectedTokenOut, 2);
    }

    function testFuzz_roundTripSwapTokenCredit(uint256 tokenRate, uint256 swapAmount) public {
        // Bound token rate between $0.90 and $1.10 (realistic stablecoin range)
        tokenRate = bound(tokenRate, 0.90e27, 1.10e27);

        uint256 minAmount = 1 * 10**getTestTokenDecimals();
        uint256 maxAmount = 1_000 * 10**getTestTokenDecimals();
        swapAmount = bound(swapAmount, minAmount, maxAmount);

        getMockRateProvider().__setConversionRate(tokenRate);

        // Seed liquidity with both tokens
        _deposit(address(getTestToken()), address(this), 100_000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 100_000e18);

        // Swap token -> credit
        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), swapAmount);

        // Swap credit back -> token
        uint256 tokenBack = groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), creditOut);

        // Should get approximately the same amount back (accounting for rounding)
        assertApproxEqAbs(tokenBack, swapAmount, 2);
    }

    function testFuzz_swapTokenForCredit_largeAmounts(uint256 tokenRate, uint256 swapAmount) public {
        // Bound token rate between $0.90 and $1.10 (realistic stablecoin range)
        tokenRate = bound(tokenRate, 0.90e27, 1.10e27);

        uint256 minAmount = 100_000_000 * 10**getTestTokenDecimals();
        uint256 maxAmount = 1_000_000_000 * 10**getTestTokenDecimals();
        swapAmount = bound(swapAmount, minAmount, maxAmount);

        getMockRateProvider().__setConversionRate(tokenRate);

        // Seed liquidity with very large amounts
        _deposit(address(getTestToken()), address(this), 2_000_000_000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Calculate expected credit out
        uint256 expectedCreditOut;
        if (getTestTokenDecimals() == 18) {
            expectedCreditOut = swapAmount * tokenRate / 1.25e27;
        } else {
            expectedCreditOut = swapAmount * tokenRate / 1.25e27 * 1e18 / 1e6;
        }

        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), swapAmount);

        // Using relative comparison (within 0.000001%)
        assertApproxEqRel(creditOut, expectedCreditOut, 1e10);
    }

    function testFuzz_swapCreditForToken_largeAmounts(uint256 tokenRate, uint256 swapAmount) public {
        // Bound token rate between $0.90 and $1.10 (realistic stablecoin range)
        tokenRate = bound(tokenRate, 0.90e27, 1.10e27);
        // Bound swap amount to very large range (100M - 1B tokens)
        swapAmount = bound(swapAmount, 100_000_000e18, 1_000_000_000e18);

        getMockRateProvider().__setConversionRate(tokenRate);

        // Seed liquidity with very large amounts
        _deposit(address(getTestToken()), address(this), 2_000_000_000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Calculate expected token out
        uint256 expectedTokenOut;
        if (getTestTokenDecimals() == 18) {
            expectedTokenOut = swapAmount * 1.25e27 / tokenRate;
        } else {
            expectedTokenOut = swapAmount * 1.25e27 / tokenRate * 1e6 / 1e18;
        }

        uint256 tokenOut = groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), swapAmount);

        // Using relative comparison (within 0.000001%)
        assertApproxEqRel(tokenOut, expectedTokenOut, 1e10);
    }

    function testFuzz_roundTripSwapTokenCredit_largeAmounts(uint256 tokenRate, uint256 swapAmount) public {
        // Bound token rate between $0.90 and $1.10 (realistic stablecoin range)
        tokenRate = bound(tokenRate, 0.90e27, 1.10e27);

        uint256 minAmount = 100_000_000 * 10**getTestTokenDecimals();
        uint256 maxAmount = 1_000_000_000 * 10**getTestTokenDecimals();
        swapAmount = bound(swapAmount, minAmount, maxAmount);

        getMockRateProvider().__setConversionRate(tokenRate);

        // Seed liquidity with very large amounts
        _deposit(address(getTestToken()), address(this), 2_000_000_000 * 10**getTestTokenDecimals());
        _deposit(address(creditToken), address(this), 2_000_000_000e18);

        // Swap token -> credit
        uint256 creditOut = groveBasin.previewSwapExactIn(address(getTestToken()), address(creditToken), swapAmount);

        // Swap credit back -> token
        uint256 tokenBack = groveBasin.previewSwapExactIn(address(creditToken), address(getTestToken()), creditOut);

        // Should get approximately the same amount back (accounting for rounding)
        // Using relative comparison for large amounts (within 0.000001%)
        assertApproxEqRel(tokenBack, swapAmount, 1e10);
    }
}

// Concrete implementation for SwapToken
contract SwapTokenRateProviderTests is RateProviderTestTemplate {

    function getTestToken() internal view override returns (MockERC20) {
        return swapToken;
    }

    function getTestTokenDecimals() internal pure override returns (uint256) {
        return 6; // USDT has 6 decimals
    }

    function getMockRateProvider() internal view override returns (MockRateProvider) {
        return mockSwapTokenRateProvider;
    }

    function getTokenName() internal pure override returns (string memory) {
        return "swapToken";
    }

    function test_swapTokenRateProviderGetter() public view {
        assertEq(groveBasin.swapTokenRateProvider(), address(mockSwapTokenRateProvider));
    }
}

// Concrete implementation for CollateralToken
contract CollateralTokenRateProviderTests is RateProviderTestTemplate {

    function getTestToken() internal view override returns (MockERC20) {
        return collateralToken;
    }

    function getTestTokenDecimals() internal pure override returns (uint256) {
        return 18; // USDC has 18 decimals in this implementation
    }

    function getMockRateProvider() internal view override returns (MockRateProvider) {
        return mockCollateralTokenRateProvider;
    }

    function getTokenName() internal pure override returns (string memory) {
        return "collateralToken";
    }

    function test_collateralTokenRateProviderGetter() public view {
        assertEq(groveBasin.collateralTokenRateProvider(), address(mockCollateralTokenRateProvider));
    }
}
