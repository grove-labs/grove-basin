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

    function _allowAssets(GroveBasin basin, address managerAdmin, address user, address[] memory assets)
        internal
    {
        bool[] memory allowed = new bool[](assets.length);

        for (uint256 i; i < assets.length; ++i) {
            allowed[i] = true;
        }

        vm.prank(managerAdmin);
        basin.setLpAssetAllowed(user, assets, allowed);
    }

}
