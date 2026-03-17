// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { JTRSYGroveBasin }   from "src/JTRSYGroveBasin.sol";

library JTRSYGroveBasinDeploy {

    function deploy(
        address owner,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider,
        address vault
    )
        internal returns (address groveBasin)
    {
        groveBasin = address(new JTRSYGroveBasin(owner, swapToken, collateralToken, creditToken, swapTokenRateProvider, collateralTokenRateProvider, creditTokenRateProvider, vault));

        IERC20(swapToken).approve(groveBasin, 1e6);
        GroveBasin(groveBasin).deposit(swapToken, address(0), 1e6);
    }

}
