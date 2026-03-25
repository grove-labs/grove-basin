// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

/**********************************************************************************************/
/*** InitiateRedeem tests                                                                   ***/
/**********************************************************************************************/

contract GroveBasinInitiateRedeemTests is GroveBasinTestBase {

    function test_initiateRedeem_notRedeemer() public {
        address nonRedeemer = makeAddr("nonRedeemer");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonRedeemer,
                groveBasin.REDEEMER_ROLE()
            )
        );
        vm.prank(nonRedeemer);
        groveBasin.initiateRedeem(makeAddr("redeemer"), 1000e18);
    }

}

/**********************************************************************************************/
/*** CompleteRedeem tests                                                                   ***/
/**********************************************************************************************/

contract GroveBasinInitiateRedeemInvalidRedeemerContractTests is GroveBasinTestBase {

    function test_initiateRedeem_invalidRedeemerContract() public {
        address redeemer        = makeAddr("redeemer");
        address invalidContract = makeAddr("invalidContract");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert("GB/invalid-redeemer");
        groveBasin.initiateRedeem(invalidContract, 100e18);
    }

}

contract GroveBasinCompleteRedeemTests is GroveBasinTestBase {

    function test_completeRedeem_notRedeemer() public {
        address nonRedeemer = makeAddr("nonRedeemer");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonRedeemer,
                groveBasin.REDEEMER_ROLE()
            )
        );
        vm.prank(nonRedeemer);
        groveBasin.completeRedeem(makeAddr("redeemer"), 1000e18);
    }

}

contract GroveBasinCompleteRedeemInvalidRedeemerContractTests is GroveBasinTestBase {

    function test_completeRedeem_invalidRedeemerContract() public {
        address redeemer        = makeAddr("redeemer");
        address invalidContract = makeAddr("invalidContract");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert("GB/invalid-redeemer");
        groveBasin.completeRedeem(invalidContract, 100e18);
    }

}
