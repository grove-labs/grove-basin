// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IAsyncVaultLike } from "src/interfaces/IAsyncVaultLike.sol";
import { IGroveBasin }     from "src/interfaces/IGroveBasin.sol";
import { ITokenRedeemer }  from "src/interfaces/ITokenRedeemer.sol";

contract JTRSYTokenRedeemer is ITokenRedeemer {

    using SafeERC20 for IERC20;

    address public immutable override creditToken;
    address public immutable override vault;

    address public override basin;

    modifier onlyBasin() {
        require(msg.sender == basin, "JTRSYTokenRedeemer/only-basin");
        _;
    }

    constructor(address creditToken_, address vault_) {
        require(creditToken_ != address(0), "JTRSYTokenRedeemer/invalid-creditToken");
        require(vault_       != address(0), "JTRSYTokenRedeemer/invalid-vault");

        creditToken = creditToken_;
        vault       = vault_;
    }

    function setUp(address basin_) external override {
        require(basin == address(0),                                                              "JTRSYTokenRedeemer/already-set-up");
        require(msg.sender == basin_,                                                             "JTRSYTokenRedeemer/only-basin");
        require(address(IGroveBasin(basin_).creditToken()) == creditToken,                        "JTRSYTokenRedeemer/creditToken-mismatch");
        require(address(IGroveBasin(basin_).collateralToken()) == IAsyncVaultLike(vault).asset(), "JTRSYTokenRedeemer/collateral-asset-mismatch");
        require(IAsyncVaultLike(vault).isPermissioned(address(this)),                             "JTRSYTokenRedeemer/not-allowlisted");

        basin = basin_;
    }

    function tearDown(address) external override onlyBasin {}

    function initiateRedeem(uint256 creditTokenAmount) external override onlyBasin {
        IERC20(creditToken).safeTransferFrom(msg.sender, address(this), creditTokenAmount);
        IERC20(creditToken).approve(vault, creditTokenAmount);
        IAsyncVaultLike(vault).requestRedeem(creditTokenAmount, address(this), address(this));
    }

    function completeRedeem(uint256 creditTokenAmount) external override onlyBasin returns (uint256 assets) {
        assets = IAsyncVaultLike(vault).redeem(creditTokenAmount, address(this), address(this));
        IERC20(IAsyncVaultLike(vault).asset()).safeTransfer(msg.sender, assets);
    }

}
