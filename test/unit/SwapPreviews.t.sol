// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPreviewSwapExactIn_FailureTests is GroveBasinTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwapExactIn_invalidAssetOut() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(usdc), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactIn_bothUsdc() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(usdc), address(usdc), 1);
    }

    function test_previewSwapExactIn_bothUsds() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(usds), address(usds), 1);
    }

    function test_previewSwapExactIn_bothCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactIn(address(creditToken), address(creditToken), 1);
    }

}

contract GroveBasinPreviewSwapExactOut_FailureTests is GroveBasinTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwapExactOut_invalidAssetOut() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(usdc), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactOut_bothUsdc() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(usds), address(usds), 1);
    }

    function test_previewSwapExactOut_bothUsds() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(usdc), address(usdc), 1);
    }

    function test_previewSwapExactOut_bothCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.previewSwapExactOut(address(creditToken), address(creditToken), 1);
    }

}

contract GroveBasinPreviewSwapExactIn_UsdsAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_usdsToUsdc() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 1e18 - 1), 1e6 - 1);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 1e18),     1e6);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 1e18 + 1), 1e6);

        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 1e12 - 1), 0);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 1e12),     1);

        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 1e18), 1e6);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 2e18), 2e6);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), 3e18), 3e6);
    }

    function testFuzz_previewSwapExactIn_usdsToUsdc(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDS_TOKEN_MAX);

        assertEq(groveBasin.previewSwapExactIn(address(usds), address(usdc), amountIn), amountIn / 1e12);
    }

    function test_previewSwapExactIn_usdsToCreditToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), 1e18 - 1), 0.8e18 - 1);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), 1e18),     0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), 1e18 + 1), 0.8e18);

        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), 1e18), 0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), 2e18), 1.6e18);
        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), 3e18), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_usdsToCreditToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        assertEq(groveBasin.previewSwapExactIn(address(usds), address(creditToken), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_UsdsAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_usdsToUsdc() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), 1e6 - 1), 0.999999e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), 1e6),     1e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), 1e6 + 1), 1.000001e18);

        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), 1e6), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), 2e6), 2e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), 3e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_usdsToUsdc(uint256 amountOut) public view {
        amountOut = _bound(amountOut, 0, USDC_TOKEN_MAX);

        assertEq(groveBasin.previewSwapExactOut(address(usds), address(usdc), amountOut), amountOut * 1e12);
    }

    function test_previewSwapExactOut_usdsToCreditToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(creditToken), 1e18 - 1), 1.25e18 - 1);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(creditToken), 1e18),     1.25e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(creditToken), 1e18 + 1), 1.25e18 + 2);

        assertEq(groveBasin.previewSwapExactOut(address(usds), address(creditToken), 0.8e18), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(creditToken), 1.6e18), 2e18);
        assertEq(groveBasin.previewSwapExactOut(address(usds), address(creditToken), 2.4e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_usdsToCreditToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * conversionRate / 1e27;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(usds), address(creditToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

}

contract GroveBasinPreviewSwapExactIn_USDCAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_usdcToUsds() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), 1e6 - 1), 0.999999e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), 1e6),     1e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), 1e6 + 1), 1.000001e18);

        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), 1e6), 1e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), 2e6), 2e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), 3e6), 3e18);
    }

    function testFuzz_previewSwapExactIn_usdcToUsds(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDC_TOKEN_MAX);

        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(usds), amountIn), amountIn * 1e12);
    }

    function test_previewSwapExactIn_usdcToCreditToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 1e6 - 1), 0.799999e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 1e6),     0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 1e6 + 1), 0.8e18);

        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 1e6), 0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 2e6), 1.6e18);
        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 3e6), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_usdcToCreditToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        assertEq(groveBasin.previewSwapExactIn(address(usdc), address(creditToken), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_USDCAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_usdcToUsds() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18 - 1), 1e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18),     1e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1), 1e6 + 1);

        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18), 1e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(usds), 2e18), 2e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(usds), 3e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_usdcToUsds(uint256 amountOut) public view {
        amountOut = _bound(amountOut, 0, USDS_TOKEN_MAX);

        uint256 amountIn = groveBasin.previewSwapExactOut(address(usdc), address(usds), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - amountOut / 1e12, 1);
    }

    function test_previewSwapExactOut_usdcToCreditToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 1e18 - 1), 1.25e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 1e18),     1.25e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 1e18 + 1), 1.25e6 + 1);

        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 0.8e18), 1e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 1.6e18), 2e6);
        assertEq(groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 2.4e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_usdcToCreditToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,     1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        // Using raw calculation to demo rounding
        uint256 expectedAmountIn = amountOut * conversionRate / 1e27 / 1e12;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(usdc), address(creditToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_demoRoundingUp_usdcToCreditToken() public view {
        uint256 expectedAmountIn1 = groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 0.8e18);
        uint256 expectedAmountIn2 = groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 0.8e18 + 1);
        uint256 expectedAmountIn3 = groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 0.8e18 + 0.8e12);
        uint256 expectedAmountIn4 = groveBasin.previewSwapExactOut(address(usdc), address(creditToken), 0.8e18 + 0.8e12 + 1);

        assertEq(expectedAmountIn1, 1e6);
        assertEq(expectedAmountIn2, 1e6 + 1);
        assertEq(expectedAmountIn3, 1e6 + 1);
        assertEq(expectedAmountIn4, 1e6 + 2);
    }

    function test_demoRoundingUp_usdcToUsds() public view {
        uint256 expectedAmountIn1 = groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18);
        uint256 expectedAmountIn2 = groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1);
        uint256 expectedAmountIn3 = groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1e12);
        uint256 expectedAmountIn4 = groveBasin.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1e12 + 1);

        assertEq(expectedAmountIn1, 1e6);
        assertEq(expectedAmountIn2, 1e6 + 1);
        assertEq(expectedAmountIn3, 1e6 + 1);
        assertEq(expectedAmountIn4, 1e6 + 2);
    }

}

