// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IRateProviderLike } from "../interfaces/IRateProviderLike.sol";

contract FixedRateProvider is IRateProviderLike {

    uint256 public constant RATE_PRECISION = 1e27;

    uint256 public immutable rate;

    constructor(uint256 rate_) {
        require(rate_ != 0, "FixedRateProvider/zero-rate");
        rate = rate_;
    }

    function getConversionRate() external view override returns (uint256 rate_) {
        (rate_, ) = this.getConversionRateWithAge();
    }

    function getConversionRateWithAge() external view override returns (uint256, uint256) {
        return (rate, block.timestamp);
    }

    function getRatePrecision() external pure override returns (uint256) {
        return RATE_PRECISION;
    }

}
