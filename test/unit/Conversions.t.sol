// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinConversionTestBase is GroveBasinTestBase {

    struct FuzzVars {
        uint256 collateralTokenAmount;
        uint256 swapTokenAmount;
        uint256 creditTokenAmount;
        uint256 expectedShares;
    }

    // Takes in fuzz inputs, bounds them, deposits assets, and returns
    // initial shares from all deposits (always equal to total value at beginning).
    function _setUpConversionFuzzTest(
        uint256 initialConversionRate,
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount
    )
        internal returns (FuzzVars memory vars)
    {
        vars.collateralTokenAmount  = _bound(collateralTokenAmount, 1, COLLATERAL_TOKEN_MAX);
        vars.swapTokenAmount        = _bound(swapTokenAmount,       1, SWAP_TOKEN_MAX);
        vars.creditTokenAmount      = _bound(creditTokenAmount,     1, CREDIT_TOKEN_MAX);

        _deposit(address(collateralToken), address(this), vars.collateralTokenAmount);
        _deposit(address(swapToken),       address(this), vars.swapTokenAmount);
        _deposit(address(creditToken),     address(this), vars.creditTokenAmount);

        vars.expectedShares =
            vars.collateralTokenAmount +
            vars.swapTokenAmount * 1e12 +
            vars.creditTokenAmount * initialConversionRate / 1e27;

        // Assert that shares to be used for calcs are correct
        assertEq(groveBasin.totalShares(), vars.expectedShares);
    }
}

contract GroveBasinConvertToAssetsTests is GroveBasinTestBase {

    function test_convertToAssets_invalidAsset() public {
        vm.expectRevert("GB/invalid-asset");
        groveBasin.convertToAssets(makeAddr("new-asset"), 100);
    }

    function test_convertToAssets() public view {
        assertEq(groveBasin.convertToAssets(address(collateralToken), 1), 1);
        assertEq(groveBasin.convertToAssets(address(collateralToken), 2), 2);
        assertEq(groveBasin.convertToAssets(address(collateralToken), 3), 3);

        assertEq(groveBasin.convertToAssets(address(collateralToken), 1e18), 1e18);
        assertEq(groveBasin.convertToAssets(address(collateralToken), 2e18), 2e18);
        assertEq(groveBasin.convertToAssets(address(collateralToken), 3e18), 3e18);

        assertEq(groveBasin.convertToAssets(address(swapToken), 1), 0);
        assertEq(groveBasin.convertToAssets(address(swapToken), 2), 0);
        assertEq(groveBasin.convertToAssets(address(swapToken), 3), 0);

        assertEq(groveBasin.convertToAssets(address(swapToken), 1e18), 1e6);
        assertEq(groveBasin.convertToAssets(address(swapToken), 2e18), 2e6);
        assertEq(groveBasin.convertToAssets(address(swapToken), 3e18), 3e6);

        assertEq(groveBasin.convertToAssets(address(creditToken), 1), 0);
        assertEq(groveBasin.convertToAssets(address(creditToken), 2), 1);
        assertEq(groveBasin.convertToAssets(address(creditToken), 3), 2);

        assertEq(groveBasin.convertToAssets(address(creditToken), 1e18), 0.8e18);
        assertEq(groveBasin.convertToAssets(address(creditToken), 2e18), 1.6e18);
        assertEq(groveBasin.convertToAssets(address(creditToken), 3e18), 2.4e18);
    }

    function testFuzz_convertToAssets_swapToken(uint256 amount) public view {
        amount = _bound(amount, 0, COLLATERAL_TOKEN_MAX);

        assertEq(groveBasin.convertToAssets(address(collateralToken), amount), amount);
    }

    function testFuzz_convertToAssets_collateralToken(uint256 amount) public view {
        amount = _bound(amount, 0, SWAP_TOKEN_MAX);

        assertEq(groveBasin.convertToAssets(address(swapToken), amount), amount / 1e12);
    }

    function testFuzz_convertToAssets_creditToken(uint256 conversionRate, uint256 amount) public {
        // NOTE: 0.0001e27 considered lower bound for overflow considerations
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);
        amount         = _bound(amount,         0,         CREDIT_TOKEN_MAX);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        assertEq(groveBasin.convertToAssets(address(creditToken), amount), amount * 1e27 / conversionRate);
    }

}

