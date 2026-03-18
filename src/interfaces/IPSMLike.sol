// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IPSMLike
 * @notice Minimal interface for a Peg Stability Module (PSM) that supports exact-in and
 *         exact-out swaps between stablecoins.
 */
interface IPSMLike {

    /// @notice Swaps an exact amount of `assetIn` for `assetOut`, receiving at least `minAmountOut`.
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    /// @notice Swaps `assetIn` for an exact amount of `assetOut`, spending at most `maxAmountIn`.
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

}
