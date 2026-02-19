// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

library GroveBasinDeploy {

    function deploy(
        address owner,
        address secondaryToken,
        address collateralToken,
        address creditToken,
        address creditTokenRateProvider
    )
        internal returns (address groveBasin)
    {
        groveBasin = address(new GroveBasin(owner, secondaryToken, collateralToken, creditToken, creditTokenRateProvider));

        IERC20(secondaryToken).approve(groveBasin, 1e6);
        GroveBasin(groveBasin).deposit(secondaryToken, address(0), 1e6);
    }

}
