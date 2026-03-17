// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

interface IGroveBasinPocket {

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
     *  @dev    Withdraws liquidity from the pocket, converting from yield-bearing positions if
     *          necessary to fulfill the requested amount. Callable by the basin or MANAGER_ROLE.
     *  @param  amount Amount of the asset to withdraw.
     *  @param  asset  Address of the asset to withdraw.
     *  @return The amount of the asset made available.
     */
    function withdrawLiquidity(uint256 amount, address asset) external returns (uint256);

    /**
     *  @dev    Deposits liquidity into the pocket, optionally deploying it to yield-bearing
     *          strategies. Callable by the basin or MANAGER_ROLE.
     *  @param  amount Amount of the asset to deposit.
     *  @param  asset  Address of the asset to deposit.
     *  @return The amount of the asset deposited (or converted equivalent).
     */
    function depositLiquidity(uint256 amount, address asset) external returns (uint256);

    /**
     *  @dev    Returns the total available balance of a given asset in the pocket, including
     *          amounts deployed to yield-bearing strategies that can be withdrawn.
     *  @param  asset Address of the asset to query.
     *  @return The total available balance of the asset.
     */
    function availableBalance(address asset) external view returns (uint256);

}
