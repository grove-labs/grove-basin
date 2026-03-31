// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }  from "src/GroveBasin.sol";
import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPauseTests is GroveBasinTestBase {

    address public manager  = makeAddr("manager");
    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        _deposit(address(swapToken),       makeAddr("seeder"), 1_000e6);
        _deposit(address(collateralToken), makeAddr("seeder"), 1_000e18);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000e18);
    }

    /**********************************************************************************************/
    /*** Access control tests                                                                   ***/
    /**********************************************************************************************/

    function test_setPaused_notManager() public {
        address nonManager = makeAddr("nonManager");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonManager,
                groveBasin.MANAGER_ROLE()
            )
        );
        vm.prank(nonManager);
        groveBasin.setPaused(groveBasin.swapExactIn.selector, true);
    }

    function test_setPaused_globalNotManager() public {
        address nonManager = makeAddr("nonManager");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonManager,
                groveBasin.MANAGER_ROLE()
            )
        );
        vm.prank(nonManager);
        groveBasin.setPaused(bytes4(0), true);
    }

    /**********************************************************************************************/
    /*** setPaused flag tests                                                                   ***/
    /**********************************************************************************************/

    function test_setPaused_swapExactIn() public {
        bytes4 sig = groveBasin.swapExactIn.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(manager);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);

        vm.prank(manager);
        groveBasin.setPaused(sig, false);

        assertEq(groveBasin.paused(sig), false);
    }

    function test_setPaused_swapExactOut() public {
        bytes4 sig = groveBasin.swapExactOut.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(manager);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_deposit() public {
        bytes4 sig = groveBasin.deposit.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(manager);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_initiateRedeem() public {
        bytes4 sig = groveBasin.initiateRedeem.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(manager);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_global() public {
        bytes4 globalSig = bytes4(0);
        assertEq(groveBasin.paused(globalSig), false);

        vm.prank(manager);
        groveBasin.setPaused(globalSig, true);

        assertEq(groveBasin.paused(globalSig), true);

        vm.prank(manager);
        groveBasin.setPaused(globalSig, false);

        assertEq(groveBasin.paused(globalSig), false);
    }

    /**********************************************************************************************/
    /*** Event tests                                                                            ***/
    /**********************************************************************************************/

    function test_setPaused_event() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet(sig, true);

        vm.prank(manager);
        groveBasin.setPaused(sig, true);
    }

    function test_setPaused_globalEvent() public {
        bytes4 globalSig = bytes4(0);

        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet(globalSig, true);

        vm.prank(manager);
        groveBasin.setPaused(globalSig, true);
    }

    /**********************************************************************************************/
    /*** Swap pause enforcement tests                                                           ***/
    /**********************************************************************************************/

    function test_swapExactIn_paused() public {
        vm.prank(manager);
        groveBasin.setPaused(groveBasin.swapExactIn.selector, true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_paused() public {
        vm.prank(manager);
        groveBasin.setPaused(groveBasin.swapExactOut.selector, true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_globalPaused() public {
        vm.prank(manager);
        groveBasin.setPaused(bytes4(0), true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_globalPaused() public {
        vm.prank(manager);
        groveBasin.setPaused(bytes4(0), true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(creditToken), address(swapToken), 100e6, type(uint256).max, receiver, 0);
    }

    /**********************************************************************************************/
    /*** Swap unpaused success tests                                                            ***/
    /**********************************************************************************************/

    function test_swapExactIn_unpaused() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(manager);
        groveBasin.setPaused(sig, true);

        vm.prank(manager);
        groveBasin.setPaused(sig, false);

        swapToken.mint(swapper, 100e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Deposit pause enforcement tests                                                        ***/
    /**********************************************************************************************/

    function test_deposit_paused() public {
        vm.prank(manager);
        groveBasin.setPaused(groveBasin.deposit.selector, true);

        address user = groveBasin.liquidityProvider();

        swapToken.mint(user, 100e6);
        vm.startPrank(user);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.deposit(address(swapToken), user, 100e6);
        vm.stopPrank();
    }

    function test_deposit_unpaused() public {
        bytes4 sig = groveBasin.deposit.selector;

        vm.prank(manager);
        groveBasin.setPaused(sig, true);

        vm.prank(manager);
        groveBasin.setPaused(sig, false);

        address user = groveBasin.liquidityProvider();

        swapToken.mint(user, 100e6);
        vm.startPrank(user);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.deposit(address(swapToken), user, 100e6);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** InitiateRedeem pause enforcement tests                                                 ***/
    /**********************************************************************************************/

    function test_initiateRedeem_paused() public {
        vm.prank(manager);
        groveBasin.setPaused(groveBasin.initiateRedeem.selector, true);

        address redeemer = makeAddr("redeemer");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.initiateRedeem(makeAddr("redeemerContract"), 100e18);
    }

}
