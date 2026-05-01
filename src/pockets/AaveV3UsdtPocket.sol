// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { BasePocket }        from "src/pockets/BasePocket.sol";
import { IAaveV3PoolLike }   from "src/interfaces/IAaveV3PoolLike.sol";
import { IATokenLike }       from "src/interfaces/IATokenLike.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

/**
 * @title  AaveV3UsdtPocket
 * @notice Pocket that deploys USDT liquidity into Aave V3 and withdraws on demand.
 *
 * @dev    Trust model:
 *         - Basin: Immutable address set at construction. Can call depositLiquidity and
 *           withdrawLiquidity unconditionally.
 *         - MANAGER_ROLE: Determined by the Grove Basin's AccessControl. Any address that holds
 *           MANAGER_ROLE in the basin can call depositLiquidity and withdrawLiquidity.
 */
contract AaveV3UsdtPocket is BasePocket {

    using SafeERC20 for IERC20;

    error InvalidUsdt();
    error InvalidAUsdt();
    error InvalidAaveV3Pool();
    error UnderlyingAssetMismatch();
    error SwapTokenMismatch();
    error NoWithdrawMaxUint();

    IERC20 public immutable usdt;
    IERC20 public immutable aUsdt;

    address public immutable aaveV3Pool;

    /**
     * @param basin_      Address of the GroveBasin contract.
     * @param usdt_       USDT token address.
     * @param aUsdt_      Aave aUSDT token address.
     * @param aaveV3Pool_ Aave V3 pool address.
     */
    constructor(
        address basin_,
        address usdt_,
        address aUsdt_,
        address aaveV3Pool_
    ) BasePocket(basin_) {
        if (usdt_       == address(0)) revert InvalidUsdt();
        if (aUsdt_      == address(0)) revert InvalidAUsdt();
        if (aaveV3Pool_ == address(0)) revert InvalidAaveV3Pool();

        if (IATokenLike(aUsdt_).UNDERLYING_ASSET_ADDRESS() != usdt_) revert UnderlyingAssetMismatch();

        if (_basin.swapToken() != usdt_) revert SwapTokenMismatch();

        usdt       = IERC20(usdt_);
        aUsdt      = IERC20(aUsdt_);
        aaveV3Pool = aaveV3Pool_;

        IERC20(usdt_).safeApprove(basin_, type(uint256).max);
    }

    /// @inheritdoc IGroveBasinPocket
    function depositLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        // Return 0 since this pocket only supports USDT
        if (asset != address(usdt)) {
            return 0;
        }

        emit LiquidityDeposited(asset, amount, amount);

        usdt.safeApprove(aaveV3Pool, amount);
        IAaveV3PoolLike(aaveV3Pool).supply(address(usdt), amount, address(this), 0);

        return amount;
    }

    /// @inheritdoc IGroveBasinPocket
    function withdrawLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;
        
        // Return 0 since this pocket only supports USDT
        if (asset != address(usdt)) {
            return 0;
        }
        
        // Aave lets users withdraw their whole balance by passing in the max value
        // This check ensures the amount returned and emitted in logs is valid and
        // explicitly defined by the caller.
        if (amount == type(uint256).max) revert NoWithdrawMaxUint();

        uint256 balance = usdt.balanceOf(address(this));

        uint256 convertedAmount;

        if (balance < amount) {
            uint256 remainder = amount - balance;

            convertedAmount = IAaveV3PoolLike(aaveV3Pool).withdraw(
                address(usdt),
                remainder,
                address(this)
            );

            emit LiquidityDrawn(asset, amount, convertedAmount);
        } else {
            emit LiquidityDrawn(asset, amount, 0);
        }

        return amount;
    }

    /// @inheritdoc IGroveBasinPocket
    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(usdt)) {
            return usdt.balanceOf(address(this)) + aUsdt.balanceOf(address(this));
        }
        return IERC20(asset).balanceOf(address(this));
    }

}
