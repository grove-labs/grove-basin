// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";


contract DeployEthereum is Script {

    function run() external {
        vm.createSelectFork(getChain("base").rpcUrl);

        console.log("Deploying GroveBasin...");

        vm.startBroadcast();

        address groveBasin = GroveBasinDeploy.deploy({
            owner                       : Ethereum.GROVE_PROXY,
            secondaryToken              : Ethereum.USDC,
            collateralToken             : Ethereum.USDS,
            creditToken                 : Ethereum.SUSDS,
            collateralTokenRateProvider : address(0), // TODO: set up rate provider
            creditTokenRateProvider     : address(0)  // TODO: set up rate provider
        });

        vm.stopBroadcast();

        console.log("GroveBasin deployed at:", groveBasin);
    }

}
