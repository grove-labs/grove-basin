// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IGroveRateProvider }     from "../interfaces/IGroveRateProvider.sol";
import { IChronicleOracleLike } from "../interfaces/IChronicleOracleLike.sol";

/**
 * @title  ChronicleRateProvider
 * @notice Rate provider that fetches conversion rates from a Chronicle oracle, scaling the
 *         returned value from oracle precision to 1e27 (rate provider precision).
 */
contract ChronicleRateProvider is IGroveRateProvider {

    error ZeroOracle();

    /// @notice Precision of the returned rate (1e27).
    uint256 public constant RATE_PRECISION = 1e27;

    /// @notice Native precision of the Chronicle oracle, derived from `oracle.decimals()`.
    uint256 public immutable chroniclePrecision;

    /// @notice Address of the Chronicle oracle contract.
    address public immutable oracle;

    /// @param oracle_ Address of the Chronicle oracle (must be non-zero).
    constructor(address oracle_) {
        if (oracle_ == address(0)) revert ZeroOracle();
        oracle             = oracle_;
        chroniclePrecision = 10 ** IChronicleOracleLike(oracle_).decimals();
    }

    /// @inheritdoc IGroveRateProvider
    function getConversionRate() external view override returns (uint256 rate) {
        (rate, ) = this.getConversionRateWithAge();
    }

    /// @inheritdoc IGroveRateProvider
    function getConversionRateWithAge() external view override returns (uint256, uint256) {
        (uint256 val, uint256 age) = IChronicleOracleLike(oracle).readWithAge();
        return (val * RATE_PRECISION / chroniclePrecision, age);
    }

    /// @inheritdoc IGroveRateProvider
    function getRatePrecision() external pure override returns (uint256) {
        return RATE_PRECISION;
    }

}
