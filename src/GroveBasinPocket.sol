// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";
import { IPSM3Like }        from "src/interfaces/IPSM3Like.sol";
import { IAaveV3PoolLike }   from "src/interfaces/IAaveV3PoolLike.sol";

contract GroveBasinPocket is IGroveBasinPocket {

    using SafeERC20 for IERC20;

    address public override immutable basin;
    address public override immutable manager;

    IERC20 public immutable usdc;
    IERC20 public immutable usdt;
    IERC20 public immutable usds;
    IERC20 public immutable aUsdt;

    address public immutable psm3;
    address public immutable aaveV3Pool;

    uint256 internal immutable _usdsPrecision;
    uint256 internal immutable _usdcPrecision;
    uint256 internal immutable _usdtPrecision;
    uint256 internal immutable _aUsdtPrecision;

    modifier onlyBasin() {
        require(msg.sender == basin, "GroveBasinPocket/not-basin");
        _;
    }

    constructor(
        address basin_,
        address manager_,
        address usdc_,
        address usdt_,
        address usds_,
        address aUsdt_,
        address psm3_,
        address aaveV3Pool_
    ) {
        require(basin_      != address(0), "GroveBasinPocket/invalid-basin");
        require(manager_    != address(0), "GroveBasinPocket/invalid-manager");
        require(usdc_       != address(0), "GroveBasinPocket/invalid-usdc");
        require(usdt_       != address(0), "GroveBasinPocket/invalid-usdt");
        require(usds_       != address(0), "GroveBasinPocket/invalid-usds");
        require(aUsdt_      != address(0), "GroveBasinPocket/invalid-aUsdt");
        require(psm3_       != address(0), "GroveBasinPocket/invalid-psm3");
        require(aaveV3Pool_ != address(0), "GroveBasinPocket/invalid-aaveV3Pool");

        basin      = basin_;
        manager    = manager_;
        usdc       = IERC20(usdc_);
        usdt       = IERC20(usdt_);
        usds       = IERC20(usds_);
        aUsdt      = IERC20(aUsdt_);
        psm3       = psm3_;
        aaveV3Pool = aaveV3Pool_;

        _usdsPrecision  = 10 ** IERC20(usds_).decimals();
        _usdcPrecision  = 10 ** IERC20(usdc_).decimals();
        _usdtPrecision  = 10 ** IERC20(usdt_).decimals();
        _aUsdtPrecision = 10 ** IERC20(aUsdt_).decimals();

        IERC20(usds_).safeApprove(psm3_, type(uint256).max);
        IERC20(usds_).safeApprove(basin_, type(uint256).max);
        IERC20(usdc_).safeApprove(psm3_, type(uint256).max);
        IERC20(usdc_).safeApprove(basin_, type(uint256).max);
        IERC20(usdt_).safeApprove(aaveV3Pool_, type(uint256).max);
        IERC20(usdt_).safeApprove(basin_, type(uint256).max);
        IERC20(aUsdt_).safeApprove(aaveV3Pool_, type(uint256).max);
    }

    function depositLiquidity(uint256 amount, address asset) external override onlyBasin {
        if (amount == 0) return;

        if (asset == address(usds)) {
            emit LiquidityDeposited(asset, amount, 0);
        } else if (asset == address(usdc)) {
            uint256 convertedAmount = IPSM3Like(psm3).swapExactIn(
                address(usdc),
                address(usds),
                amount,
                0,
                address(this),
                0
            );

            emit LiquidityDeposited(asset, amount, convertedAmount);
        } else if (asset == address(usdt)) {
            IAaveV3PoolLike(aaveV3Pool).supply(address(usdt), amount, address(this), 0);

            emit LiquidityDeposited(asset, amount, amount);
        }
    }

    function drawLiquidity(uint256 amount, address asset) external override onlyBasin {
        if (amount == 0) return;

        if (asset == address(usdc)) {
            uint256 balance = usdc.balanceOf(address(this));

            uint256 convertedAmount;

            if (balance < amount) {
                uint256 remainder = amount - balance;

                convertedAmount = IPSM3Like(psm3).swapExactOut(
                    address(usds),
                    address(usdc),
                    remainder,
                    type(uint256).max,
                    address(this),
                    0
                );
            }

            emit LiquidityDrawn(asset, amount, convertedAmount);
        } else if (asset == address(usdt)) {
            uint256 balance = usdt.balanceOf(address(this));

            uint256 convertedAmount;

            if (balance < amount) {
                uint256 remainder = amount - balance;

                convertedAmount = IAaveV3PoolLike(aaveV3Pool).withdraw(
                    address(usdt),
                    remainder,
                    address(this)
                );
            }

            emit LiquidityDrawn(asset, amount, convertedAmount);
        }
    }

    function totalAssets() external view override returns (uint256) {
        return usds.balanceOf(address(this))  * 1e18 / _usdsPrecision
            + usdc.balanceOf(address(this))   * 1e18 / _usdcPrecision
            + usdt.balanceOf(address(this))   * 1e18 / _usdtPrecision
            + aUsdt.balanceOf(address(this))  * 1e18 / _aUsdtPrecision;
    }

    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(usds)) {
            return usds.balanceOf(address(this));
        } else if (asset == address(usdc)) {
            return usdc.balanceOf(address(this))
                + usds.balanceOf(address(this)) * _usdcPrecision / _usdsPrecision;
        } else if (asset == address(usdt)) {
            return usdt.balanceOf(address(this)) + aUsdt.balanceOf(address(this));
        }
        return 0;
    }

}
