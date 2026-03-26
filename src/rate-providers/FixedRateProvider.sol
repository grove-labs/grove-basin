// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IRateProviderLike } from "../interfaces/IRateProviderLike.sol";

/**
 * @title  FixedRateProvider
 * @notice Rate provider that returns a fixed, immutable conversion rate set at deployment.
 *         Always reports the current block timestamp as the rate age, so it never goes stale.
 */
contract FixedRateProvider is IRateProviderLike {

    error ZeroRate();

    /// @notice Precision of the returned rate (1e27).
    uint256 public constant RATE_PRECISION = 1e27;

    /// @notice The fixed conversion rate in 1e27 precision.
    uint256 public immutable rate;

    /// @param rate_ The fixed conversion rate to use (must be non-zero).
    constructor(uint256 rate_) {
        if (rate_ == 0) revert ZeroRate();
        rate = rate_;
    }

    /// @inheritdoc IRateProviderLike
    function getConversionRate() external view override returns (uint256 rate_) {
        (rate_, ) = this.getConversionRateWithAge();
    }

    /// @inheritdoc IRateProviderLike
    function getConversionRateWithAge() external view override returns (uint256, uint256) {
        return (rate, block.timestamp);
    }

    /// @inheritdoc IRateProviderLike
    function getRatePrecision() external pure override returns (uint256) {
        return RATE_PRECISION;
    }

}
