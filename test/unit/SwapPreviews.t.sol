// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPreviewSwapExactIn_FailureTests is GroveBasinTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(makeAddr("other-token"), address(secondaryToken), 1);
    }

    function test_previewSwapExactIn_invalidAssetOut() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(secondaryToken), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactIn_bothSecondaryToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(secondaryToken), address(secondaryToken), 1);
    }

    function test_previewSwapExactIn_bothCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(collateralToken), address(collateralToken), 1);
    }

    function test_previewSwapExactIn_bothCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(creditToken), address(creditToken), 1);
    }

    function test_previewSwapExactIn_collateralTokenToSecondaryToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactIn(address(collateralToken), address(secondaryToken), 1);
    }

    function test_previewSwapExactIn_secondaryTokenToCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactIn(address(secondaryToken), address(collateralToken), 1);
    }

}

contract GroveBasinPreviewSwapExactOut_FailureTests is GroveBasinTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(makeAddr("other-token"), address(secondaryToken), 1);
    }

    function test_previewSwapExactOut_invalidAssetOut() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(secondaryToken), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactOut_bothSecondaryToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(collateralToken), address(collateralToken), 1);
    }

    function test_previewSwapExactOut_bothCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(secondaryToken), address(secondaryToken), 1);
    }

    function test_previewSwapExactOut_bothCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(creditToken), address(creditToken), 1);
    }

    function test_previewSwapExactOut_collateralTokenToSecondaryToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactOut(address(collateralToken), address(secondaryToken), 1);
    }

    function test_previewSwapExactOut_secondaryTokenToCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactOut(address(secondaryToken), address(collateralToken), 1);
    }

}

contract GroveBasinPreviewSwapExactIn_CollateralTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_collateralTokenToSecondaryToken_reverts() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactIn(address(collateralToken), address(secondaryToken), 1e18);
    }

    function test_previewSwapExactIn_collateralTokenToCreditToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 1e18 - 1), 0.8e18 - 1);
        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 1e18),     0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 1e18 + 1), 0.8e18);

        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 1e18), 0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 2e18), 1.6e18);
        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 3e18), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_collateralTokenToCreditToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         COLLATERAL_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        assertEq(groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_CollateralTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_collateralTokenToSecondaryToken_reverts() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactOut(address(collateralToken), address(secondaryToken), 1e6);
    }

    function test_previewSwapExactOut_collateralTokenToCreditToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), 1e18 - 1), 1.25e18 - 1);
        assertEq(groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), 1e18),     1.25e18);
        assertEq(groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), 1e18 + 1), 1.25e18 + 2);

        assertEq(groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), 0.8e18), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), 1.6e18), 2e18);
        assertEq(groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), 2.4e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_collateralTokenToCreditToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         SECONDARY_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * conversionRate / 1e27;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

}

contract GroveBasinPreviewSwapExactIn_SecondaryTokenInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_secondaryTokenToCollateralToken_reverts() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactIn(address(secondaryToken), address(collateralToken), 1e6);
    }

    function test_previewSwapExactIn_secondaryTokenToCreditToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 1e6 - 1), 0.799999e18);
        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 1e6),     0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 1e6 + 1), 0.8e18);

        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 1e6), 0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 2e6), 1.6e18);
        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), 3e6), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_secondaryTokenToCreditToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SECONDARY_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        assertEq(groveBasin.previewSwapExactIn(address(secondaryToken), address(creditToken), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_SecondaryTokenInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_secondaryTokenToCollateralToken_reverts() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.previewSwapExactOut(address(secondaryToken), address(collateralToken), 1e18);
    }

    function test_previewSwapExactOut_secondaryTokenToCreditToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 1e18 - 1), 1.25e6);
        assertEq(groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 1e18),     1.25e6);
        assertEq(groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 1e18 + 1), 1.25e6 + 1);

        assertEq(groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 0.8e18), 1e6);
        assertEq(groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 1.6e18), 2e6);
        assertEq(groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 2.4e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_secondaryTokenToCreditToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,     1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        // Using raw calculation to demo rounding
        uint256 expectedAmountIn = amountOut * conversionRate / 1e27 / 1e12;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_demoRoundingUp_secondaryTokenToCreditToken() public view {
        uint256 expectedAmountIn1 = groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 0.8e18);
        uint256 expectedAmountIn2 = groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 0.8e18 + 1);
        uint256 expectedAmountIn3 = groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 0.8e18 + 0.8e12);
        uint256 expectedAmountIn4 = groveBasin.previewSwapExactOut(address(secondaryToken), address(creditToken), 0.8e18 + 0.8e12 + 1);

        assertEq(expectedAmountIn1, 1e6);
        assertEq(expectedAmountIn2, 1e6 + 1);
        assertEq(expectedAmountIn3, 1e6 + 1);
        assertEq(expectedAmountIn4, 1e6 + 2);
    }

}

contract GroveBasinPreviewSwapExactIn_CreditTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_creditTokenToCollateralToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 1e18 - 1), 1.25e18 - 2);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 1e18),     1.25e18);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 1e18 + 1), 1.25e18 + 1);

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 1e18), 1.25e18);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 2e18), 2.5e18);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 3e18), 3.75e18);
    }

    function testFuzz_previewSwapExactIn_creditTokenToCollateralToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), amountIn), amountOut);
    }

    function test_previewSwapExactIn_creditTokenToSecondaryToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 1e18 - 1), 1.25e6 - 1);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 1e18),     1.25e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 1e18 + 1), 1.25e6);

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 1e18), 1.25e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 2e18), 2.5e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), 3e18), 3.75e6);
    }

    function testFuzz_previewSwapExactIn_creditTokenToSecondaryToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(secondaryToken), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_CreditTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_creditTokenToCollateralToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), 1e18 - 1), 0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), 1e18),     0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), 1e18 + 1), 0.8e18 + 1);

        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), 1.25e18), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), 2.5e18),  2e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), 3.75e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_creditTokenToCollateralToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         COLLATERAL_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * 1e27 / conversionRate;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(collateralToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_previewSwapExactOut_creditTokenToSecondaryToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), 1e6 - 1), 0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), 1e6),     0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), 1e6 + 1), 0.800001e18);

        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), 1.25e6), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), 2.5e6),  2e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), 3.75e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_creditTokenToSecondaryToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = bound(amountOut,      1,         SECONDARY_TOKEN_MAX);
        conversionRate = bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * 1e27 / conversionRate * 1e12;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(secondaryToken), amountOut);

        // Allow for rounding error of 1e12 upwards
        assertLe(amountIn - expectedAmountIn, 1e12);
    }

}
