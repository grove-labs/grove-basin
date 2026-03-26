// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IRateProviderLike }     from "../interfaces/IRateProviderLike.sol";
import { IChronicleOracleLike } from "../interfaces/IChronicleOracleLike.sol";

/**
 * @title  ChronicleRateProvider
 * @notice Rate provider that fetches conversion rates from a Chronicle oracle, scaling the
 *         returned value from 1e18 (Chronicle precision) to 1e27 (rate provider precision).
 */
contract ChronicleRateProvider is IRateProviderLike {

    error ZeroOracle();

    /// @notice Precision of the returned rate (1e27).
    uint256 public constant RATE_PRECISION = 1e27;

    /// @notice Native precision of the Chronicle oracle (1e18).
    uint256 public constant CHRONICLE_PRECISION = 1e18;

    /// @notice Address of the Chronicle oracle contract.
    address public immutable oracle;

    /// @param oracle_ Address of the Chronicle oracle (must be non-zero).
    constructor(address oracle_) {
        if (oracle_ == address(0)) revert ZeroOracle();
        oracle = oracle_;
    }

    /// @inheritdoc IRateProviderLike
    function getConversionRate() external view override returns (uint256 rate) {
        (rate, ) = this.getConversionRateWithAge();
    }

    /// @inheritdoc IRateProviderLike
    function getConversionRateWithAge() external view override returns (uint256, uint256) {
        (uint256 val, uint256 age) = IChronicleOracleLike(oracle).readWithAge();
        return (val * RATE_PRECISION / CHRONICLE_PRECISION, age);
    }

    /// @inheritdoc IRateProviderLike
    function getRatePrecision() external pure override returns (uint256) {
        return RATE_PRECISION;
    }

}
