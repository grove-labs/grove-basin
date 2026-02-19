// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

library GroveBasinDeploy {

    function deploy(
        address owner,
        address usdc,
        address collateralToken,
        address creditToken,
        address creditTokenRateProvider
    )
        internal returns (address groveBasin)
    {
        groveBasin = address(new GroveBasin(owner, usdc, collateralToken, creditToken, creditTokenRateProvider));

        IERC20(usdc).approve(groveBasin, 1e6);
        GroveBasin(groveBasin).deposit(usdc, address(0), 1e6);
    }

}
