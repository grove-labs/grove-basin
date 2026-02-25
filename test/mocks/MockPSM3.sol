// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

contract MockPSM3 {

    using SafeERC20 for IERC20;

    address public usds;
    address public usdc;

    constructor(address usds_, address usdc_) {
        usds = usds_;
        usdc = usdc_;
    }

    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256
    ) external returns (uint256 amountIn) {
        require(assetIn  == usds, "MockPSM3/invalid-assetIn");
        require(assetOut == usdc, "MockPSM3/invalid-assetOut");

        // 1:1 swap, but USDS is 18 decimals and USDC is 6 decimals
        amountIn = amountOut * 1e12;
        require(amountIn <= maxAmountIn, "MockPSM3/amountIn-too-high");

        IERC20(usds).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(usdc).safeTransfer(receiver, amountOut);
    }

}
