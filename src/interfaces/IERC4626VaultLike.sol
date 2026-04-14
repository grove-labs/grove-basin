// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IERC4626VaultLike
 * @notice Minimal interface for ERC-4626 tokenized vaults used by pocket contracts.
 */
interface IERC4626VaultLike {

    /// @notice Deposits `assets` into the vault, minting shares to `receiver`.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Withdraws `assets` from the vault, burning shares from `owner`.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @notice Redeems `shares` from the vault, returning the underlying assets to `receiver`.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /// @notice Returns the amount of underlying assets equivalent to `shares`.
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @notice Returns the share balance of `owner`.
    function balanceOf(address owner) external view returns (uint256);

}
