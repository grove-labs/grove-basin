// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IGroveBasin }                 from "src/interfaces/IGroveBasin.sol";
import { ITokenRedeemer, RedeemRequest } from "src/interfaces/ITokenRedeemer.sol";

contract BUIDLTokenRedeemer is ITokenRedeemer {

    using SafeERC20 for IERC20;

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error InvalidRedemptionAddress();

    /**********************************************************************************************/
    /*** State variables and immutables                                                         ***/
    /**********************************************************************************************/

    /// @inheritdoc ITokenRedeemer
    address public immutable override creditToken;

    address public immutable collateralToken;

    address public immutable redemptionAddress;

    /// @inheritdoc ITokenRedeemer
    IGroveBasin public immutable override basin;

    modifier onlyBasin() {
        if (msg.sender != address(basin)) revert OnlyBasin();
        _;
    }

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
        IERC20(creditToken).safeTransferFrom(address(basin), address(this), creditTokenAmount);
        IERC20(creditToken).safeTransfer(redemptionAddress, creditTokenAmount);
        emit RedeemInitiated(creditTokenAmount);
    }

    /// @inheritdoc ITokenRedeemer
    function completeRedeem(RedeemRequest calldata request) external override onlyBasin returns (uint256 collateralTokenReturned) {
        collateralTokenReturned = Math.min(request.collateralTokenAmount, IERC20(collateralToken).balanceOf(address(this)));
        IERC20(collateralToken).safeTransfer(address(basin), collateralTokenReturned);
        emit RedeemCompleted(collateralTokenReturned);
    }

}
