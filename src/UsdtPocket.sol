// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";
import { IAaveV3PoolLike }   from "src/interfaces/IAaveV3PoolLike.sol";

contract UsdtPocket is IGroveBasinPocket {

    using SafeERC20 for IERC20;

    address public override immutable basin;
    address public immutable manager;

    IERC20 public immutable usdt;
    IERC20 public immutable aUsdt;

    address public immutable aaveV3Pool;

    modifier onlyBasin() {
        require(msg.sender == basin, "UsdtPocket/not-basin");
        _;
    }

    constructor(
        address basin_,
        address manager_,
        address usdt_,
        address aUsdt_,
        address aaveV3Pool_
    ) {
        require(basin_      != address(0), "UsdtPocket/invalid-basin");
        require(manager_    != address(0), "UsdtPocket/invalid-manager");
        require(usdt_       != address(0), "UsdtPocket/invalid-usdt");
        require(aUsdt_      != address(0), "UsdtPocket/invalid-aUsdt");
        require(aaveV3Pool_ != address(0), "UsdtPocket/invalid-aaveV3Pool");

        basin      = basin_;
        manager    = manager_;
        usdt       = IERC20(usdt_);
        aUsdt      = IERC20(aUsdt_);
        aaveV3Pool = aaveV3Pool_;

        IERC20(usdt_).safeApprove(basin_, type(uint256).max);
    }

    function depositLiquidity(uint256 amount, address asset) external override onlyBasin returns (uint256) {
        if (amount == 0) return 0;

        require(asset == address(usdt), "UsdtPocket/invalid-asset");

        emit LiquidityDeposited(asset, amount, amount);

        usdt.safeApprove(aaveV3Pool, 0);
        usdt.safeApprove(aaveV3Pool, amount);
        IAaveV3PoolLike(aaveV3Pool).supply(address(usdt), amount, address(this), 0);

        return amount;
    }

    function withdrawLiquidity(uint256 amount, address asset) external override onlyBasin returns (uint256) {
        if (amount == 0) return 0;

        require(asset == address(usdt), "UsdtPocket/invalid-asset");

        uint256 balance = usdt.balanceOf(address(this));

        uint256 convertedAmount;

        if (balance < amount) {
            uint256 remainder = amount - balance;

            aUsdt.safeApprove(aaveV3Pool, remainder);

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

    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(usdt)) {
            return usdt.balanceOf(address(this)) + aUsdt.balanceOf(address(this));
        }
        return 0;
    }

}
