// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract DeployTimelockController is Script {

    uint256 constant MIN_DELAY = 7 days;

    /**
     * @notice Deploy a TimelockController with a specified proposer address.
     * @dev    Usage:
     *         DEPLOYER=<admin_address> \
     *         forge script script/DeployTimelockController.s.sol:DeployTimelockController --sig "run(address)" <PROPOSER_ADDRESS>
     */
    function run(address proposer) external returns (address timelock) {
        require(proposer != address(0), "DeployTimelockController/zero-proposer");

        address deployer = vm.envAddress("DEPLOYER");

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = Ethereum.GROVE_PROXY;

        console.log("Deploying TimelockController...");
        console.log("Min delay:     ", MIN_DELAY);
        console.log("Proposer:      ", proposer);
        console.log("Executor:       Grove Proxy", Ethereum.GROVE_PROXY);
        console.log("Canceller:      ALM Freezer", Ethereum.ALM_FREEZER);
        console.log("Default admin: ", deployer);

        vm.startBroadcast();

        TimelockController timelockController = new TimelockController(
            MIN_DELAY,
            proposers,
            executors,
            deployer
        );

        // Constructor grants CANCELLER_ROLE to proposers by default. Grant it
        // to the ALM Freezer
        timelockController.grantRole(timelockController.CANCELLER_ROLE(), Ethereum.ALM_FREEZER);

        vm.stopBroadcast();

        timelock = address(timelockController);
        console.log("TimelockController deployed at:", timelock);
    }

}
