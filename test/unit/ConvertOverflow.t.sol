// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinConvertOverflowTests is GroveBasinTestBase {

    // Rate of 1_000_000x in 1e27 precision triggers overflow in the numerator
    // product: rateIn * tokenPrecisionOut * ratePrecisionOut = 1e33 * 1e18 * 1e27 = 1e78 > uint256 max.
    function test_convert_highRateProvider_doesNotOverflow() public {
        mockSwapTokenRateProvider.__setConversionRate(1_000_000e27);

        uint256 amountOut = groveBasin.previewSwapExactIn(
            address(swapToken),
            address(creditToken),
            1e6
        );

        assertGt(amountOut, 0);
    }

    // With two high-precision rates on both sides, the denominator can also overflow.
    function test_convert_highRateBothSides_doesNotOverflow() public {
        mockSwapTokenRateProvider.__setConversionRate(1_000_000e27);
        mockCreditTokenRateProvider.__setConversionRate(2_000_000e27);

        uint256 amountOut = groveBasin.previewSwapExactIn(
            address(swapToken),
            address(creditToken),
            1e6
        );

        assertGt(amountOut, 0);
    }

    function test_convert_highRate_roundUp_doesNotOverflow() public {
        mockSwapTokenRateProvider.__setConversionRate(1_000_000e27);

        uint256 amountIn = groveBasin.previewSwapExactOut(
            address(swapToken),
            address(creditToken),
            1e18
        );

        assertGt(amountIn, 0);
    }

}
