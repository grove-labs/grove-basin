// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { UsdsUsdcPocket } from "src/pockets/UsdsUsdcPocket.sol";

contract UsdsUsdcPocketFactory {

    function createUsdsUsdcPocket(
        address groveBasin,
        address swapToken,
        address usds,
        address psm,
        address groveProxy
    ) external returns (address) {
        UsdsUsdcPocket pocket_ = new UsdsUsdcPocket(
            groveBasin,
            swapToken,
            usds,
            psm,
            groveProxy
        );

        return address(pocket_);
    }

}
