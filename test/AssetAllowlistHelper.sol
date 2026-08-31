// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

/// @dev Deposits require both the depositor and the receiver to be allowed the asset, and
///      withdrawals require the caller to be allowed it, so test setups have to allow the addresses
///      they use as receivers.
abstract contract AssetAllowlistHelper is Test {

    function _allowAsset(GroveBasin basin, address managerAdmin, address user, address asset)
        internal
    {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        _allowAssets(basin, managerAdmin, user, assets);
    }

    /// @dev The Basin constructor only grants LIQUIDITY_PROVIDER_ROLE, so the asset allowances of
    ///      the provider it is given have to be set explicitly by the deployer.
    function _allowAllAssets(GroveBasin basin, address managerAdmin, address user) internal {
        address[] memory assets = new address[](3);
        assets[0] = basin.swapToken();
        assets[1] = basin.collateralToken();
        assets[2] = basin.creditToken();

        _allowAssets(basin, managerAdmin, user, assets);
    }

    /// @dev setLiquidityProvider states the whole permission set of an address in one call, so the
    ///      allowances and the role the user already has are read back and preserved to keep the
    ///      helper additive.
    function _allowAssets(GroveBasin basin, address managerAdmin, address user, address[] memory assets)
        internal
    {
        address[] memory tokens = new address[](3);
        tokens[0] = basin.swapToken();
        tokens[1] = basin.collateralToken();
        tokens[2] = basin.creditToken();

        bool[] memory allowed = new bool[](3);

        for (uint256 i; i < tokens.length; ++i) {
            allowed[i] = basin.lpAssetAllowed(user, tokens[i]);

            for (uint256 j; j < assets.length; ++j) {
                if (assets[j] == tokens[i]) allowed[i] = true;
            }
        }

        bool isDepositor = basin.hasRole(basin.LIQUIDITY_PROVIDER_ROLE(), user);

        vm.prank(managerAdmin);
        basin.setLiquidityProvider(user, isDepositor, tokens, allowed);
    }

}
