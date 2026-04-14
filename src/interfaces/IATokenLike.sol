// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IATokenLike
 * @notice Minimal interface for Aave V3 aToken contracts.
 */
interface IATokenLike {

    /// @notice Returns the address of the underlying asset of this aToken.
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

}
