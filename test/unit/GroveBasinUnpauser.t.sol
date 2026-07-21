// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { GroveBasinUnpauser } from "src/GroveBasinUnpauser.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinUnpauserTests is GroveBasinTestBase {

    GroveBasinUnpauser public unpauserContract;

    address public unpauserOwner = makeAddr("unpauserOwner");
    address public unpauser      = makeAddr("unpauser");
    address public pauser        = makeAddr("pauser");

    bytes32 public unpauserRole;

    function setUp() public override {
        super.setUp();

        address[] memory unpausers = new address[](1);
        unpausers[0] = unpauser;

        unpauserContract = new GroveBasinUnpauser(unpauserOwner, unpausers);
        unpauserRole     = unpauserContract.UNPAUSER_ROLE();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), address(unpauserContract));
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(),        pauser);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Constructor tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_grantsRoles() public view {
        assertTrue(unpauserContract.hasRole(unpauserContract.OWNER_ROLE(), unpauserOwner));
        assertTrue(unpauserContract.hasRole(unpauserRole, unpauser));
        assertEq(unpauserContract.getRoleAdmin(unpauserRole), unpauserContract.OWNER_ROLE());
    }

    function test_constructor_zeroOwner() public {
        address[] memory unpausers = new address[](0);

        vm.expectRevert(GroveBasinUnpauser.InvalidOwner.selector);
        new GroveBasinUnpauser(address(0), unpausers);
    }

    function test_constructor_multipleUnpausers() public {
        address[] memory unpausers = new address[](2);
        unpausers[0] = makeAddr("u1");
        unpausers[1] = makeAddr("u2");

        GroveBasinUnpauser c = new GroveBasinUnpauser(unpauserOwner, unpausers);

        assertTrue(c.hasRole(c.UNPAUSER_ROLE(), unpausers[0]));
        assertTrue(c.hasRole(c.UNPAUSER_ROLE(), unpausers[1]));
    }

    /**********************************************************************************************/
    /*** OWNER_ROLE manages UNPAUSER_ROLE                                                       ***/
    /**********************************************************************************************/

    function test_owner_grantsUnpauserRole() public {
        address newUnpauser = makeAddr("newUnpauser");

        vm.prank(unpauserOwner);
        unpauserContract.grantRole(unpauserRole, newUnpauser);

        assertTrue(unpauserContract.hasRole(unpauserRole, newUnpauser));
    }

    function test_owner_revokesUnpauserRole() public {
        vm.prank(unpauserOwner);
        unpauserContract.revokeRole(unpauserRole, unpauser);

        assertFalse(unpauserContract.hasRole(unpauserRole, unpauser));
    }

    function test_nonOwner_cannotGrantUnpauserRole() public {
        address newUnpauser = makeAddr("newUnpauser");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                unpauser,
                unpauserContract.OWNER_ROLE()
            )
        );
        vm.prank(unpauser);
        unpauserContract.grantRole(unpauserRole, newUnpauser);
    }

    /**********************************************************************************************/
    /*** unpause pass-through                                                                   ***/
    /**********************************************************************************************/

    function test_unpause_global() public {
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0));
        assertTrue(groveBasin.paused(bytes4(0)));

        vm.prank(unpauser);
        unpauserContract.unpause(address(groveBasin), bytes4(0));

        assertFalse(groveBasin.paused(bytes4(0)));
    }

    function test_unpause_specificKey() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig);
        assertTrue(groveBasin.paused(sig));

        vm.prank(unpauser);
        unpauserContract.unpause(address(groveBasin), sig);

        assertFalse(groveBasin.paused(sig));
    }

    function test_unpause_emitsEvent() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig);

        vm.expectEmit(true, true, true, false);
        emit GroveBasinUnpauser.Unpaused(address(groveBasin), sig, unpauser);

        vm.prank(unpauser);
        unpauserContract.unpause(address(groveBasin), sig);
    }

    function test_unpause_notUnpauser() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig);

        address notUnpauser = makeAddr("notUnpauser");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                notUnpauser,
                unpauserRole
            )
        );
        vm.prank(notUnpauser);
        unpauserContract.unpause(address(groveBasin), sig);
    }

    function test_unpause_withoutManagerAdminRoleReverts() public {
        address[] memory unpausers = new address[](1);
        unpausers[0] = unpauser;
        GroveBasinUnpauser rogue = new GroveBasinUnpauser(unpauserOwner, unpausers);

        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(rogue),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(unpauser);
        rogue.unpause(address(groveBasin), sig);
    }

}
