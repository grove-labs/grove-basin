// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

interface IChronicleOracleLike {
    function read() external view returns (uint256 val);
    function tryRead() external view returns (bool ok, uint256 val);
    function readWithAge() external view returns (uint256 val, uint256 age);
    function tryReadWithAge() external view returns (bool ok, uint256 val, uint256 age);
}
