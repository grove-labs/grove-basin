// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

contract MockPSM {

    using SafeERC20 for IERC20;

    address public usds;
    address public usdc;

    constructor(address usds_, address usdc_) {
        usds = usds_;
        usdc = usdc_;
    }

    function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOutWad) {
        // 1:1 swap, but USDC is 6 decimals and USDS is 18 decimals
        usdsOutWad = gemAmt * 1e12;

        IERC20(usdc).safeTransferFrom(msg.sender, address(this), gemAmt);
        IERC20(usds).safeTransfer(usr, usdsOutWad);
    }

    function buyGem(address usr, uint256 gemAmt) external returns (uint256 usdsInWad) {
        // 1:1 swap, but USDS is 18 decimals and USDC is 6 decimals
        usdsInWad = gemAmt * 1e12;

        IERC20(usds).safeTransferFrom(msg.sender, address(this), usdsInWad);
        IERC20(usdc).safeTransfer(usr, gemAmt);
    }

}
