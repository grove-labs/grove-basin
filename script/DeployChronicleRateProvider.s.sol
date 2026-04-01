// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { ChronicleRateProvider } from "src/rate-providers/ChronicleRateProvider.sol";

/**
 * @title  DeployChronicleRateProvider
 * @notice Script to deploy a ChronicleRateProvider contract with a specified Chronicle oracle.
 *
 * @dev    Usage:
 *         forge script script/DeployChronicleRateProvider.s.sol:DeployChronicleRateProvider \
 *             --rpc-url <RPC_URL> \
 *             --account <ACCOUNT_NAME> \
 *             --broadcast \
 *             --sig "run(address)" <ORACLE_ADDRESS>
 *
 *         Example with grove-dev-deployer account:
 *         forge script script/DeployChronicleRateProvider.s.sol:DeployChronicleRateProvider \
 *             --rpc-url $MAINNET_RPC_URL \
 *             --account grove-dev-deployer \
 *             --broadcast \
 *             --sig "run(address)" 0x1234567890123456789012345678901234567890
 *
 *         For simpler usage, set the oracle address in the run() function and run without parameters:
 *         forge script script/DeployChronicleRateProvider.s.sol:DeployChronicleRateProvider \
 *             --rpc-url $MAINNET_RPC_URL \
 *             --account grove-dev-deployer \
 *             --broadcast
 */
contract DeployChronicleRateProvider is Script {

    /**
     * @notice Deploy a ChronicleRateProvider with a default oracle address.
     * @dev    Modify the oracle address to deploy with a different Chronicle oracle.
     * @return chronicleRateProvider The address of the deployed ChronicleRateProvider.
     */
    function run() external returns (address chronicleRateProvider) {
        // Default oracle address - MODIFY THIS to your Chronicle oracle address
        address oracle = address(0);  // MUST be set before deployment

        require(oracle != address(0), "DeployChronicleRateProvider/oracle-not-set");

        return _deploy(oracle);
    }

    /**
     * @notice Deploy a ChronicleRateProvider with a specified oracle address.
     * @param oracle The Chronicle oracle address to use.
     * @return chronicleRateProvider The address of the deployed ChronicleRateProvider.
     */
    function run(address oracle) external returns (address chronicleRateProvider) {
        return _deploy(oracle);
    }

    /**
     * @dev Internal function to deploy the ChronicleRateProvider.
     */
    function _deploy(address oracle) internal returns (address chronicleRateProvider) {
        require(oracle != address(0), "DeployChronicleRateProvider/zero-oracle");

        console.log("Deploying ChronicleRateProvider...");
        console.log("Oracle address:", oracle);

        vm.startBroadcast();

        chronicleRateProvider = address(new ChronicleRateProvider(oracle));

        vm.stopBroadcast();

        console.log("ChronicleRateProvider deployed at:", chronicleRateProvider);
    }

}
