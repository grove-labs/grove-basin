// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

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
