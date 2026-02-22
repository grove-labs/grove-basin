// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

contract MockRateProvider {

    uint256 public constant RATE_PRECISION = 1e27;

    uint256 public conversionRate;
    uint256 public lastUpdated;

    function __setConversionRate(uint256 conversionRate_) external {
        conversionRate = conversionRate_;
        lastUpdated = block.timestamp;
    }

    function __setLastUpdated(uint256 lastUpdated_) external {
        lastUpdated = lastUpdated_;
    }

    function getConversionRate() external view returns (uint256) {
        return conversionRate;
    }

    function getConversionRateWithAge() external view returns (uint256, uint256) {
        return (conversionRate, lastUpdated);
    }

    function getRatePrecision() external pure returns (uint256) {
        return RATE_PRECISION;
    }

}