contract GroveBasinConvertToAssetValueTests is GroveBasinConversionTestBase {

    function testFuzz_convertToAssetValue_noValue(uint256 amount) public view {
        assertEq(groveBasin.convertToAssetValue(amount), amount);
    }

    function test_convertToAssetValue() public {
        _deposit(address(collateralToken), address(this), 100e18);
        _deposit(address(swapToken),       address(this), 100e6);
        _deposit(address(creditToken),     address(this), 80e18);

        assertEq(groveBasin.convertToAssetValue(1e18), 1e18);

        mockCreditTokenRateProvider.__setConversionRate(2e27);

        // $300 dollars of value deposited, 300 shares minted.
        // creditToken portion becomes worth $160, full pool worth $360, each share worth $1.20
        assertEq(groveBasin.convertToAssetValue(1e18), 1.2e18);
    }

    function testFuzz_convertToAssetValue_conversionRateIncrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(groveBasin.convertToAssetValue(vars.expectedShares), initialValue);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.convertToAssetValue(vars.expectedShares), newValue);

        // Value change is only from creditToken exchange rate increasing
        assertEq(newValue - initialValue, vars.creditTokenAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(groveBasin.convertToAssetValue(vars.expectedShares), initialValue);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.convertToAssetValue(vars.expectedShares), newValue);

        // Value change is only from creditToken exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.creditTokenAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

}

contract GroveBasinConvertToSharesTests is GroveBasinConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        assertEq(groveBasin.convertToShares(amount), amount);
    }

    function test_convertToShares_depositAndWithdrawSwapTokenAndCreditToken_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(swapToken), address(this), 100e6);
        _assertOneToOneConversion();

        _deposit(address(creditToken), address(this), 80e18);
        _assertOneToOneConversion();

        _withdraw(address(swapToken), address(this), 100e6);
        _assertOneToOneConversion();

        _withdraw(address(creditToken), address(this), 80e18);
        _assertOneToOneConversion();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(swapToken), address(this), 100e6);
        _deposit(address(creditToken), address(this), 80e18);

        _assertOneToOneConversion();

        // 80 creditToken now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.convertToShares(10), 9);
        assertEq(groveBasin.convertToShares(11), 10);
        assertEq(groveBasin.convertToShares(12), 10);

        assertEq(groveBasin.convertToShares(1e18),   0.909090909090909090e18);
        assertEq(groveBasin.convertToShares(1.1e18), 1e18);
        assertEq(groveBasin.convertToShares(1.2e18), 1.090909090909090909e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(groveBasin.convertToShares(initialValue), vars.expectedShares);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.convertToShares(newValue), vars.expectedShares);

        // Value change is only from creditToken exchange rate increasing
        assertEq(newValue - initialValue, vars.creditTokenAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(groveBasin.convertToShares(initialValue), vars.expectedShares);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.convertToShares(newValue), vars.expectedShares);

        // Value change is only from creditToken exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.creditTokenAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversion() internal view {
        assertEq(groveBasin.convertToShares(1), 1);
        assertEq(groveBasin.convertToShares(2), 2);
        assertEq(groveBasin.convertToShares(3), 3);
        assertEq(groveBasin.convertToShares(4), 4);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
        assertEq(groveBasin.convertToShares(2e18), 2e18);
        assertEq(groveBasin.convertToShares(3e18), 3e18);
        assertEq(groveBasin.convertToShares(4e18), 4e18);
    }

}

contract GroveBasinConvertToSharesFailureTests is GroveBasinTestBase {

    function test_convertToShares_invalidAsset() public {
        vm.expectRevert("GB/invalid-asset");
        groveBasin.convertToShares(makeAddr("new-asset"), 100);
    }

}

