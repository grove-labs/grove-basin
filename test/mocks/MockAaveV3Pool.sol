// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

contract MockAaveV3Pool {

    using SafeERC20 for IERC20;

    address public aToken;
    address public underlying;

    constructor(address aToken_, address underlying_) {
        aToken     = aToken_;
        underlying = underlying_;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        require(asset == underlying, "MockAaveV3Pool/invalid-asset");

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(aToken).safeTransfer(onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        require(asset == underlying, "MockAaveV3Pool/invalid-asset");

        IERC20(aToken).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(underlying).safeTransfer(to, amount);

        return amount;
    }

}
