// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IAsyncVaultLike
 * @notice Minimal interface for ERC-7540 async vaults used in credit token redemptions.
 */
interface IAsyncVaultLike {

    /// @notice Requests an asynchronous redemption of `shares` for the given controller/owner.
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);

    /// @notice Completes a redemption, returning the underlying assets for the given shares.
    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    /// @notice Completes a withdrawal, burning shares and returning the underlying assets.
    function withdraw(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    /// @notice Returns the maximum amount of assets that can be withdrawn by the controller.
    function maxWithdraw(address controller) external view returns (uint256 maxAssets);

    /// @notice Returns the address of the underlying asset of the vault.
    function asset() external view returns (address);

    /// @notice Returns the address of the vault's share token.
    function share() external view returns (address);

    /// @notice Returns whether the given controller address is permissioned (allowlisted).
    function isPermissioned(address controller) external view returns (bool);

}