contract GroveBasinPreviewSwapExactIn_CreditTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_creditTokenToUsds() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), 1e18 - 1), 1.25e18 - 2);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), 1e18),     1.25e18);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), 1e18 + 1), 1.25e18 + 1);

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), 1e18), 1.25e18);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), 2e18), 2.5e18);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), 3e18), 3.75e18);
    }

    function testFuzz_previewSwapExactIn_creditTokenToUsds(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usds), amountIn), amountOut);
    }

    function test_previewSwapExactIn_creditTokenToUsdc() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), 1e18 - 1), 1.25e6 - 1);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), 1e18),     1.25e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), 1e18 + 1), 1.25e6);

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), 1e18), 1.25e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), 2e18), 2.5e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), 3e18), 3.75e6);
    }

    function testFuzz_previewSwapExactIn_creditTokenToUsdc(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(usdc), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_CreditTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_creditTokenToUsds() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usds), 1e18 - 1), 0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usds), 1e18),     0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usds), 1e18 + 1), 0.8e18 + 1);

        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usds), 1.25e18), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usds), 2.5e18),  2e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usds), 3.75e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_creditTokenToUsds(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * 1e27 / conversionRate;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(usds), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_previewSwapExactOut_creditTokenToUsdc() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usdc), 1e6 - 1), 0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usdc), 1e6),     0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usdc), 1e6 + 1), 0.800001e18);

        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usdc), 1.25e6), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usdc), 2.5e6),  2e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(usdc), 3.75e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_creditTokenToUsdc(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = bound(amountOut,      1,         USDC_TOKEN_MAX);
        conversionRate = bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * 1e27 / conversionRate * 1e12;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(usdc), amountOut);

        // Allow for rounding error of 1e12 upwards
        assertLe(amountIn - expectedAmountIn, 1e12);
    }

}
