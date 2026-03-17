// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IRateProviderLike }      from "../interfaces/IRateProviderLike.sol";
import { IChronicleOracleLike } from "../interfaces/IChronicleOracleLike.sol";

contract ChronicleRateProvider is IRateProviderLike {

    uint256 public constant RATE_PRECISION = 1e27;
    uint256 public constant CHRONICLE_PRECISION = 1e18;

    address public immutable oracle;

    constructor(address oracle_) {
        require(oracle_ != address(0), "ChronicleRateProvider/zero-oracle");
        oracle = oracle_;
    }

    function getConversionRate() external view override returns (uint256 rate) {
        (rate, ) = this.getConversionRateWithAge();
    }

    function getConversionRateWithAge() external view override returns (uint256, uint256) {
        (uint256 val, uint256 age) = IChronicleOracleLike(oracle).readWithAge();
        return (val * RATE_PRECISION / CHRONICLE_PRECISION, age);
    }

    function getRatePrecision() external pure override returns (uint256) {
        return RATE_PRECISION;
    }

}
