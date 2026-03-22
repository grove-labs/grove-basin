// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

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
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        external returns (address groveBasin)
    {
        IERC20(swapToken).transferFrom(msg.sender, address(this), 1e6);

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

        emit GroveBasinDeployed(groveBasin, owner, swapToken, collateralToken, creditToken);
    }

}
