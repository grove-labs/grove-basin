// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @dev Basins deployed before the liquidity provider became a role expose it as an immutable
 *      getter, which the current `GroveBasin` ABI no longer declares. Tests that run against
 *      those live deployments, or against basins produced by the already-deployed factory, read
 *      the liquidity provider through this interface.
 */
interface ILegacyLiquidityProvider {

    function liquidityProvider() external view returns (address);

}
