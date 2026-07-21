// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { stdJson } from "forge-std/StdJson.sol";

import { GroveBasinUnpauser } from "src/GroveBasinUnpauser.sol";

contract DeployGroveBasinUnpauser is Script {

    using stdJson for string;

    /**
     * @notice Deploy a GroveBasinUnpauser from a JSON config.
     * @dev    Config format:
     *         {
     *           "owner": "0x...",
     *           "unpausers": ["0x...", "0x..."]
     *         }
     *         Usage:
     *         forge script script/DeployGroveBasinUnpauser.s.sol:DeployGroveBasinUnpauser \
     *           --sig "run(string)" script/input/GroveBasinUnpauser.example.json
     * @param  configPath Path to the JSON config file.
     * @return unpauser    Address of the deployed GroveBasinUnpauser.
     */
    function run(string memory configPath) external returns (address unpauser) {
        string memory config = vm.readFile(configPath);

        address           owner     = config.readAddress(".owner");
        address[] memory  unpausers = config.readAddressArray(".unpausers");

        require(owner != address(0), "DeployGroveBasinUnpauser/zero-owner");

        console.log("Deploying GroveBasinUnpauser...");
        console.log("Owner:", owner);
        for (uint256 i = 0; i < unpausers.length; i++) {
            console.log("Unpauser:", unpausers[i]);
        }

        vm.startBroadcast();
        unpauser = address(new GroveBasinUnpauser(owner, unpausers));
        vm.stopBroadcast();

        console.log("GroveBasinUnpauser deployed at:", unpauser);
    }

}
