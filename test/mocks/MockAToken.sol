// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

contract MockAToken is MockERC20 {

    address public immutable UNDERLYING_ASSET_ADDRESS;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address underlying_)
        MockERC20(name_, symbol_, decimals_)
    {
        UNDERLYING_ASSET_ADDRESS = underlying_;
    }

}
