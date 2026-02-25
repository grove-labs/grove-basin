// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256 rate);
    function getConversionRateWithAge() external view returns (uint256 rate, uint256 lastUpdated);
    function getRatePrecision() external view returns (uint256);
}
