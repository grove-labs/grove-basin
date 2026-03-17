// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

interface IERC4626VaultLike {

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function balanceOf(address owner) external view returns (uint256);

}
