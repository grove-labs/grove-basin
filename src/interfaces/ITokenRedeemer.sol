// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

interface ITokenRedeemer {

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error OnlyBasin();
    error InvalidCreditToken();
    error InvalidBasin();
    error CreditTokenMismatch();

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev   Emitted when a redemption is initiated.
     *  @param creditTokenAmount Amount of credit tokens sent to the vault for redemption.
     */
    event RedeemInitiated(uint256 creditTokenAmount);

    /**
     *  @dev   Emitted when a redemption is completed.
     *  @param creditTokenAmount Amount of credit tokens that were redeemed.
     *  @param assets            Amount of collateral assets received from the vault.
     */
    event RedeemCompleted(uint256 creditTokenAmount, uint256 assets);

    /**********************************************************************************************/
    /*** State variables and immutables                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the address of the credit token that this redeemer handles.
     *  @return The address of the credit token.
     */
    function creditToken() external view returns (address);

    /**
     *  @dev    Returns the address of the async vault used for redemption.
     *  @return The address of the vault.
     */
    function vault() external view returns (address);

    /**
     *  @dev    Returns the IGroveBasin interface of the basin contract that this redeemer is bound to.
     *  @return The IGroveBasin interface of the basin.
     */
    function basin() external view returns (IGroveBasin);

    /**
     *  @dev   Performs any redeemer-specific setup. Called by the basin when adding a redeemer.
     *  @param basin The address of the basin.
     */
    function setUp(address basin) external;

    /**
     *  @dev   Performs any redeemer-specific teardown. Called by the basin when removing a redeemer.
     *  @param basin The address of the basin.
     */
    function tearDown(address basin) external;

    /**
     *  @dev   Initiates a redemption by transferring credit tokens from the caller and calling
     *         requestRedeem on the vault.
     *  @param creditTokenAmount Amount of credit tokens to redeem.
     */
    function initiateRedeem(uint256 creditTokenAmount) external;

    /**
     *  @dev   Completes a redemption by calling redeem on the vault and transferring the
     *         redeemed collateral assets back to the caller.
     *  @param  creditTokenAmount Amount of credit tokens to complete redemption for.
     *  @return assets            Amount of collateral assets sent back to the caller.
     */
    function completeRedeem(uint256 creditTokenAmount) external returns (uint256 assets);

}
