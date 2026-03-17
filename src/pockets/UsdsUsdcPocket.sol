// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { BasePocket } from "src/pockets/BasePocket.sol";
import { IPSMLike }   from "src/interfaces/IPSMLike.sol";

/**
 * @title  UsdsUsdcPocket
 * @notice Pocket that converts USDC to USDS via PSM on deposit and reverses on withdraw.
 *
 * @dev    Trust model:
 *         - Basin: Immutable address set at construction. Can call depositLiquidity and
 *           withdrawLiquidity unconditionally.
 *         - MANAGER_ROLE: Determined by the Grove Basin's AccessControl. Any address that holds
 *           MANAGER_ROLE in the basin can call depositLiquidity and withdrawLiquidity.
 */
contract UsdsUsdcPocket is BasePocket {

    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable usds;

    address public immutable psm;

    uint256 internal immutable _usdsPrecision;
    uint256 internal immutable _usdcPrecision;

    constructor(
        address basin_,
        address usdc_,
        address usds_,
        address psm_
    ) BasePocket(basin_) {
        require(usdc_ != address(0), "UsdsUsdcPocket/invalid-usdc");
        require(usds_ != address(0), "UsdsUsdcPocket/invalid-usds");
        require(psm_  != address(0), "UsdsUsdcPocket/invalid-psm");

        usdc = IERC20(usdc_);
        usds = IERC20(usds_);
        psm  = psm_;

        _usdsPrecision = 10 ** IERC20(usds_).decimals();
        _usdcPrecision = 10 ** IERC20(usdc_).decimals();

        IERC20(usds_).safeApprove(basin_, type(uint256).max);
        IERC20(usdc_).safeApprove(basin_, type(uint256).max);
    }

    function depositLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        if (asset == address(usds)) {
            emit LiquidityDeposited(asset, amount, 0);
            return amount;
        } else if (asset == address(usdc)) {
            usdc.safeApprove(psm, amount);

            uint256 convertedAmount = IPSMLike(psm).swapExactIn(
                address(usdc),
                address(usds),
                amount,
                0,
                address(this),
                0
            );

            usds.safeApprove(psm, 0);

            emit LiquidityDeposited(asset, amount, convertedAmount);
            return convertedAmount;
        }

        return 0;
    }

    function withdrawLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        if (asset == address(usdc)) {
            uint256 balance = usdc.balanceOf(address(this));

            uint256 convertedAmount;

            if (balance < amount) {
                uint256 remainder = amount - balance;

                usds.safeApprove(psm, type(uint256).max);

                convertedAmount = IPSMLike(psm).swapExactOut(
                    address(usds),
                    address(usdc),
                    remainder,
                    type(uint256).max,
                    address(this),
                    0
                );

                usds.safeApprove(psm, 0);

                emit LiquidityDrawn(asset, amount, convertedAmount);
            } else {
                emit LiquidityDrawn(asset, amount, 0);
            }

            return amount;
        }

        return 0;
    }

    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(usds)) {
            return usds.balanceOf(address(this));
        } else if (asset == address(usdc)) {
            return usdc.balanceOf(address(this))
                + usds.balanceOf(address(this)) * _usdcPrecision / _usdsPrecision;
        }
        return 0;
    }

}
