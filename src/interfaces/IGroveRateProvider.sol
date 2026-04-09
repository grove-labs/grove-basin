// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IGroveRateProvider
 * @notice Minimal interface for rate provider contracts that supply token-to-USD conversion
 *         rates in 1e27 precision.
 */
interface IGroveRateProvider {

    /**
     * @notice Returns the current conversion rate in 1e27 precision.
     * @return rate The conversion rate.
     */
    function getConversionRate() external view returns (uint256 rate);

    /**
     * @notice Returns the conversion rate and the timestamp it was last updated.
     * @return rate        The conversion rate in 1e27 precision.
     * @return lastUpdated Timestamp of the last rate update.
     */
    function getConversionRateWithAge() external view returns (uint256 rate, uint256 lastUpdated);

    /**
     * @notice Returns the precision of the rate (1e27).
     * @return The rate precision.
     */
    function getRatePrecision() external view returns (uint256);

}
