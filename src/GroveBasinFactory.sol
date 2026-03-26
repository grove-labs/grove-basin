// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { GroveBasin } from "src/GroveBasin.sol";

contract GroveBasinFactory {

    event GroveBasinDeployed(
        address indexed groveBasin,
        address indexed owner,
        address         swapToken,
        address         collateralToken,
        address         creditToken
    );

    function deploy(
        address owner,
        address liquidityProvider,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        external returns (address groveBasin)
    {
        groveBasin = address(new GroveBasin(
            owner,
            liquidityProvider,
            swapToken,
            collateralToken,
            creditToken,
            swapTokenRateProvider,
            collateralTokenRateProvider,
            creditTokenRateProvider
        ));

        emit GroveBasinDeployed(groveBasin, owner, swapToken, collateralToken, creditToken);
    }

}
