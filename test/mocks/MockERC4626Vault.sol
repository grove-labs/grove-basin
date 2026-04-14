// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IERC4626VaultLike } from "src/interfaces/IERC4626VaultLike.sol";

contract MockERC4626Vault is IERC4626VaultLike {

    using SafeERC20 for IERC20;

    IERC20 public underlying;

    mapping(address => uint256) public override balanceOf;

    uint256 public totalShares;

    // Exchange rate numerator/denominator for non-1:1 rate testing.
    // Defaults to 1:1 (rateNumerator = 1, rateDenominator = 1).
    uint256 public rateNumerator   = 1;
    uint256 public rateDenominator = 1;

    constructor(address underlying_) {
        underlying = IERC20(underlying_);
    }

    function setExchangeRate(uint256 numerator_, uint256 denominator_) external {
        rateNumerator   = numerator_;
        rateDenominator = denominator_;
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256 shares) {
        underlying.safeTransferFrom(msg.sender, address(this), assets);

        // shares = assets * rateDenominator / rateNumerator (inverse of convertToAssets)
        shares = assets * rateDenominator / rateNumerator;

        balanceOf[receiver] += shares;
        totalShares         += shares;
    }

    function withdraw(uint256 assets, address receiver, address owner_) external override returns (uint256 shares) {
        // shares = assets * rateDenominator / rateNumerator (inverse of convertToAssets)
        shares = assets * rateDenominator / rateNumerator;

        require(balanceOf[owner_] >= shares, "MockERC4626Vault/insufficient-shares");

        balanceOf[owner_] -= shares;
        totalShares       -= shares;

        underlying.safeTransfer(receiver, assets);
    }

    function redeem(uint256 shares, address receiver, address owner_) external override returns (uint256 assets) {
        require(balanceOf[owner_] >= shares, "MockERC4626Vault/insufficient-shares");

        assets = shares * rateNumerator / rateDenominator;

        balanceOf[owner_] -= shares;
        totalShares       -= shares;

        underlying.safeTransfer(receiver, assets);
    }

    function convertToAssets(uint256 shares) external view override returns (uint256) {
        return shares * rateNumerator / rateDenominator;
    }

}
