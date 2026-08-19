// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IGroveBasinPocket
 * @notice Interface for pocket contracts that hold custody of the GroveBasin's swap token and can
 *         deploy it to an external venue. Venues are not necessarily yield-bearing: they can be
 *         yield strategies (e.g. an ERC-4626 vault or Aave) or plain converters (e.g. a PSM).
 */
interface IGroveBasinPocket {

    error NotAuthorized();
    error InvalidBasin();
    error InvalidAsset();

    /**
     *  @dev   Emitted when liquidity is withdrawn from the pocket.
     *  @param asset           Address of the asset withdrawn.
     *  @param amount          Amount of the asset requested.
     *  @param convertedAmount Amount converted from another asset to fulfill the withdrawal.
     */
    event LiquidityDrawn(address indexed asset, uint256 amount, uint256 convertedAmount);

    /**
     *  @dev   Emitted when liquidity is deposited into the pocket.
     *  @param asset           Address of the asset deposited.
     *  @param amount          Amount of the asset deposited.
     *  @param convertedAmount Amount converted to another asset during the deposit.
     */
    event LiquidityDeposited(address indexed asset, uint256 amount, uint256 convertedAmount);

    /**
     *  @dev    Returns the address of the basin contract that this pocket is bound to.
     *  @return The address of the basin.
     */
    function basin() external view returns (address);

    /**
     *  @dev    Withdraws liquidity from the pocket, unwinding an external position if necessary to
     *          fulfill the requested amount. Callable by the basin or MANAGER_ROLE.
     *  @param  amount Amount of the asset to withdraw.
     *  @param  asset  Address of the asset to withdraw.
     *  @return The result of the withdrawal request. All pockets in this repository return the
     *          requested `amount` for a supported asset, not the delta actually made available.
     */
    function withdrawLiquidity(uint256 amount, address asset) external returns (uint256);

    /**
     *  @dev    Deposits liquidity into the pocket, optionally deploying it to an external venue.
     *          Callable by the basin or MANAGER_ROLE.
     *  @param  amount Amount of the asset to deposit.
     *  @param  asset  Address of the asset to deposit.
     *  @return The amount of the asset deposited (or converted equivalent). The GroveBasin does not
     *          consume this value.
     */
    function depositLiquidity(uint256 amount, address asset) external returns (uint256);

    /**
     *  @dev    Returns the expected balance of a given asset in the pocket, including amounts
     *          deployed to external venues. Externally deployed amounts are not guaranteed to be
     *          withdrawable at any given time, for example when the venue is temporarily short of
     *          liquidity.
     *  @param  asset Address of the asset to query.
     *  @return The expected balance of the asset.
     */
    function availableBalance(address asset) external view returns (uint256);

}
