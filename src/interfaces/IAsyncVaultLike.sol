// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

interface IAsyncVaultLike {

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    function asset() external view returns (address);

    function share() external view returns (address);

    function isPermissioned(address controller) external view returns (bool);

}
