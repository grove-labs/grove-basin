// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { Math }        from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IGroveBasin }  from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPreviewSwapExactIn_FailureTests is GroveBasinTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactIn(makeAddr("other-token"), address(swapToken), 1);
    }

    function test_previewSwapExactIn_invalidAssetOut() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactIn(address(swapToken), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactIn_bothSwapToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactIn(address(swapToken), address(swapToken), 1);
    }

    function test_previewSwapExactIn_bothCollateralToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactIn(address(collateralToken), address(collateralToken), 1);
    }

    function test_previewSwapExactIn_bothCreditToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactIn(address(creditToken), address(creditToken), 1);
    }

    function test_previewSwapExactIn_collateralTokenToSwapToken() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactIn(address(collateralToken), address(swapToken), 1);
    }

    function test_previewSwapExactIn_swapTokenToCollateralToken() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactIn(address(swapToken), address(collateralToken), 1);
    }

    function test_previewSwapExactIn_globalPaused() public {
        address pauser = makeAddr("pauser");
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), pauser);
        vm.stopPrank();
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0), true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 1e6);
    }

    function test_previewSwapExactIn_directionPaused() public {
        address pauser = makeAddr("pauser");
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), pauser);
        vm.stopPrank();
        vm.startPrank(pauser);
        groveBasin.setPaused(groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT(), true);
        vm.stopPrank();

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 1e6);
    }

}

contract GroveBasinPreviewSwapExactOut_FailureTests is GroveBasinTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactOut(makeAddr("other-token"), address(swapToken), 1);
    }

    function test_previewSwapExactOut_invalidAssetOut() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactOut(address(swapToken), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactOut_bothSwapToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactOut(address(collateralToken), address(collateralToken), 1);
    }

    function test_previewSwapExactOut_bothCollateralToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactOut(address(swapToken), address(swapToken), 1);
    }

    function test_previewSwapExactOut_bothCreditToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.previewSwapExactOut(address(creditToken), address(creditToken), 1);
    }

    function test_previewSwapExactOut_collateralTokenToSwapToken() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactOut(address(collateralToken), address(swapToken), 1);
    }

    function test_previewSwapExactOut_swapTokenToCollateralToken() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactOut(address(swapToken), address(collateralToken), 1);
    }

    function test_previewSwapExactOut_globalPaused() public {
        address pauser = makeAddr("pauser");
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), pauser);
        vm.stopPrank();
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0), true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 1e18);
    }

    function test_previewSwapExactOut_directionPaused() public {
        address pauser = makeAddr("pauser");
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), pauser);
        vm.stopPrank();
        vm.startPrank(pauser);
        groveBasin.setPaused(groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT(), true);
        vm.stopPrank();

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 1e18);
    }

}

contract GroveBasinPreviewSwapExactIn_CollateralTokenAssetInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_collateralTokenToSwapToken_reverts() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactIn(address(collateralToken), address(swapToken), 1e18);
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

    function test_previewSwapExactOut_collateralTokenToSwapToken_reverts() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactOut(address(collateralToken), address(swapToken), 1e6);
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
        amountOut      = _bound(amountOut,      1,         SWAP_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * conversionRate / 1e27;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(collateralToken), address(creditToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

}

contract GroveBasinPreviewSwapExactIn_SwapTokenInTests is GroveBasinTestBase {

    function test_previewSwapExactIn_swapTokenToCollateralToken_reverts() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactIn(address(swapToken), address(collateralToken), 1e6);
    }

    function test_previewSwapExactIn_swapTokenToCreditToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 1e6 - 1), 799999200000000000);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 1e6),     0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 1e6 + 1), 800000800000000000);

        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 1e6), 0.8e18);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 2e6), 1.6e18);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 3e6), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_swapTokenToCreditToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SWAP_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        // Use mulDiv for precise calculation: amount * swapRate * creditPrecision / (creditRate * swapPrecision)
        uint256 amountOut = (amountIn * 1e27 * 1e18) / (conversionRate * 1e6);

        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), amountIn), amountOut);
    }

}

contract GroveBasinPreviewSwapExactOut_SwapTokenInTests is GroveBasinTestBase {

    function test_previewSwapExactOut_swapTokenToCollateralToken_reverts() public {
        vm.expectRevert(IGroveBasin.InvalidSwap.selector);
        groveBasin.previewSwapExactOut(address(swapToken), address(collateralToken), 1e18);
    }

    function test_previewSwapExactOut_swapTokenToCreditToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 1e18 - 1), 1.25e6);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 1e18),     1.25e6);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 1e18 + 1), 1.25e6 + 1);

        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 0.8e18), 1e6);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 1.6e18), 2e6);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 2.4e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_swapTokenToCreditToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,     1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        // Using raw calculation to demo rounding
        uint256 expectedAmountIn = amountOut * conversionRate / 1e27 / 1e12;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_demoRoundingUp_swapTokenToCreditToken() public view {
        uint256 expectedAmountIn1 = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 0.8e18);
        uint256 expectedAmountIn2 = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 0.8e18 + 1);
        uint256 expectedAmountIn3 = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 0.8e18 + 0.8e12);
        uint256 expectedAmountIn4 = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 0.8e18 + 0.8e12 + 1);

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

    function test_previewSwapExactIn_creditTokenToSwapToken() public view {
        // Demo rounding down
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 1e18 - 1), 1.25e6 - 1);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 1e18),     1.25e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 1e18 + 1), 1.25e6);

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 1e18), 1.25e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 2e18), 2.5e6);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 3e18), 3.75e6);
    }

    function testFuzz_previewSwapExactIn_creditTokenToSwapToken(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), amountIn), amountOut);
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

    function test_previewSwapExactOut_creditTokenToSwapToken() public view {
        // Demo rounding up
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 1e6 - 1), 799_999_200_000_000_000);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 1e6),     0.8e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 1e6 + 1), 800_000_800_000_000_000);

        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 1.25e6), 1e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 2.5e6),  2e18);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 3.75e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_creditTokenToSwapToken(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = bound(amountOut,      1,         SWAP_TOKEN_MAX);
        conversionRate = bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = Math.mulDiv(amountOut, 1e27 * 1e18, conversionRate * 1e6);

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), amountOut);

        // Allow for rounding error of +1 upwards (single ceil)
        assertLe(amountIn - expectedAmountIn, 1);
    }

}