contract GroveBasinConvertToSharesWithCollateralTokenTests is GroveBasinConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversionCollateralToken();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        amount = _bound(amount, 0, COLLATERAL_TOKEN_MAX);
        assertEq(groveBasin.convertToShares(address(collateralToken), amount), amount);
    }

    function test_convertToShares_depositAndWithdrawCollateralTokenAndCreditToken_noChange() public {
        _assertOneToOneConversionCollateralToken();

        _deposit(address(collateralToken), address(this), 100e18);
        _assertOneToOneConversionCollateralToken();

        _deposit(address(creditToken), address(this), 80e18);
        _assertOneToOneConversionCollateralToken();

        _withdraw(address(collateralToken), address(this), 100e18);
        _assertOneToOneConversionCollateralToken();

        _withdraw(address(creditToken), address(this), 80e18);
        _assertOneToOneConversionCollateralToken();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(collateralToken),  address(this), 100e18);
        _deposit(address(creditToken), address(this), 80e18);

        _assertOneToOneConversionCollateralToken();

        // 80 creditToken now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.convertToShares(address(collateralToken), 10), 9);
        assertEq(groveBasin.convertToShares(address(collateralToken), 11), 10);
        assertEq(groveBasin.convertToShares(address(collateralToken), 12), 10);

        assertEq(groveBasin.convertToShares(address(collateralToken), 10e18), 9.090909090909090909e18);
        assertEq(groveBasin.convertToShares(address(collateralToken), 11e18), 10e18);
        assertEq(groveBasin.convertToShares(address(collateralToken), 12e18), 10.909090909090909090e18);
    }

    // NOTE: These tests will be the exact same as convertToShares(amount) tests because collateral token is an
    //       18 decimal precision asset pegged to the dollar, which is whats used for "value".

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(groveBasin.convertToShares(address(collateralToken), initialValue), vars.expectedShares);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.convertToShares(address(collateralToken), newValue), vars.expectedShares);

        // Value change is only from creditToken exchange rate increasing
        assertEq(newValue - initialValue, vars.creditTokenAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(groveBasin.convertToShares(address(collateralToken), initialValue), vars.expectedShares);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.convertToShares(address(collateralToken), newValue), vars.expectedShares);

        // Value change is only from creditToken exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.creditTokenAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversionCollateralToken() internal view {
        assertEq(groveBasin.convertToShares(address(collateralToken), 1), 1);
        assertEq(groveBasin.convertToShares(address(collateralToken), 2), 2);
        assertEq(groveBasin.convertToShares(address(collateralToken), 3), 3);
        assertEq(groveBasin.convertToShares(address(collateralToken), 4), 4);

        assertEq(groveBasin.convertToShares(address(collateralToken), 1e18), 1e18);
        assertEq(groveBasin.convertToShares(address(collateralToken), 2e18), 2e18);
        assertEq(groveBasin.convertToShares(address(collateralToken), 3e18), 3e18);
        assertEq(groveBasin.convertToShares(address(collateralToken), 4e18), 4e18);
    }

}

