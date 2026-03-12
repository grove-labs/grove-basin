// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

/// @dev SwapperHandler variant with fee-aware per-action assertions. When purchase/redemption fees
///      are non-zero, each swap accrues fee revenue to the Basin. This increases totalAssets and
///      the share price by the fee amount. The standard SwapperHandler's tight tolerances (3e12)
///      are insufficient; this handler uses fee-proportional tolerances instead.
contract FeeAwareSwapperHandler is HandlerBase {

    MockERC20[3] public assets;

    address[] public swappers;

    IRateProviderLike public swapTokenRateProvider;
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

    // Ghost counter tracking number of preview/execute consistency checks performed.
    uint256 public previewConsistencyCheckCount;

    constructor(
        GroveBasin      groveBasin_,
        MockERC20 swapToken,
        MockERC20 collateralToken,
        MockERC20 creditToken,
        uint256   swapperCount
    ) HandlerBase(groveBasin_) {
        assets[0] = swapToken;
        assets[1] = collateralToken;
        assets[2] = creditToken;

        swapTokenRateProvider = IRateProviderLike(groveBasin.swapTokenRateProvider());
        creditTokenRateProvider    = IRateProviderLike(groveBasin.creditTokenRateProvider());

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

        // Skip stable-to-stable swaps (collateralToken <-> swapToken)
        if (assetIn != assets[2] && assetOut != assets[2]) {
            assetOut = assets[2];
        }

        address assetOutCustodian
            = address(assetOut) == address(assets[0]) ? groveBasin.pocket() : address(groveBasin);

        uint256 maxAmountIn;
        {
            uint256 cappedOutBalance = _capAmountToMaxSwapSize(
                address(assetOut),
                assetOut.balanceOf(assetOutCustodian)
            );

            if (cappedOutBalance == 0) {
                zeroBalanceCount++;
                return;
            }

            maxAmountIn = groveBasin.previewSwapExactIn(
                address(assetOut),
                address(assetIn),
                cappedOutBalance
            );
        }

        if (maxAmountIn == 0) {
            zeroBalanceCount++;
            return;
        }

        amountIn = _bound(amountIn, 1, maxAmountIn);

        amountIn = _capAmountToMaxSwapSize(address(assetIn), amountIn);

        if (amountIn == 0) {
            zeroBalanceCount++;
            return;
        }

        minAmountOut = _bound(
            minAmountOut,
            0,
            groveBasin.previewSwapExactIn(address(assetIn), address(assetOut), amountIn)
        );

        // 2. Cache starting state
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);
        uint256 startingValue      = groveBasin.totalAssets();

        // 3. Preview before swap, execute, and assert preview/execute consistency.
        //    Scoped to avoid stack-too-deep.
        uint256 amountOut;
        {
            uint256 previewAmountOut = groveBasin.previewSwapExactIn(
                address(assetIn), address(assetOut), amountIn
            );

            vm.startPrank(swapper);
            assetIn.mint(swapper, amountIn);
            assetIn.approve(address(groveBasin), amountIn);
            amountOut = groveBasin.swapExactIn(
                address(assetIn), address(assetOut), amountIn, minAmountOut, swapper, 0
            );
            vm.stopPrank();

            // Assert preview/execute consistency
            assertEq(previewAmountOut, amountOut, "FeeAwareSwapperHandler/swapExactIn/preview-execute-mismatch");
            previewConsistencyCheckCount++;
        }

        // 4. Update ghost variable(s)
        swapsIn[swapper][address(assetIn)]   += amountIn;
        swapsOut[swapper][address(assetOut)] += amountOut;

        uint256 valueIn  = _getAssetValue(address(assetIn),  amountIn);
        uint256 valueOut = _getAssetValue(address(assetOut), amountOut);

        valueSwappedIn[swapper]  += valueIn;
        valueSwappedOut[swapper] += valueOut;

        // 5. Perform action-specific assertions

        // Fee revenue increases the conversion rate and total value. The increase is bounded by
        // the fee percentage (up to 5%) of the swap value, plus rounding.
        uint256 feeToleranceValue = valueIn * 500 / 10_000;  // Max 5% fee
        uint256 feeTolerance      = feeToleranceValue + 3e12;

        assertApproxEqAbs(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            feeTolerance,
            "FeeAwareSwapperHandler/swapExactIn/conversion-rate-change"
        );

        // Rounding + fee revenue always increases share price
        assertGe(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            "FeeAwareSwapperHandler/swapExactIn/conversion-rate-decrease"
        );

        // Total value can increase by fee revenue
        assertGe(
            groveBasin.totalAssets(),
            startingValue,
            "FeeAwareSwapperHandler/swapExactIn/groveBasin-total-value-decrease"
        );

        // Value in always >= value out (fees + rounding favour protocol)
        uint256 rateIntroducedRounding = creditTokenRateProvider.getConversionRate() / 1e27;

        assertGe(valueIn, valueOut, "FeeAwareSwapperHandler/swapExactIn/value-out-greater-than-in");

        // 6. Update metrics tracking state
        _updateSharePrice();
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

        // Skip stable-to-stable swaps (collateralToken <-> swapToken)
        if (assetIn != assets[2] && assetOut != assets[2]) {
            assetOut = assets[2];
        }

        address assetOutCustodian
            = address(assetOut) == address(assets[0]) ? groveBasin.pocket() : address(groveBasin);

        if (assetOut.balanceOf(assetOutCustodian) == 0) {
            zeroBalanceCount++;
            return;
        }

        amountOut = _bound(amountOut, 1, assetOut.balanceOf(assetOutCustodian));

        amountOut = _capAmountOutToMaxSwapSize(address(assetIn), address(assetOut), amountOut);

        if (amountOut == 0) {
            zeroBalanceCount++;
            return;
        }

        uint256 maxAmountIn = type(uint256).max;

        // 2. Cache starting state
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);
        uint256 startingValue      = groveBasin.totalAssets();

        // 3. Preview before swap, execute, and assert preview/execute consistency.
        //    Scoped to avoid stack-too-deep.
        uint256 amountIn;
        {
            uint256 previewAmountIn = groveBasin.previewSwapExactOut(
                address(assetIn), address(assetOut), amountOut
            );

            vm.startPrank(swapper);
            assetIn.mint(swapper, previewAmountIn);
            assetIn.approve(address(groveBasin), previewAmountIn);
            amountIn = groveBasin.swapExactOut(
                address(assetIn), address(assetOut), amountOut, maxAmountIn, swapper, 0
            );
            vm.stopPrank();

            // Assert preview/execute consistency
            assertEq(previewAmountIn, amountIn, "FeeAwareSwapperHandler/swapExactOut/preview-execute-mismatch");
            previewConsistencyCheckCount++;
        }

        // 4. Update ghost variable(s)
        swapsIn[swapper][address(assetIn)]   += amountIn;
        swapsOut[swapper][address(assetOut)] += amountOut;

        uint256 valueIn  = _getAssetValue(address(assetIn),  amountIn);
        uint256 valueOut = _getAssetValue(address(assetOut), amountOut);

        valueSwappedIn[swapper]  += valueIn;
        valueSwappedOut[swapper] += valueOut;

        // 5. Perform action-specific assertions

        // Fee revenue increases the conversion rate and total value. The increase is bounded by
        // the fee percentage (up to 5%) of the swap value, plus rounding.
        uint256 feeToleranceValue = valueIn * 500 / 10_000;  // Max 5% fee
        uint256 feeTolerance      = feeToleranceValue + 3e12;

        assertApproxEqAbs(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            feeTolerance,
            "FeeAwareSwapperHandler/swapExactOut/conversion-rate-change"
        );

        // Rounding + fee revenue always increases share price
        assertGe(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            "FeeAwareSwapperHandler/swapExactOut/conversion-rate-decrease"
        );

        // Total value can increase by fee revenue
        assertGe(
            groveBasin.totalAssets(),
            startingValue,
            "FeeAwareSwapperHandler/swapExactOut/groveBasin-total-value-decrease"
        );

        // Value in always >= value out (fees + rounding favour protocol)
        assertGe(valueIn, valueOut, "FeeAwareSwapperHandler/swapExactOut/value-out-greater-than-in");

        // 6. Update metrics tracking state
        _updateSharePrice();
        swapperSwapCount[swapper]++;
        swapCount++;
    }

    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        if      (asset == address(assets[0])) return amount * swapTokenRateProvider.getConversionRate() / 1e15;
        else if (asset == address(assets[1])) return amount;
        else if (asset == address(assets[2])) return amount * creditTokenRateProvider.getConversionRate() / 1e27;
        else revert("FeeAwareSwapperHandler/asset-not-found");
    }

    function _capAmountOutToMaxSwapSize(
        address assetIn,
        address assetOut,
        uint256 amountOut
    )
        internal view returns (uint256)
    {
        uint256 maxSwapSize_ = groveBasin.maxSwapSize();

        if (maxSwapSize_ == 0) return 0;

        uint256 outValue = _getAssetValue(assetOut, amountOut);

        if (outValue > maxSwapSize_) {
            amountOut = amountOut * maxSwapSize_ / outValue;
            if (amountOut == 0) return 0;
        }

        try groveBasin.previewSwapExactOut(assetIn, assetOut, amountOut) {
            return amountOut;
        } catch {
            if (amountOut > 1) amountOut -= 1;
            else return 0;
        }

        try groveBasin.previewSwapExactOut(assetIn, assetOut, amountOut) {
            return amountOut;
        } catch {
            return 0;
        }
    }

    function _capAmountToMaxSwapSize(address asset, uint256 amount) internal view returns (uint256) {
        uint256 maxSwapSize_ = groveBasin.maxSwapSize();

        if (maxSwapSize_ == 0) return 0;

        uint256 value = _getAssetValue(asset, amount);

        if (value <= maxSwapSize_) return amount;

        return amount * maxSwapSize_ / value;
    }

}
