// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IGroveBasinPocket }  from "src/interfaces/IGroveBasinPocket.sol";
import { IERC4626VaultLike }  from "src/interfaces/IERC4626VaultLike.sol";

/**
 * @title  MorphoUsdtPocket
 * @notice Pocket that deploys USDT liquidity into a Morpho ERC-4626 vault and withdraws on
 *         demand.
 *
 * @dev    Trust model:
 *         - DEFAULT_ADMIN_ROLE: Trusted. Can manage MANAGER_ROLE grants/revocations.
 *         - MANAGER_ROLE: Semi-trusted. Can call depositLiquidity and withdrawLiquidity.
 *         - Basin: Immutable address set at construction. Can call depositLiquidity and
 *           withdrawLiquidity independently of any role assignments.
 *
 *         The vault address is immutable and set at construction — there is no setter. This
 *         ensures the yield strategy cannot be changed after deployment.
 */
contract MorphoUsdtPocket is IGroveBasinPocket, AccessControl {

    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public override immutable basin;

    IERC20 public immutable usdt;

    address public immutable vault;

    modifier onlyBasinOrManager() {
        require(msg.sender == basin || hasRole(MANAGER_ROLE, msg.sender), "MorphoUsdtPocket/not-authorized");
        _;
    }

    constructor(
        address basin_,
        address admin_,
        address usdt_,
        address vault_
    ) {
        require(basin_ != address(0), "MorphoUsdtPocket/invalid-basin");
        require(admin_ != address(0), "MorphoUsdtPocket/invalid-admin");
        require(usdt_  != address(0), "MorphoUsdtPocket/invalid-usdt");
        require(vault_ != address(0), "MorphoUsdtPocket/invalid-vault");

        basin = basin_;
        usdt  = IERC20(usdt_);
        vault = vault_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        IERC20(usdt_).safeApprove(basin_, type(uint256).max);
    }

    function depositLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        require(asset == address(usdt), "MorphoUsdtPocket/invalid-asset");

        usdt.safeApprove(vault, 0);
        usdt.safeApprove(vault, amount);
        IERC4626VaultLike(vault).deposit(amount, address(this));

        emit LiquidityDeposited(asset, amount, amount);
        return amount;
    }

    function withdrawLiquidity(uint256 amount, address asset) external override onlyBasinOrManager returns (uint256) {
        if (amount == 0) return 0;

        require(asset == address(usdt), "MorphoUsdtPocket/invalid-asset");

        uint256 balance = usdt.balanceOf(address(this));

        uint256 convertedAmount;

        if (balance < amount) {
            uint256 remainder = amount - balance;

            IERC4626VaultLike(vault).withdraw(remainder, address(this), address(this));
            convertedAmount = remainder;
        }

        emit LiquidityDrawn(asset, amount, convertedAmount);
        return amount;
    }

    function availableBalance(address asset) external view override returns (uint256) {
        if (asset == address(usdt)) {
            return usdt.balanceOf(address(this))
                + IERC4626VaultLike(vault).convertToAssets(
                    IERC4626VaultLike(vault).balanceOf(address(this))
                );
        }
        return 0;
    }

}
