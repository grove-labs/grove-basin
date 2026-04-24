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
        return deploy({
            salt                        : keccak256(abi.encode(owner, swapToken, collateralToken, creditToken)),
            owner                       : owner,
            liquidityProvider           : liquidityProvider,
            swapToken                   : swapToken,
            collateralToken             : collateralToken,
            creditToken                 : creditToken,
            swapTokenRateProvider       : swapTokenRateProvider,
            collateralTokenRateProvider : collateralTokenRateProvider,
            creditTokenRateProvider     : creditTokenRateProvider
        });
    }

    function deploy(
        bytes32 salt,
        address owner,
        address liquidityProvider,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        public returns (address groveBasin)
    {
        uint256 seedAmount = 10 ** IERC20(swapToken).decimals();

        IERC20(swapToken).safeTransferFrom(msg.sender, address(this), seedAmount);

        groveBasin = address(new GroveBasin{salt: salt}(
            owner,
            liquidityProvider,
            swapToken,
            collateralToken,
            creditToken,
            swapTokenRateProvider,
            collateralTokenRateProvider,
            creditTokenRateProvider
        ));

        IERC20(swapToken).safeApprove(groveBasin, seedAmount);
        GroveBasin(groveBasin).depositInitial(swapToken, seedAmount);

        emit GroveBasinDeployed(groveBasin, owner, swapToken, collateralToken, creditToken);
    }

}
