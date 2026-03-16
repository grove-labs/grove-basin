// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";
import { IAaveV3PoolLike }   from "src/interfaces/IAaveV3PoolLike.sol";

/**
 * @title  AaveV3UsdtPocket
 * @notice Pocket that deploys USDT liquidity into Aave V3 and withdraws on demand.
 *
 * @dev    Trust model:
 *         - DEFAULT_ADMIN_ROLE: Trusted. Can manage MANAGER_ROLE grants/revocations.
 *         - MANAGER_ROLE: Semi-trusted. Can call depositLiquidity and withdrawLiquidity.
 *         - Basin: Immutable address set at construction. Can call depositLiquidity and
 *           withdrawLiquidity independently of any role assignments.
 */
contract AaveV3UsdtPocket is IGroveBasinPocket, AccessControl {

    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public override immutable basin;

    IERC20 public immutable usdt;
    IERC20 public immutable aUsdt;

    address public immutable aaveV3Pool;

    modifier onlyBasinOrManager() {
        require(msg.sender == basin || hasRole(MANAGER_ROLE, msg.sender), "AaveV3UsdtPocket/not-authorized");
        _;
    }

    constructor(
        address basin_,
        address admin_,
        address usdt_,
        address aUsdt_,
        address aaveV3Pool_
    ) {
        require(basin_      != address(0), "AaveV3UsdtPocket/invalid-basin");
        require(admin_      != address(0), "AaveV3UsdtPocket/invalid-admin");
        require(usdt_       != address(0), "AaveV3UsdtPocket/invalid-usdt");
        require(aUsdt_      != address(0), "AaveV3UsdtPocket/invalid-aUsdt");
        require(aaveV3Pool_ != address(0), "AaveV3UsdtPocket/invalid-aaveV3Pool");

        basin      = basin_;
        usdt       = IERC20(usdt_);
        aUsdt      = IERC20(aUsdt_);
        aaveV3Pool = aaveV3Pool_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        IERC20(usdt_).safeApprove(basin_, type(uint256).max);
    }

    function depositLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        require(asset == address(usdt), "AaveV3UsdtPocket/invalid-asset");

        emit LiquidityDeposited(asset, amount, amount);

        usdt.safeApprove(aaveV3Pool, 0);
        usdt.safeApprove(aaveV3Pool, amount);
        IAaveV3PoolLike(aaveV3Pool).supply(address(usdt), amount, address(this), 0);

        return amount;
    }

    function withdrawLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        require(asset == address(usdt), "AaveV3UsdtPocket/invalid-asset");

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
