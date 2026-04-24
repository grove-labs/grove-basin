// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IAsyncVaultLike }              from "src/interfaces/IAsyncVaultLike.sol";
import { IGroveBasin }                 from "src/interfaces/IGroveBasin.sol";
import { ITokenRedeemer, RedeemRequest } from "src/interfaces/ITokenRedeemer.sol";

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

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error InvalidVault();
    error CollateralAssetMismatch();
    error ShareMismatch();
    error RedemptionAlreadyActive();

    /**********************************************************************************************/
    /*** State variables and immutables                                                         ***/
    /**********************************************************************************************/

    /// @inheritdoc ITokenRedeemer
    address public immutable override creditToken;

    /// @inheritdoc ITokenRedeemer
    address public immutable override vault;

    /// @inheritdoc ITokenRedeemer
    IGroveBasin public immutable override basin;

    /// @dev Whether a redemption is currently in flight. Only one allowed at a time.
    bool public redemptionActive;

    /// @dev Restricts access to the basin contract.
    modifier onlyBasin() {
        if (msg.sender != address(basin)) revert OnlyBasin();
        _;
    }

    /**
     * @param creditToken_ Address of the credit token.
     * @param vault_       Address of the ERC-7540 async vault.
     * @param basin_       Address of the GroveBasin contract.
     */
    constructor(address creditToken_, address vault_, address basin_) {
        if (creditToken_ == address(0)) revert InvalidCreditToken();
        if (vault_       == address(0)) revert InvalidVault();
        if (basin_       == address(0)) revert InvalidBasin();

        if (IGroveBasin(basin_).creditToken() != creditToken_)                        revert CreditTokenMismatch();
        if (IGroveBasin(basin_).collateralToken() != IAsyncVaultLike(vault_).asset()) revert CollateralAssetMismatch();
        if (IAsyncVaultLike(vault_).share() != creditToken_)                          revert ShareMismatch();

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
        if (redemptionActive) revert RedemptionAlreadyActive();

        redemptionActive = true;

        IERC20(creditToken).safeTransferFrom(address(basin), address(this), creditTokenAmount);
        IAsyncVaultLike(vault).requestRedeem(creditTokenAmount, address(this), address(this));

        emit RedeemInitiated(creditTokenAmount);
    }

    /// @inheritdoc ITokenRedeemer
    function completeRedeem(RedeemRequest calldata request) external override onlyBasin returns (uint256 collateralTokenReturned) {
        collateralTokenReturned = IAsyncVaultLike(vault).redeem(request.creditTokenAmount, address(this), address(this));

        redemptionActive = false;

        IERC20(IAsyncVaultLike(vault).asset()).safeTransfer(address(basin), collateralTokenReturned);

        emit RedeemCompleted(collateralTokenReturned);
    }

    /// @inheritdoc ITokenRedeemer
    function sweep(address token, uint256 amount) external override {
        if (!IAccessControl(address(basin)).hasRole(basin.MANAGER_ADMIN_ROLE(), msg.sender)) revert NotAuthorized();
        if (token != creditToken && token != basin.collateralToken())                        revert InvalidToken();

        if (amount == 0) revert ZeroBalance();

        IERC20(token).safeTransfer(address(basin), amount);
        
        emit Swept(token, amount);
    }

}
