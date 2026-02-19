// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

contract SwapperHandler is HandlerBase {

    MockERC20[3] public assets;

    address[] public swappers;

    IRateProviderLike public creditTokenRateProvider;

    mapping(address user => mapping(address asset => uint256 deposits)) public swapsIn;
    mapping(address user => mapping(address asset => uint256 deposits)) public swapsOut;

    mapping(address user => uint256) public valueSwappedIn;
    mapping(address user => uint256) public valueSwappedOut;
    mapping(address user => uint256) public swapperSwapCount;

    // Used for assertions, assumption made that LpHandler is used with at least 1 LP.
    address public lp0;

    uint256 public swapCount;
    uint256 public zeroBalanceCount;

    constructor(
        GroveBasin      groveBasin_,
        MockERC20 secondaryToken,
        MockERC20 collateralToken,
        MockERC20 creditToken,
        uint256   swapperCount
    ) HandlerBase(groveBasin_) {
        assets[0] = secondaryToken;
        assets[1] = collateralToken;
        assets[2] = creditToken;

        creditTokenRateProvider = IRateProviderLike(groveBasin.creditTokenRateProvider());

        for (uint256 i = 0; i < swapperCount; i++) {
            swappers.push(makeAddr(string(abi.encodePacked("swapper-", vm.toString(i)))));
        }

        // Derive LP-0 address for assertion
        lp0 = makeAddr("lp-0");
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function _getSwapper(uint256 indexSeed) internal view returns (address) {
        return swappers[indexSeed % swappers.length];
    }

    function swapExactIn(
        uint256 assetInSeed,
        uint256 assetOutSeed,
        uint256 swapperSeed,
        uint256 amountIn,
        uint256 minAmountOut
    )
        public
    {
        // 1. Setup and bounds

        // Prevent overflow in if statement below
        assetOutSeed = _bound(assetOutSeed, 0, type(uint256).max - 2);

        MockERC20 assetIn  = _getAsset(assetInSeed);
        MockERC20 assetOut = _getAsset(assetOutSeed);
        address   swapper  = _getSwapper(swapperSeed);

        // Handle case where randomly selected assets match
        if (assetIn == assetOut) {
            assetOut = _getAsset(assetOutSeed + 2);
        }

        address assetOutCustodian
            = address(assetOut) == address(assets[0]) ? groveBasin.pocket() : address(groveBasin);

        // By calculating the amount of assetIn we can get from the max asset out, we can
        // determine the max amount of assetIn we can swap since its the same both ways.
        uint256 maxAmountIn = groveBasin.previewSwapExactIn(
            address(assetOut),
            address(assetIn),
            assetOut.balanceOf(assetOutCustodian)
        );

        // If there's zero balance a swap can't be performed
        if (maxAmountIn == 0) {
            zeroBalanceCount++;
            return;
        }

        amountIn = _bound(amountIn, 1, maxAmountIn);

        // Fuzz between zero and the expected amount out from the swap
        minAmountOut = _bound(
            minAmountOut,
            0,
            groveBasin.previewSwapExactIn(address(assetIn), address(assetOut), amountIn)
        );

        // 2. Cache starting state
        uint256 startingConversion        = groveBasin.convertToAssetValue(1e18);
        uint256 startingConversionMillion = groveBasin.convertToAssetValue(1e6 * 1e18);
        uint256 startingConversionLp0     = groveBasin.convertToAssetValue(groveBasin.shares(lp0));
        uint256 startingValue             = groveBasin.totalAssets();

        // 3. Perform action against protocol
        vm.startPrank(swapper);
        assetIn.mint(swapper, amountIn);
        assetIn.approve(address(groveBasin), amountIn);
        uint256 amountOut = groveBasin.swapExactIn(
            address(assetIn),
            address(assetOut),
            amountIn,
            minAmountOut,
            swapper,
            0
        );
        vm.stopPrank();

        // 4. Update ghost variable(s)
        swapsIn[swapper][address(assetIn)]   += amountIn;
        swapsOut[swapper][address(assetOut)] += amountOut;

        uint256 valueIn  = _getAssetValue(address(assetIn),  amountIn);
        uint256 valueOut = _getAssetValue(address(assetOut), amountOut);

        valueSwappedIn[swapper]  += valueIn;
        valueSwappedOut[swapper] += valueOut;

        // 5. Perform action-specific assertions

        // Rounding because of USDC precision, the conversion rate of a
        // user's position can fluctuate by up to 2e12 per 1e18 shares
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            3e12,
            "SwapperHandler/swapExactIn/conversion-rate-change"
        );

        // Demonstrate rounding scales with shares
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(1_000_000e18),
            startingConversionMillion,
            3_000_000e12, // 2e18 of value
            "SwapperHandler/swapExactIn/conversion-rate-change-million"
        );

        // Rounding is always in favour of the protocol
        assertGe(
            groveBasin.convertToAssetValue(1_000_000e18),
            startingConversionMillion,
            "SwapperHandler/swapExactIn/conversion-rate-million-decrease"
        );

        // Disregard this assertion if the LP has less than a dollar of value
        if (startingConversionLp0 > 1e18) {
            // Position values can fluctuate by up to 0.00000002% on swaps
            assertApproxEqRel(
                groveBasin.convertToAssetValue(groveBasin.shares(lp0)),
                startingConversionLp0,
                0.000002e18,
                "SwapperHandler/swapExactIn/conversion-rate-change-lp"
            );
        }

        // Rounding is always in favour of the user
        assertGe(
            groveBasin.convertToAssetValue(groveBasin.shares(lp0)),
            startingConversionLp0,
            "SwapperHandler/swapExactIn/conversion-rate-lp-decrease"
        );

        // GroveBasin value can fluctuate by up to 0.00000002% on swaps because of USDC rounding
        assertApproxEqRel(
            groveBasin.totalAssets(),
            startingValue,
            0.000002e18,
            "SwapperHandler/swapExactIn/groveBasin-total-value-change"
        );

        // Rounding is always in favour of the protocol
        assertGe(
            groveBasin.totalAssets(),
            startingValue,
            "SwapperHandler/swapExactIn/groveBasin-total-value-decrease"
        );

        // High rates introduce larger rounding errors
        uint256 rateIntroducedRounding = creditTokenRateProvider.getConversionRate() / 1e27;

        assertApproxEqAbs(
            valueIn,
            valueOut, 1e12 + rateIntroducedRounding * 1e12,
            "SwapperHandler/swapExactIn/value-mismatch"
        );

        assertGe(valueIn, valueOut, "SwapperHandler/swapExactIn/value-out-greater-than-in");

        // 6. Update metrics tracking state
        swapperSwapCount[swapper]++;
        swapCount++;
    }

    function swapExactOut(
        uint256 assetInSeed,
        uint256 assetOutSeed,
        uint256 swapperSeed,
        uint256 amountOut
    )
        public
    {
        // 1. Setup and bounds

        // Prevent overflow in if statement below
        assetOutSeed = _bound(assetOutSeed, 0, type(uint256).max - 2);

        MockERC20 assetIn  = _getAsset(assetInSeed);
        MockERC20 assetOut = _getAsset(assetOutSeed);
        address   swapper  = _getSwapper(swapperSeed);

        // Handle case where randomly selected assets match
        if (assetIn == assetOut) {
            assetOut = _getAsset(assetOutSeed + 2);
        }

        address assetOutCustodian
            = address(assetOut) == address(assets[0]) ? groveBasin.pocket() : address(groveBasin);

        // If there's zero balance a swap can't be performed
        if (assetOut.balanceOf(assetOutCustodian) == 0) {
            zeroBalanceCount++;
            return;
        }

        amountOut = _bound(amountOut, 1, assetOut.balanceOf(assetOutCustodian));

        // Not testing this functionality, just want a successful swap
        uint256 maxAmountIn = type(uint256).max;

        // 2. Cache starting state
        uint256 startingConversion        = groveBasin.convertToAssetValue(1e18);
        uint256 startingConversionMillion = groveBasin.convertToAssetValue(1e6 * 1e18);
        uint256 startingConversionLp0     = groveBasin.convertToAssetValue(groveBasin.shares(lp0));
        uint256 startingValue             = groveBasin.totalAssets();

        // 3. Perform action against protocol
        uint256 amountInNeeded = groveBasin.previewSwapExactOut(
            address(assetIn),
            address(assetOut),
            amountOut
        );

        vm.startPrank(swapper);
        assetIn.mint(swapper, amountInNeeded);
        assetIn.approve(address(groveBasin), amountInNeeded);
        uint256 amountIn = groveBasin.swapExactOut(
            address(assetIn),
            address(assetOut),
            amountOut,
            maxAmountIn,
            swapper,
            0
        );
        vm.stopPrank();

        // 4. Update ghost variable(s)
        swapsIn[swapper][address(assetIn)]   += amountIn;
        swapsOut[swapper][address(assetOut)] += amountOut;

        uint256 valueIn  = _getAssetValue(address(assetIn),  amountIn);
        uint256 valueOut = _getAssetValue(address(assetOut), amountOut);

        valueSwappedIn[swapper]  += valueIn;
        valueSwappedOut[swapper] += valueOut;

        // 5. Perform action-specific assertions

        // Rounding because of USDC precision, the conversion rate of a
        // user's position can fluctuate by up to 2e12 per 1e18 shares
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            3e12,
            "SwapperHandler/swapExactOut/conversion-rate-change"
        );

        // Demonstrate rounding scales with shares
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(1_000_000e18),
            startingConversionMillion,
            3_000_000e12, // 2e18 of value
            "SwapperHandler/swapExactOut/conversion-rate-change-million"
        );

        // Rounding is always in favour of the protocol
        assertGe(
            groveBasin.convertToAssetValue(1_000_000e18),
            startingConversionMillion,
            "SwapperHandler/swapExactOut/conversion-rate-million-decrease"
        );

        // Disregard this assertion if the LP has less than a dollar of value
        if (startingConversionLp0 > 1e18) {
            // Position values can fluctuate by up to 0.00000003% on swaps
            assertApproxEqRel(
                groveBasin.convertToAssetValue(groveBasin.shares(lp0)),
                startingConversionLp0,
                0.000003e18,
                "SwapperHandler/swapExactOut/conversion-rate-change-lp"
            );
        }

        // Rounding is always in favour of the user
        assertGe(
            groveBasin.convertToAssetValue(groveBasin.shares(lp0)),
            startingConversionLp0,
            "SwapperHandler/swapExactOut/conversion-rate-lp-decrease"
        );

        // GroveBasin value can fluctuate by up to 0.00000003% on swaps because of USDC rounding
        assertApproxEqRel(
            groveBasin.totalAssets(),
            startingValue,
            0.000003e18,
            "SwapperHandler/swapExactOut/groveBasin-total-value-change"
        );

        // Rounding is always in favour of the protocol
        assertGe(
            groveBasin.totalAssets(),
            startingValue,
            "SwapperHandler/swapExactOut/groveBasin-total-value-decrease"
        );

        // High rates introduce larger rounding errors
        uint256 rateIntroducedRounding = creditTokenRateProvider.getConversionRate() / 1e27;

        assertApproxEqAbs(
            valueIn,
            valueOut, 1e12 + rateIntroducedRounding * 1e12,
            "SwapperHandler/swapExactOut/value-mismatch"
        );

        assertGe(valueIn, valueOut, "SwapperHandler/swapExactOut/value-out-greater-than-in");

        // 6. Update metrics tracking state
        swapperSwapCount[swapper]++;
        swapCount++;
    }

    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        if      (asset == address(assets[0])) return amount * 1e12;
        else if (asset == address(assets[1])) return amount;
        else if (asset == address(assets[2])) return amount * creditTokenRateProvider.getConversionRate() / 1e27;
        else revert("SwapperHandler/asset-not-found");
    }

}
