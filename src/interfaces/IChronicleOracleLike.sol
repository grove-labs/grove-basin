// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IChronicleOracleLike
 * @notice Minimal interface for Chronicle oracle contracts that provide price feeds.
 */
interface IChronicleOracleLike {

    /// @notice Returns the current oracle value.
    function read() external view returns (uint256 val);

    /// @notice Returns the current oracle value, or (false, 0) if unavailable.
    function tryRead() external view returns (bool ok, uint256 val);

    /// @notice Returns the current oracle value and its age (timestamp of last update).
    function readWithAge() external view returns (uint256 val, uint256 age);

    /// @notice Returns the current oracle value and age, or (false, 0, 0) if unavailable.
    function tryReadWithAge() external view returns (bool ok, uint256 val, uint256 age);

    /// @notice Returns the number of decimals of the oracle's value.
    function decimals() external view returns (uint8);

}
