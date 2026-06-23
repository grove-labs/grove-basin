// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { GroveBasinFactory } from "src/GroveBasinFactory.sol";

/**
 * @title  DeployGroveBasinFactory
 * @notice Script to deploy the GroveBasinFactory contract.
 *
 * @dev    Usage:
 *         forge script script/DeployGroveBasinFactory.s.sol:DeployGroveBasinFactory \
 *             --rpc-url $MAINNET_RPC_URL \
 *             --account grove-dev-deployer \
 *             --broadcast
 */
contract DeployGroveBasinFactory is Script {

    /**
     * @notice Deploy the GroveBasinFactory.
     * @return factory The address of the deployed GroveBasinFactory.
     */
    function run() external returns (address factory) {
        console.log("Deploying GroveBasinFactory...");

        vm.startBroadcast();

        factory = address(new GroveBasinFactory());

        vm.stopBroadcast();

        console.log("GroveBasinFactory deployed at:", factory);
    }

}
