// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IAsyncVaultLike } from "src/interfaces/IAsyncVaultLike.sol";
import { IGroveBasin }     from "src/interfaces/IGroveBasin.sol";
import { ITokenRedeemer }  from "src/interfaces/ITokenRedeemer.sol";

/**
 * @title  JTRSYTokenRedeemer
 * @notice Token redeemer that handles asynchronous credit token redemptions through an ERC-7540
 *         async vault. Transfers credit tokens to the vault on initiation and returns the
 *         redeemed collateral assets to the basin on completion.
 * @dev    Only callable by the Basin contract. The vault must allowlist this contract. This contract
 *         must be on the credit token allowlist.
 */
contract JTRSYTokenRedeemer is ITokenRedeemer {

    using SafeERC20 for IERC20;

    /// @inheritdoc ITokenRedeemer
    address public immutable override creditToken;

    /// @inheritdoc ITokenRedeemer
    address public immutable override vault;

    /// @inheritdoc ITokenRedeemer
    IGroveBasin public immutable override basin;

    /// @dev Restricts access to the basin contract.
    modifier onlyBasin() {
        require(msg.sender == address(basin), "JTRSYTokenRedeemer/only-basin");
        _;
    }

    /**
     * @param creditToken_ Address of the credit token.
     * @param vault_       Address of the ERC-7540 async vault.
     * @param basin_       Address of the GroveBasin contract.
     */
    constructor(address creditToken_, address vault_, address basin_) {
        require(creditToken_ != address(0), "JTRSYTokenRedeemer/invalid-creditToken");
        require(vault_       != address(0), "JTRSYTokenRedeemer/invalid-vault");
        require(basin_       != address(0), "JTRSYTokenRedeemer/invalid-basin");

        require(
            address(IGroveBasin(basin_).creditToken()) == creditToken_,
            "JTRSYTokenRedeemer/creditToken-mismatch"
        );
        require(
            address(IGroveBasin(basin_).collateralToken()) == IAsyncVaultLike(vault_).asset(),
            "JTRSYTokenRedeemer/collateral-asset-mismatch"
        );
        require(
            IAsyncVaultLike(vault_).isPermissioned(address(this)),
            "JTRSYTokenRedeemer/not-allowlisted"
        );

        creditToken = creditToken_;
        vault       = vault_;
        basin       = IGroveBasin(basin_);
    }

    /// @inheritdoc ITokenRedeemer
    function setUp(address) external override onlyBasin {}

    /// @inheritdoc ITokenRedeemer
    function tearDown(address) external override onlyBasin {}

    /// @inheritdoc ITokenRedeemer
    function initiateRedeem(uint256 creditTokenAmount) external override onlyBasin {
        IERC20(creditToken).safeTransferFrom(msg.sender, address(this), creditTokenAmount);
        IERC20(creditToken).approve(vault, creditTokenAmount);
        IAsyncVaultLike(vault).requestRedeem(creditTokenAmount, address(this), address(this));
    }

    /// @inheritdoc ITokenRedeemer
    function completeRedeem(uint256 creditTokenAmount) external override onlyBasin returns (uint256 assets) {
        assets = IAsyncVaultLike(vault).redeem(creditTokenAmount, address(this), address(this));
        IERC20(IAsyncVaultLike(vault).asset()).safeTransfer(msg.sender, assets);
    }

}
