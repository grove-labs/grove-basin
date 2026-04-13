// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IGroveBasin }                 from "src/interfaces/IGroveBasin.sol";
import { ITokenRedeemer, RedeemRequest } from "src/interfaces/ITokenRedeemer.sol";

/**
 * @title  BUIDLTokenRedeemer
 * @notice Token redeemer that handles BUIDL credit token redemptions through an offchain
 *         settlement process. Only one redemption may be active at a time. Transfers credit
 *         tokens to the redemption address on initiation and returns the redeemer's entire
 *         collateral token balance to the basin on completion.
 * @dev    Only callable by the Basin contract. To reset a stuck redemption, send any non-zero
 *         amount of collateral token to this contract and call completeRedeem.
 */
contract BUIDLTokenRedeemer is ITokenRedeemer {

    using SafeERC20 for IERC20;

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error InvalidRedemptionAddress();
    error RedemptionAlreadyActive();
    error NoCollateralBalance();

    /**********************************************************************************************/
    /*** State variables and immutables                                                         ***/
    /**********************************************************************************************/

    /// @inheritdoc ITokenRedeemer
    address public immutable override creditToken;

    address public immutable collateralToken;

    address public immutable redemptionAddress;

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
     * @param creditToken_       Address of the credit token (BUIDL).
     * @param redemptionAddress_ Address that receives credit tokens for offchain settlement.
     * @param basin_             Address of the GroveBasin contract.
     */
    constructor(address creditToken_, address redemptionAddress_, address basin_) {
        if (creditToken_       == address(0)) revert InvalidCreditToken();
        if (redemptionAddress_ == address(0)) revert InvalidRedemptionAddress();
        if (basin_             == address(0)) revert InvalidBasin();

        if (IGroveBasin(basin_).creditToken() != creditToken_) revert CreditTokenMismatch();

        creditToken       = creditToken_;
        collateralToken   = IGroveBasin(basin_).collateralToken();
        redemptionAddress = redemptionAddress_;
        basin             = IGroveBasin(basin_);
    }

    /// @inheritdoc ITokenRedeemer
    function vault() external view override returns (address) {
        return redemptionAddress;
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
        IERC20(creditToken).safeTransfer(redemptionAddress, creditTokenAmount);
        emit RedeemInitiated(creditTokenAmount);
    }

    /// @inheritdoc ITokenRedeemer
    function completeRedeem(RedeemRequest calldata) external override onlyBasin returns (uint256 collateralTokenReturned) {
        collateralTokenReturned = IERC20(collateralToken).balanceOf(address(this));

        if (collateralTokenReturned == 0) revert NoCollateralBalance();

        redemptionActive = false;

        IERC20(collateralToken).safeTransfer(address(basin), collateralTokenReturned);
        emit RedeemCompleted(collateralTokenReturned);
    }

}
