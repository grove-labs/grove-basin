// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

struct RedeemRequest {
    uint256 blockNumber;
    address redeemer;
    uint256 creditTokenAmount;
    uint256 collateralTokenAmount;
}

interface ITokenRedeemer {

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error OnlyBasin();
    error NotAuthorized();
    error InvalidCreditToken();
    error InvalidBasin();
    error InvalidToken();
    error ZeroBalance();
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
     *  @param collateralTokenAmount Amount of collateral assets received from the vault.
     */
    event RedeemCompleted(uint256 collateralTokenAmount);

    /**
     *  @dev   Emitted when tokens are swept from the redeemer to the basin.
     *  @param token  Address of the token swept.
     *  @param amount Amount of tokens swept.
     */
    event Swept(address indexed token, uint256 amount);

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
     *  @dev    Completes a redemption by withdrawing collateral assets from the vault and
     *          transferring them back to the caller.
     *  @param  request The RedeemRequest struct containing the redemption details.
     *  @return collateralTokenReturned Amount of collateral assets sent back to the caller.
     */
    function completeRedeem(RedeemRequest calldata request) external returns (uint256 collateralTokenReturned);

    /**
     *  @dev   Transfers tokens to the basin. The token must be the credit token or the collateral
     *         token. Callable only by MANAGER_ADMIN_ROLE holders. Reverts if amount is zero.
     *         Should only be called when there are no pending redemptions.
     *  @param token  Address of the token to sweep (must be creditToken or collateralToken).
     *  @param amount Amount of tokens to sweep.
     */
    function sweep(address token, uint256 amount) external;

}
