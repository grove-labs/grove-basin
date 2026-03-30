// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

contract MockAsyncVault {

    address public asset;
    address public share;

    uint256 public lastRequestRedeemShares;
    address public lastRequestRedeemController;
    address public lastRequestRedeemOwner;

    mapping(address => bool) public permissioned;

    uint256 public lastRedeemShares;
    address public lastRedeemReceiver;
    address public lastRedeemController;

    uint256 public lastWithdrawAssets;
    address public lastWithdrawReceiver;
    address public lastWithdrawController;

    uint256 public mockMaxWithdraw;

    constructor(address asset_, address share_) {
        asset = asset_;
        share = share_;
    }

    function __setMaxWithdraw(uint256 amount) external {
        mockMaxWithdraw = amount;
    }

    function __setPermissioned(address account, bool status) external {
        permissioned[account] = status;
    }

    function isPermissioned(address controller) external view returns (bool) {
        return permissioned[controller];
    }

    function requestRedeem(uint256 shares, address controller, address owner_)
        external returns (uint256 requestId)
    {
        lastRequestRedeemShares     = shares;
        lastRequestRedeemController = controller;
        lastRequestRedeemOwner      = owner_;

        return 0;
    }

    function redeem(uint256 shares, address receiver, address controller)
        external returns (uint256 assets)
    {
        lastRedeemShares     = shares;
        lastRedeemReceiver   = receiver;
        lastRedeemController = controller;

        assets = shares;
        if (asset != address(0)) {
            IERC20(asset).transfer(receiver, assets);
        }
    }

    function withdraw(uint256 assets, address receiver, address controller)
        external returns (uint256 shares)
    {
        lastWithdrawAssets     = assets;
        lastWithdrawReceiver   = receiver;
        lastWithdrawController = controller;

        shares = assets;
        if (asset != address(0)) {
            IERC20(asset).transfer(receiver, assets);
        }
    }

    function maxWithdraw(address) external view returns (uint256) {
        return mockMaxWithdraw;
    }

}
