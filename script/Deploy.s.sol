// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { PSM3Deploy } from "deploy/PSM3Deploy.sol";


contract DeployEthereum is Script {

    function run() external {
        vm.createSelectFork(getChain("base").rpcUrl);

        console.log("Deploying PSM...");

        vm.startBroadcast();

        address psm = PSM3Deploy.deploy({
            owner        : Ethereum.GROVE_PROXY,
            usdc         : Ethereum.USDC,
            usds         : Ethereum.USDS,
            susds        : Ethereum.SUSDS,
            rateProvider : address(0) // TODO: set up rate provider
        });

        vm.stopBroadcast();

        console.log("PSM3 deployed at:", psm);
    }

}