contract GroveBasinConvertToSharesWithSwapTokenTests is GroveBasinConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversionSwapToken();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        amount = _bound(amount, 0, SWAP_TOKEN_MAX);
        assertEq(groveBasin.convertToShares(address(swapToken), amount), amount * 1e12);
    }

    function test_convertToShares_depositAndWithdrawSwapTokenAndCreditToken_noChange() public {
        _assertOneToOneConversionSwapToken();

        _deposit(address(swapToken), address(this), 100e6);
        _assertOneToOneConversionSwapToken();

        _deposit(address(creditToken), address(this), 80e18);
        _assertOneToOneConversionSwapToken();

        _withdraw(address(swapToken), address(this), 100e6);
        _assertOneToOneConversionSwapToken();

        _withdraw(address(creditToken), address(this), 80e18);
        _assertOneToOneConversionSwapToken();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(swapToken),  address(this), 100e6);
        _deposit(address(creditToken), address(this), 80e18);

        _assertOneToOneConversionSwapToken();

        // 80 creditToken now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.convertToShares(address(swapToken), 10), 9.090909090909e12);
        assertEq(groveBasin.convertToShares(address(swapToken), 11), 10e12);
        assertEq(groveBasin.convertToShares(address(swapToken), 12), 10.909090909090e12);

        assertEq(groveBasin.convertToShares(address(swapToken), 10e6), 9.090909090909090909e18);
        assertEq(groveBasin.convertToShares(address(swapToken), 11e6), 10e18);
        assertEq(groveBasin.convertToShares(address(swapToken), 12e6), 10.909090909090909090e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // Precision is lost when using 1e6 so expectedShares have to be adjusted accordingly
        // but this represents a 1:1 exchange rate in 1e6 precision
        assertEq(
            groveBasin.convertToShares(address(swapToken), initialValue / 1e12),
            vars.expectedShares / 1e12 * 1e12
        );

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        // Larger rounding error because of 1e6 precision
        assertApproxEqAbs(
            groveBasin.convertToShares(address(swapToken), newValue / 1e12),
            vars.expectedShares,
            1e12
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            groveBasin.convertToShares(address(swapToken), newValue / 1e12),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            groveBasin.convertToShares(address(swapToken), newValue / 1e12),
            (newValue / 1e12 * 1e12) * vars.expectedShares / newValue
        );

        // Value change is only from creditToken exchange rate increasing
        assertEq(newValue - initialValue, vars.creditTokenAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // Precision is lost when using 1e6 so expectedShares have to be adjusted accordingly
        // but this represents a 1:1 exchange rate in 1e6 precision
        assertEq(
            groveBasin.convertToShares(address(swapToken), initialValue / 1e12),
            vars.expectedShares / 1e12 * 1e12
        );

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        // Rounding scales with difference between expectedShares and newValue
        assertApproxEqAbs(
            groveBasin.convertToShares(address(swapToken), newValue / 1e12),
            vars.expectedShares,
            1e12 + initialValue * 1e18 / newValue
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            groveBasin.convertToShares(address(swapToken), newValue / 1e12),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            groveBasin.convertToShares(address(swapToken), newValue / 1e12),
            (newValue / 1e12 * 1e12) * vars.expectedShares / newValue
        );

        // Value change is only from creditToken exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.creditTokenAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversionSwapToken() internal view {
        assertEq(groveBasin.convertToShares(address(swapToken), 1), 1e12);
        assertEq(groveBasin.convertToShares(address(swapToken), 2), 2e12);
        assertEq(groveBasin.convertToShares(address(swapToken), 3), 3e12);
        assertEq(groveBasin.convertToShares(address(swapToken), 4), 4e12);

        assertEq(groveBasin.convertToShares(address(swapToken), 1e6), 1e18);
        assertEq(groveBasin.convertToShares(address(swapToken), 2e6), 2e18);
        assertEq(groveBasin.convertToShares(address(swapToken), 3e6), 3e18);
        assertEq(groveBasin.convertToShares(address(swapToken), 4e6), 4e18);
    }

}

