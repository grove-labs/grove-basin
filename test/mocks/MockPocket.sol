// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

contract MockPocket is IGroveBasinPocket {

    using SafeERC20 for IERC20;

    address public immutable override basin;
    address public immutable swapToken;
    address public immutable usds;
    address public immutable psm;

    constructor(address basin_, address swapToken_, address usds_, address psm_) {
        basin     = basin_;
        swapToken = swapToken_;
        usds      = usds_;
        psm       = psm_;

        IERC20(swapToken_).safeApprove(basin_, type(uint256).max);

        if (usds_ != address(0)) {
            IERC20(usds_).safeApprove(basin_, type(uint256).max);
        }
    }

    function depositLiquidity(uint256 amount, address) external override returns (uint256) {
        return amount;
    }

    function withdrawLiquidity(uint256 amount, address) external override returns (uint256) {
        return amount;
    }

    function availableBalance(address asset) external view override returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}
