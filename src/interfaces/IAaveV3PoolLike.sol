// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IAaveV3PoolLike
 * @notice Minimal interface for the Aave V3 lending pool used by pocket contracts.
 */
interface IAaveV3PoolLike {

    /// @notice Supplies `amount` of `asset` to the pool on behalf of `onBehalfOf`.
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /// @notice Withdraws `amount` of `asset` from the pool, sending it to `to`.
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

}
