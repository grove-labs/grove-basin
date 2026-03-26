// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

contract GroveBasinFactory {

    using SafeERC20 for IERC20;

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
        uint256 seedAmount = 10 ** IERC20(swapToken).decimals();

        IERC20(swapToken).transferFrom(msg.sender, address(this), seedAmount);

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

        IERC20(swapToken).approve(groveBasin, seedAmount);
        GroveBasin(groveBasin).depositInitial(swapToken, address(0), seedAmount);

        emit GroveBasinDeployed(groveBasin, owner, swapToken, collateralToken, creditToken);
    }

}
