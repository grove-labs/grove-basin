// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

library GroveBasinDeploy {

    function deploy(
        address owner,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        internal returns (address groveBasin)
    {
        groveBasin = address(new GroveBasin(
            owner,
            swapToken,
            collateralToken,
            creditToken,
            swapTokenRateProvider,
            collateralTokenRateProvider,
            creditTokenRateProvider
        ));

        IERC20(swapToken).approve(groveBasin, 1e6);
        GroveBasin(groveBasin).deposit(swapToken, address(0), 1e6);
    }

}
