// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { IGroveBasin }         from "src/interfaces/IGroveBasin.sol";
import { JTRSYTokenRedeemer } from "src/JTRSYTokenRedeemer.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockAsyncVault }     from "test/mocks/MockAsyncVault.sol";

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
        vm.expectRevert(IGroveBasin.InvalidRedeemer.selector);
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
        groveBasin.completeRedeem(bytes32(uint256(1)));
    }

}

contract GroveBasinCompleteRedeemInvalidRequestTests is GroveBasinTestBase {

    function test_completeRedeem_invalidRedeemRequest() public {
        address redeemer = makeAddr("redeemer");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(IGroveBasin.InvalidRedeemRequest.selector);
        groveBasin.completeRedeem(bytes32(uint256(1)));
    }

}

/**********************************************************************************************/
/*** RequestAlreadyExists tests                                                             ***/
/**********************************************************************************************/

contract GroveBasinRequestAlreadyExistsTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));
        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        vm.stopPrank();

        creditToken.mint(address(groveBasin), 10_000e18);
    }

    function test_initiateRedeem_requestAlreadyExists() public {
        uint256 amount = 1000e18;

        vm.startPrank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);

        vm.expectRevert(IGroveBasin.RequestAlreadyExists.selector);
        groveBasin.initiateRedeem(address(redeemer), amount);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** CompleteRedeem InvalidRedeemer tests                                                    ***/
/**********************************************************************************************/

contract GroveBasinCompleteRedeemInvalidRedeemerTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));
        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        vm.stopPrank();

        creditToken.mint(address(groveBasin), 10_000e18);
    }

    function test_completeRedeem_invalidRedeemer() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), amount);

        vm.prank(owner);
        groveBasin.removeTokenRedeemer(address(redeemer));

        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidRedeemer.selector);
        groveBasin.completeRedeem(requestId);
    }

}
