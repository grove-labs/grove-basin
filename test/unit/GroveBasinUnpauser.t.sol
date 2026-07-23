// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { GroveBasinUnpauser } from "src/GroveBasinUnpauser.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinUnpauserTests is GroveBasinTestBase {

    GroveBasinUnpauser public unpauserContract;

    address public unpauserOwner  = makeAddr("unpauserOwner");
    address public unpauser       = makeAddr("unpauser");
    address public globalUnpauser = makeAddr("globalUnpauser");
    address public pauser         = makeAddr("pauser");

    bytes32 public unpauserRole;
    bytes32 public globalUnpauserRole;

    function setUp() public override {
        super.setUp();

        address[] memory unpausers = new address[](1);
        unpausers[0] = unpauser;

        address[] memory globalUnpausers = new address[](1);
        globalUnpausers[0] = globalUnpauser;

        unpauserContract   = new GroveBasinUnpauser(unpauserOwner, unpausers, globalUnpausers);
        unpauserRole       = unpauserContract.UNPAUSER_ROLE();
        globalUnpauserRole = unpauserContract.GLOBAL_UNPAUSER_ROLE();

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
        assertTrue(unpauserContract.hasRole(unpauserRole,       unpauser));
        assertTrue(unpauserContract.hasRole(globalUnpauserRole, globalUnpauser));
        assertEq(unpauserContract.getRoleAdmin(unpauserRole),       unpauserContract.OWNER_ROLE());
        assertEq(unpauserContract.getRoleAdmin(globalUnpauserRole), unpauserContract.OWNER_ROLE());
    }

    function test_constructor_rolesAreSeparate() public view {
        assertFalse(unpauserContract.hasRole(globalUnpauserRole, unpauser));
        assertFalse(unpauserContract.hasRole(unpauserRole,       globalUnpauser));
    }

    function test_constructor_zeroOwner() public {
        address[] memory unpausers = new address[](0);

        vm.expectRevert(GroveBasinUnpauser.InvalidOwner.selector);
        new GroveBasinUnpauser(address(0), unpausers, unpausers);
    }

    function test_constructor_multipleUnpausers() public {
        address[] memory unpausers = new address[](2);
        unpausers[0] = makeAddr("u1");
        unpausers[1] = makeAddr("u2");

        address[] memory globalUnpausers = new address[](2);
        globalUnpausers[0] = makeAddr("g1");
        globalUnpausers[1] = makeAddr("g2");

        GroveBasinUnpauser c = new GroveBasinUnpauser(unpauserOwner, unpausers, globalUnpausers);

        assertTrue(c.hasRole(c.UNPAUSER_ROLE(), unpausers[0]));
        assertTrue(c.hasRole(c.UNPAUSER_ROLE(), unpausers[1]));
        assertTrue(c.hasRole(c.GLOBAL_UNPAUSER_ROLE(), globalUnpausers[0]));
        assertTrue(c.hasRole(c.GLOBAL_UNPAUSER_ROLE(), globalUnpausers[1]));
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

    function test_owner_grantsGlobalUnpauserRole() public {
        address newGlobalUnpauser = makeAddr("newGlobalUnpauser");

        vm.prank(unpauserOwner);
        unpauserContract.grantRole(globalUnpauserRole, newGlobalUnpauser);

        assertTrue(unpauserContract.hasRole(globalUnpauserRole, newGlobalUnpauser));
    }

    function test_owner_revokesGlobalUnpauserRole() public {
        vm.prank(unpauserOwner);
        unpauserContract.revokeRole(globalUnpauserRole, globalUnpauser);

        assertFalse(unpauserContract.hasRole(globalUnpauserRole, globalUnpauser));
    }

    function test_nonOwner_cannotGrantGlobalUnpauserRole() public {
        address newGlobalUnpauser = makeAddr("newGlobalUnpauser");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                globalUnpauser,
                unpauserContract.OWNER_ROLE()
            )
        );
        vm.prank(globalUnpauser);
        unpauserContract.grantRole(globalUnpauserRole, newGlobalUnpauser);
    }

    /**********************************************************************************************/
    /*** unpause pass-through                                                                   ***/
    /**********************************************************************************************/

    function test_unpause_global() public {
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0));
        assertTrue(groveBasin.paused(bytes4(0)));

        vm.prank(globalUnpauser);
        unpauserContract.unpause(address(groveBasin), bytes4(0));

        assertFalse(groveBasin.paused(bytes4(0)));
    }

    function test_unpause_global_notGlobalUnpauser() public {
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0));

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                unpauser,
                globalUnpauserRole
            )
        );
        vm.prank(unpauser);
        unpauserContract.unpause(address(groveBasin), bytes4(0));
    }

    function test_unpause_specificKey_notGlobalUnpauser() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                globalUnpauser,
                unpauserRole
            )
        );
        vm.prank(globalUnpauser);
        unpauserContract.unpause(address(groveBasin), sig);
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
        address[] memory globalUnpausers = new address[](1);
        globalUnpausers[0] = globalUnpauser;
        GroveBasinUnpauser rogue = new GroveBasinUnpauser(unpauserOwner, unpausers, globalUnpausers);

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
