// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

contract MockGroveBasinPocket is IGroveBasinPocket {

    address public override basin;
    address public override manager;

    IERC20 public swapToken;

    constructor(address basin_, address swapToken_) {
        basin     = basin_;
        manager   = basin_;
        swapToken = IERC20(swapToken_);

        IERC20(swapToken_).approve(basin_, type(uint256).max);
    }

    function drawLiquidity(uint256, address) external override {}

    function depositLiquidity(uint256, address) external override {}

    function availableBalance(address asset) external view override returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

}
