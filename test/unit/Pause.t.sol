// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPauseTests is GroveBasinTestBase {

    address public manager  = makeAddr("manager");
    address public pauser   = makeAddr("pauser");
    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(),  pauser);
        vm.stopPrank();

        _deposit(address(swapToken),       makeAddr("seeder"), 1_000e6);
        _deposit(address(collateralToken), makeAddr("seeder"), 1_000e18);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000e18);
    }

    /**********************************************************************************************/
    /*** Access control tests                                                                   ***/
    /**********************************************************************************************/

    function test_setPaused_notPauser() public {
        address nonPauser = makeAddr("nonPauser");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonPauser,
                groveBasin.PAUSER_ROLE()
            )
        );
        vm.prank(nonPauser);
        groveBasin.setPaused(groveBasin.swapExactIn.selector, true);
    }

    function test_setPaused_globalNotPauser() public {
        address nonPauser = makeAddr("nonPauser");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonPauser,
                groveBasin.PAUSER_ROLE()
            )
        );
        vm.prank(nonPauser);
        groveBasin.setPaused(bytes4(0), true);
    }

    function test_setPaused_managerCannotPause() public {
        bytes32 pauserRole = groveBasin.PAUSER_ROLE();

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                pauserRole
            )
        );
        vm.prank(manager);
        groveBasin.setPaused(groveBasin.swapExactIn.selector, true);
    }

    function test_setPaused_pauserCannotUnpause() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        vm.prank(pauser);
        vm.expectRevert(IGroveBasin.OnlyManagerAdminCanUnpause.selector);
        groveBasin.setPaused(sig, false);
    }

    function test_setUnpaused_notManagerAdmin() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                pauser,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(pauser);
        groveBasin.setUnpaused(sig);
    }

    function test_setUnpaused_managerCannotUnpause() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.setUnpaused(sig);
    }

    function test_setUnpaused_event() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet(sig, false);

        vm.prank(owner);
        groveBasin.setUnpaused(sig);
    }

    /**********************************************************************************************/
    /*** setPaused flag tests                                                                   ***/
    /**********************************************************************************************/

    function test_setPaused_swapExactIn() public {
        bytes4 sig = groveBasin.swapExactIn.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);

        vm.prank(owner);
        groveBasin.setUnpaused(sig);

        assertEq(groveBasin.paused(sig), false);
    }

    function test_setPaused_swapExactOut() public {
        bytes4 sig = groveBasin.swapExactOut.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_deposit() public {
        bytes4 sig = groveBasin.deposit.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_initiateRedeem() public {
        bytes4 sig = groveBasin.initiateRedeem.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_completeRedeem() public {
        bytes4 sig = groveBasin.completeRedeem.selector;
        assertEq(groveBasin.paused(sig), false);

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        assertEq(groveBasin.paused(sig), true);
    }

    function test_setPaused_global() public {
        bytes4 globalSig = bytes4(0);
        assertEq(groveBasin.paused(globalSig), false);

        vm.prank(pauser);
        groveBasin.setPaused(globalSig, true);

        assertEq(groveBasin.paused(globalSig), true);

        vm.prank(owner);
        groveBasin.setUnpaused(globalSig);

        assertEq(groveBasin.paused(globalSig), false);
    }

    /**********************************************************************************************/
    /*** Event tests                                                                            ***/
    /**********************************************************************************************/

    function test_setPaused_event() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet(sig, true);

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);
    }

    function test_setPaused_globalEvent() public {
        bytes4 globalSig = bytes4(0);

        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet(globalSig, true);

        vm.prank(pauser);
        groveBasin.setPaused(globalSig, true);
    }

    /**********************************************************************************************/
    /*** Swap pause enforcement tests                                                           ***/
    /**********************************************************************************************/

    function test_swapExactIn_paused() public {
        vm.prank(pauser);
        groveBasin.setPaused(groveBasin.swapExactIn.selector, true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_paused() public {
        vm.prank(pauser);
        groveBasin.setPaused(groveBasin.swapExactOut.selector, true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_globalPaused() public {
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0), true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_globalPaused() public {
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0), true);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(creditToken), address(swapToken), 100e6, type(uint256).max, receiver, 0);
    }

    /**********************************************************************************************/
    /*** Swap direction pause key flag tests                                                    ***/
    /**********************************************************************************************/

    function test_setPaused_swapCreditToCollateral() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_COLLATERAL();
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);

        vm.prank(owner);
        groveBasin.setUnpaused(key);

        assertEq(groveBasin.paused(key), false);
    }

    function test_setPaused_swapCreditToSwap() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_SWAP();
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);
    }

    function test_setPaused_swapCollateralToCredit() public {
        bytes4 key = groveBasin.PAUSED_SWAP_COLLATERAL_TO_CREDIT();
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);
    }

    function test_setPaused_swapSwapToCredit() public {
        bytes4 key = groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT();
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);
    }

    function test_setPaused_depositCredit() public {
        bytes4 key = groveBasin.PAUSED_DEPOSIT_CREDIT();
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);

        vm.prank(owner);
        groveBasin.setUnpaused(key);

        assertEq(groveBasin.paused(key), false);
    }

    function test_setPaused_withdrawCredit() public {
        bytes4 key = groveBasin.PAUSED_WITHDRAW_CREDIT();
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);

        vm.prank(owner);
        groveBasin.setUnpaused(key);

        assertEq(groveBasin.paused(key), false);
    }

    function test_setPaused_arbitraryKey() public {
        bytes4 key = bytes4(keccak256("CUSTOM_KEY"));
        assertEq(groveBasin.paused(key), false);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        assertEq(groveBasin.paused(key), true);

        vm.prank(owner);
        groveBasin.setUnpaused(key);

        assertEq(groveBasin.paused(key), false);
    }

    function test_setPaused_arbitraryKeyEvent() public {
        bytes4 key = bytes4(keccak256("CUSTOM_KEY"));

        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet(key, true);

        vm.prank(pauser);
        groveBasin.setPaused(key, true);
    }

    /**********************************************************************************************/
    /*** Swap direction pause enforcement tests                                                 ***/
    /**********************************************************************************************/

    function test_swapExactIn_pausedCreditToCollateral() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_COLLATERAL();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        creditToken.mint(swapper, 100e18);
        vm.prank(swapper);
        creditToken.approve(address(groveBasin), 100e18);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactOut_pausedCreditToCollateral() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_COLLATERAL();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        creditToken.mint(swapper, 200e18);
        vm.prank(swapper);
        creditToken.approve(address(groveBasin), 200e18);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(creditToken), address(collateralToken), 50e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_pausedCreditToSwap() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_SWAP();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        creditToken.mint(swapper, 100e18);
        vm.prank(swapper);
        creditToken.approve(address(groveBasin), 100e18);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactOut_pausedCreditToSwap() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_SWAP();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        creditToken.mint(swapper, 200e18);
        vm.prank(swapper);
        creditToken.approve(address(groveBasin), 200e18);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(creditToken), address(swapToken), 50e6, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_pausedCollateralToCredit() public {
        bytes4 key = groveBasin.PAUSED_SWAP_COLLATERAL_TO_CREDIT();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        collateralToken.mint(swapper, 100e18);
        vm.prank(swapper);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactOut_pausedCollateralToCredit() public {
        bytes4 key = groveBasin.PAUSED_SWAP_COLLATERAL_TO_CREDIT();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        collateralToken.mint(swapper, 200e18);
        vm.prank(swapper);
        collateralToken.approve(address(groveBasin), 200e18);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(collateralToken), address(creditToken), 50e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_pausedSwapToCredit() public {
        bytes4 key = groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        swapToken.mint(swapper, 100e6);
        vm.prank(swapper);
        swapToken.approve(address(groveBasin), 100e6);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_pausedSwapToCredit() public {
        bytes4 key = groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        swapToken.mint(swapper, 200e6);
        vm.prank(swapper);
        swapToken.approve(address(groveBasin), 200e6);

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 50e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_directionPauseDoesNotAffectOtherDirection() public {
        bytes4 key = groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        // credit -> swap should still work
        creditToken.mint(swapper, 100e18);
        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 100e18);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 100e18, 0, receiver, 0);
        vm.stopPrank();
    }

    function test_swapExactOut_directionPauseDoesNotAffectOtherDirection() public {
        bytes4 key = groveBasin.PAUSED_SWAP_CREDIT_TO_SWAP();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        // swap -> credit should still work
        swapToken.mint(swapper, 100e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
        vm.stopPrank();
    }

    function test_swapExactIn_unpausedDirection() public {
        bytes4 key = groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT();

        vm.prank(pauser);
        groveBasin.setPaused(key, true);

        vm.prank(owner);
        groveBasin.setUnpaused(key);

        swapToken.mint(swapper, 100e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Swap unpaused success tests                                                            ***/
    /**********************************************************************************************/

    function test_swapExactIn_unpaused() public {
        bytes4 sig = groveBasin.swapExactIn.selector;

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        vm.prank(owner);
        groveBasin.setUnpaused(sig);

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
        vm.prank(pauser);
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

        vm.prank(pauser);
        groveBasin.setPaused(sig, true);

        vm.prank(owner);
        groveBasin.setUnpaused(sig);

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
        vm.prank(pauser);
        groveBasin.setPaused(groveBasin.initiateRedeem.selector, true);

        address redeemer = makeAddr("redeemer");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.initiateRedeem(makeAddr("redeemerContract"), 100e18);
    }

    /**********************************************************************************************/
    /*** CompleteRedeem pause enforcement tests                                                 ***/
    /**********************************************************************************************/

    function test_completeRedeem_paused() public {
        vm.prank(pauser);
        groveBasin.setPaused(groveBasin.completeRedeem.selector, true);

        address redeemer = makeAddr("redeemer");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.completeRedeem(bytes32(uint256(1)));
    }

    function test_completeRedeem_globalPaused() public {
        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0), true);

        address redeemer = makeAddr("redeemer");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.completeRedeem(bytes32(uint256(1)));
    }

    /**********************************************************************************************/
    /*** PAUSER_ROLE revoke MANAGER_ROLE and REDEEMER_ROLE tests                                ***/
    /**********************************************************************************************/

    function test_pauser_revokeManagerRole() public {
        bytes32 managerRole = groveBasin.MANAGER_ROLE();
        assertTrue(groveBasin.hasRole(managerRole, manager));

        vm.prank(pauser);
        groveBasin.revokeRole(managerRole, manager);

        assertFalse(groveBasin.hasRole(managerRole, manager));
    }

    function test_pauser_revokeRedeemerRole() public {
        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        address redeemer = makeAddr("redeemer");
        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);
        assertTrue(groveBasin.hasRole(redeemerRole, redeemer));

        vm.prank(pauser);
        groveBasin.revokeRole(redeemerRole, redeemer);

        assertFalse(groveBasin.hasRole(redeemerRole, redeemer));
    }

    function test_pauser_cannotGrantManagerRole() public {
        bytes32 managerRole = groveBasin.MANAGER_ROLE();
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        address newManager = makeAddr("newManager");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                pauser,
                managerAdminRole
            )
        );
        vm.prank(pauser);
        groveBasin.grantRole(managerRole, newManager);
    }

    function test_pauser_cannotGrantRedeemerRole() public {
        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        address newRedeemer = makeAddr("newRedeemer");

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                pauser,
                managerAdminRole
            )
        );
        vm.prank(pauser);
        groveBasin.grantRole(redeemerRole, newRedeemer);
    }

    function test_pauser_cannotRevokeOtherRoles() public {
        bytes32 redeemerContractRole = groveBasin.REDEEMER_CONTRACT_ROLE();
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                pauser,
                managerAdminRole
            )
        );
        vm.prank(pauser);
        groveBasin.revokeRole(redeemerContractRole, makeAddr("someone"));
    }

    /**********************************************************************************************/
    /*** PAUSER_ROLE admin tests                                                                ***/
    /**********************************************************************************************/

    function test_pauserRole_adminIsManagerAdmin() public {
        assertEq(groveBasin.getRoleAdmin(groveBasin.PAUSER_ROLE()), groveBasin.MANAGER_ADMIN_ROLE());
    }

    function test_managerAdmin_grantPauserRole() public {
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        bytes32 pauserRole = groveBasin.PAUSER_ROLE();
        address managerAdmin = makeAddr("managerAdmin");

        vm.prank(owner);
        groveBasin.grantRole(managerAdminRole, managerAdmin);

        address newPauser = makeAddr("newPauser");
        vm.prank(managerAdmin);
        groveBasin.grantRole(pauserRole, newPauser);

        assertTrue(groveBasin.hasRole(pauserRole, newPauser));
    }

    function test_managerAdmin_revokePauserRole() public {
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        bytes32 pauserRole = groveBasin.PAUSER_ROLE();
        address managerAdmin = makeAddr("managerAdmin");

        vm.prank(owner);
        groveBasin.grantRole(managerAdminRole, managerAdmin);

        vm.prank(managerAdmin);
        groveBasin.revokeRole(pauserRole, pauser);

        assertFalse(groveBasin.hasRole(pauserRole, pauser));
    }

    /**********************************************************************************************/
    /*** Withdraw credit pause enforcement tests                                                ***/
    /**********************************************************************************************/

    function _depositForWithdrawCreditUser() internal {
        _deposit(address(swapToken),       swapper, 100e6);
        _deposit(address(collateralToken), swapper, 100e18);
        _deposit(address(creditToken),     swapper, 100e18);
    }

    function _pauseWithdrawCredit() internal {
        bytes4 key = groveBasin.PAUSED_WITHDRAW_CREDIT();
        vm.prank(pauser);
        groveBasin.setPaused(key, true);
    }

    function test_withdraw_creditToken_paused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        vm.prank(swapper);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.withdraw(address(creditToken), receiver, 100e18);
    }

    function test_previewWithdraw_creditToken_paused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.previewWithdraw(address(creditToken), 100e18);
    }

    function test_previewWithdraw_swapToken_whenCreditWithdrawPaused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        vm.prank(swapper);
        ( uint256 sharesToBurn, uint256 assetsWithdrawn ) = groveBasin.previewWithdraw(address(swapToken), 100e6);
        assertGt(sharesToBurn, 0);
        assertGt(assetsWithdrawn, 0);
    }

    function test_previewWithdraw_collateralToken_whenCreditWithdrawPaused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        vm.prank(swapper);
        ( uint256 sharesToBurn, uint256 assetsWithdrawn ) = groveBasin.previewWithdraw(address(collateralToken), 100e18);
        assertGt(sharesToBurn, 0);
        assertGt(assetsWithdrawn, 0);
    }

    function test_withdraw_swapToken_whenCreditWithdrawPaused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        vm.prank(swapper);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver, 100e6);
        assertGt(amount, 0);
    }

    function test_withdraw_collateralToken_whenCreditWithdrawPaused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        vm.prank(swapper);
        uint256 amount = groveBasin.withdraw(address(collateralToken), receiver, 100e18);
        assertGt(amount, 0);
    }

    function test_withdraw_creditToken_unpaused() public {
        _depositForWithdrawCreditUser();
        _pauseWithdrawCredit();

        bytes4 key = groveBasin.PAUSED_WITHDRAW_CREDIT();
        vm.prank(owner);
        groveBasin.setUnpaused(key);

        vm.prank(swapper);
        uint256 amount = groveBasin.withdraw(address(creditToken), receiver, 100e18);
        assertGt(amount, 0);
    }

}