contract GroveBasinConvertToSharesWithCreditTokenTests is GroveBasinConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    function testFuzz_convertToShares_noValue(uint256 amount, uint256 conversionRate) public {
        amount         = _bound(amount,         1000,    CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 1000e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        assertEq(groveBasin.convertToShares(address(creditToken), amount), amount * conversionRate / 1e27);
    }

    function test_convertToShares_depositAndWithdrawSwapTokenAndCreditToken_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(swapToken), address(this), 100e6);
        _assertStartingConversionCreditToken();

        _deposit(address(creditToken), address(this), 80e18);
        _assertStartingConversionCreditToken();

        _withdraw(address(swapToken), address(this), 100e6);
        _assertStartingConversionCreditToken();

        _withdraw(address(creditToken), address(this), 80e18);
        _assertStartingConversionCreditToken();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(swapToken), address(this), 100e6);
        _deposit(address(creditToken), address(this), 80e18);

        _assertStartingConversionCreditToken();

        // 80 creditToken now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10. Since 1 creditToken is now worth 1.5 SwapToken, 1 creditToken is worth
        // 1.50/1.10 = 1.3636... shares
        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.convertToShares(address(creditToken), 1), 0);
        assertEq(groveBasin.convertToShares(address(creditToken), 2), 2);
        assertEq(groveBasin.convertToShares(address(creditToken), 3), 3);  // 3 * 1.5 / 1.1 = 3 because of rounding on first operation
        assertEq(groveBasin.convertToShares(address(creditToken), 4), 5);

        assertEq(groveBasin.convertToShares(address(creditToken), 1e18), 1.363636363636363636e18);
        assertEq(groveBasin.convertToShares(address(creditToken), 2e18), 2.727272727272727272e18);
        assertEq(groveBasin.convertToShares(address(creditToken), 3e18), 4.090909090909090909e18);
        assertEq(groveBasin.convertToShares(address(creditToken), 4e18), 5.454545454545454545e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        // NOTE: Not using 1e27 for this test because initialCreditTokenValue needs to be different
        mockCreditTokenRateProvider.__setConversionRate(1.1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1.1e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue     = vars.expectedShares;
        uint256 initialCreditTokenValue = initialValue * 1e27 / 1.1e27;

        conversionRate = _bound(conversionRate, 1.1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertApproxEqAbs(
            groveBasin.convertToShares(address(creditToken), initialCreditTokenValue),
            vars.expectedShares,
            1
        );

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        uint256 newCreditTokenValue = newValue * 1e27 / conversionRate;

        // Depositing derived creditToken amount yields the same amount of shares (approx)
        assertApproxEqAbs(
            groveBasin.convertToShares(address(creditToken), newCreditTokenValue),
            vars.expectedShares,
            1000
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            groveBasin.convertToShares(address(creditToken), newCreditTokenValue),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            groveBasin.convertToShares(address(creditToken), newCreditTokenValue),
            (newCreditTokenValue * conversionRate / 1e27) * vars.expectedShares / newValue
        );

        // Value change is only from creditToken exchange rate increasing
        assertApproxEqAbs(
            newValue - initialValue,
            vars.creditTokenAmount * (conversionRate - 1.1e27) / 1e27,
            3
        );
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        mockCreditTokenRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            collateralTokenAmount,
            swapTokenAmount,
            creditTokenAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue      = vars.expectedShares;
        uint256 initialCreditTokenValue = initialValue * 1e27 / 2e27;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertApproxEqAbs(
            groveBasin.convertToShares(address(creditToken), initialCreditTokenValue),
            vars.expectedShares,
            1
        );

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.collateralTokenAmount + vars.swapTokenAmount * 1e12 + vars.creditTokenAmount * conversionRate / 1e27;

        uint256 newCreditTokenValue = newValue * 1e27 / conversionRate;

        // Depositing derived creditToken amount yields the same amount of shares (approx)
        assertApproxEqAbs(
            groveBasin.convertToShares(address(creditToken), newCreditTokenValue),
            vars.expectedShares,
            2000
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            groveBasin.convertToShares(address(creditToken), newCreditTokenValue),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            groveBasin.convertToShares(address(creditToken), newCreditTokenValue),
            (newCreditTokenValue * conversionRate / 1e27) * vars.expectedShares / newValue
        );

        // Value change is only from creditToken exchange rate increasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.creditTokenAmount * (2e27 - conversionRate) / 1e27,
            3
        );
    }

    function _assertOneToOneConversion() internal view {
        assertEq(groveBasin.convertToShares(1), 1);
        assertEq(groveBasin.convertToShares(2), 2);
        assertEq(groveBasin.convertToShares(3), 3);
        assertEq(groveBasin.convertToShares(4), 4);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
        assertEq(groveBasin.convertToShares(2e18), 2e18);
        assertEq(groveBasin.convertToShares(3e18), 3e18);
        assertEq(groveBasin.convertToShares(4e18), 4e18);
    }

    // NOTE: This is different because the dollar value of creditToken is 1.25x that of SwapToken
    function _assertStartingConversionCreditToken() internal view {
        assertEq(groveBasin.convertToShares(address(creditToken), 1), 1);
        assertEq(groveBasin.convertToShares(address(creditToken), 2), 2);
        assertEq(groveBasin.convertToShares(address(creditToken), 3), 3);
        assertEq(groveBasin.convertToShares(address(creditToken), 4), 5);

        assertEq(groveBasin.convertToShares(address(creditToken), 1e18), 1.25e18);
        assertEq(groveBasin.convertToShares(address(creditToken), 2e18), 2.5e18);
        assertEq(groveBasin.convertToShares(address(creditToken), 3e18), 3.75e18);
        assertEq(groveBasin.convertToShares(address(creditToken), 4e18), 5e18);
    }

}
