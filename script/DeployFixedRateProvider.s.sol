// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { FixedRateProvider } from "src/oracles/FixedRateProvider.sol";

/**
 * @title  DeployFixedRateProvider
 * @notice Script to deploy a FixedRateProvider contract with a specified rate.
 *
 * @dev    Usage:
 *         forge script script/DeployFixedRateProvider.s.sol:DeployFixedRateProvider \
 *             --rpc-url <RPC_URL> \
 *             --broadcast \
 *             --sig "run(uint256)" <RATE>
 *
 *         Example (1:1 rate):
 *         forge script script/DeployFixedRateProvider.s.sol:DeployFixedRateProvider \
 *             --rpc-url $RPC_URL \
 *             --broadcast \
 *             --sig "run(uint256)" 1000000000000000000000000000
 *
 *         For simpler usage, set the rate in the runDefault() function and run without parameters:
 *         forge script script/DeployFixedRateProvider.s.sol:DeployFixedRateProvider \
 *             --rpc-url $RPC_URL \
 *             --broadcast
 */
contract DeployFixedRateProvider is Script {

    /// @notice Precision of the rate (1e27).
    uint256 public constant RATE_PRECISION = 1e27;

    /**
     * @notice Deploy a FixedRateProvider with a default 1:1 rate.
     * @dev    Modify the DEFAULT_RATE constant to deploy with a different default rate.
     * @return fixedRateProvider The address of the deployed FixedRateProvider.
     */
    function run() external returns (address fixedRateProvider) {
        // Default rate: 1:1 (1e27)
        // Modify this value to deploy with a different rate
        uint256 rate = 1e27;

        return _deploy(rate);
    }

    /**
     * @dev Internal function to deploy the FixedRateProvider.
     */
    function _deploy(uint256 rate) internal returns (address fixedRateProvider) {
        require(rate != 0, "DeployFixedRateProvider/zero-rate");

        console.log("Deploying FixedRateProvider...");
        console.log("Rate:", rate);
        console.log("Rate (in decimal):", rate / RATE_PRECISION);

        vm.startBroadcast();

        fixedRateProvider = address(new FixedRateProvider(rate));

        vm.stopBroadcast();

        console.log("FixedRateProvider deployed at:", fixedRateProvider);
    }

}
