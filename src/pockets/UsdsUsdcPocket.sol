// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { BasePocket }        from "src/pockets/BasePocket.sol";
import { IPSMLike }          from "src/interfaces/IPSMLike.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

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

    error InvalidUsdc();
    error InvalidUsds();
    error InvalidPsm();
    error SwapTokenMismatch();
    error CollateralTokenMismatch();

    IERC20 public immutable usdc;
    IERC20 public immutable usds;

    address public immutable psm;
    address public immutable groveProxy;

    uint256 internal immutable _usdsPrecision;
    uint256 internal immutable _usdcPrecision;

    /**
     * @param basin_ Address of the GroveBasin contract.
     * @param usdc_  USDC token address.
     * @param usds_  USDS token address.
     * @param psm_   Peg Stability Module address for USDC/USDS conversion.
     */
    constructor(
        address basin_,
        address usdc_,
        address usds_,
        address psm_,
        address groveProxy_
    ) BasePocket(basin_) {
        if (usdc_       == address(0)) revert InvalidUsdc();
        if (usds_       == address(0)) revert InvalidUsds();
        if (psm_        == address(0)) revert InvalidPsm();

        if (_basin.swapToken()       != usds_) revert SwapTokenMismatch();
        if (_basin.collateralToken() != usdc_) revert CollateralTokenMismatch();

        usdc       = IERC20(usdc_);
        usds       = IERC20(usds_);
        psm        = psm_;
        groveProxy = groveProxy_;

        _usdsPrecision = 10 ** IERC20(usds_).decimals();
        _usdcPrecision = 10 ** IERC20(usdc_).decimals();

        IERC20(usds_).safeApprove(basin_, type(uint256).max);
        IERC20(usdc_).safeApprove(basin_, type(uint256).max);

        if (groveProxy_ != address(0)) {
            // Allows Sky spells to withdraw USDS from this pocket
            IERC20(usds_).safeApprove(groveProxy_, type(uint256).max);
        }
    }

    /// @inheritdoc IGroveBasinPocket
    function depositLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        if (asset == address(usds)) {
            emit LiquidityDeposited(asset, amount, 0);
            return amount;
        } else if (asset == address(usdc)) {
            usdc.safeApprove(psm, amount);

            uint256 convertedAmount = IPSMLike(psm).sellGem(address(this), amount);

            usdc.safeApprove(psm, 0);

            emit LiquidityDeposited(asset, amount, convertedAmount);
            return convertedAmount;
        }

        return 0;
    }

    /// @inheritdoc IGroveBasinPocket
    function withdrawLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        if (asset == address(usdc)) {
            uint256 balance = usdc.balanceOf(address(this));

            uint256 convertedAmount;

            if (balance < amount) {
                uint256 remainder = amount - balance;

                usds.safeApprove(psm, type(uint256).max);

                IPSMLike(psm).buyGem(address(this), remainder);
                convertedAmount = remainder;

                usds.safeApprove(psm, 0);

                emit LiquidityDrawn(asset, amount, convertedAmount);
            } else {
                emit LiquidityDrawn(asset, amount, 0);
            }

            return amount;
        }

        return 0;
    }

    /// @inheritdoc IGroveBasinPocket
    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(usds)) {
            return usds.balanceOf(address(this));
        } else if (asset == address(usdc)) {
            return usdc.balanceOf(address(this))
                + usds.balanceOf(address(this)) * _usdcPrecision / _usdsPrecision;
        }
        return IERC20(asset).balanceOf(address(this));
    }

}
