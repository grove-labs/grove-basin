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
        groveBasin.setPaused("swapToCredit", true);
    }

    function test_setPaused_invalidAction() public {
        vm.expectRevert(IGroveBasin.InvalidAction.selector);
        vm.prank(manager);
        groveBasin.setPaused("invalidAction", true);
    }

    /**********************************************************************************************/
    /*** setPaused flag tests                                                                   ***/
    /**********************************************************************************************/

    function test_setPaused_swapToCredit() public {
        assertEq(groveBasin.pausedSwapToCredit(), false);

        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", true);

        assertEq(groveBasin.pausedSwapToCredit(), true);

        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", false);

        assertEq(groveBasin.pausedSwapToCredit(), false);
    }

    function test_setPaused_creditToSwap() public {
        assertEq(groveBasin.pausedCreditToSwap(), false);

        vm.prank(manager);
        groveBasin.setPaused("creditToSwap", true);

        assertEq(groveBasin.pausedCreditToSwap(), true);
    }

    function test_setPaused_collateralToCredit() public {
        assertEq(groveBasin.pausedCollateralToCredit(), false);

        vm.prank(manager);
        groveBasin.setPaused("collateralToCredit", true);

        assertEq(groveBasin.pausedCollateralToCredit(), true);
    }

    function test_setPaused_creditToCollateral() public {
        assertEq(groveBasin.pausedCreditToCollateral(), false);

        vm.prank(manager);
        groveBasin.setPaused("creditToCollateral", true);

        assertEq(groveBasin.pausedCreditToCollateral(), true);
    }

    function test_setPaused_deposits() public {
        assertEq(groveBasin.pausedDeposits(), false);

        vm.prank(manager);
        groveBasin.setPaused("deposits", true);

        assertEq(groveBasin.pausedDeposits(), true);
    }

    function test_setPaused_initiateRedeem() public {
        assertEq(groveBasin.pausedInitiateRedeem(), false);

        vm.prank(manager);
        groveBasin.setPaused("initiateRedeem", true);

        assertEq(groveBasin.pausedInitiateRedeem(), true);
    }

    /**********************************************************************************************/
    /*** Event tests                                                                            ***/
    /**********************************************************************************************/

    function test_setPaused_event() public {
        vm.expectEmit(true, false, false, true);
        emit IGroveBasin.PausedSet("swapToCredit", true);

        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", true);
    }

    /**********************************************************************************************/
    /*** Swap pause enforcement tests                                                           ***/
    /**********************************************************************************************/

    function test_swapExactIn_pausedSwapToCredit() public {
        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_pausedSwapToCredit() public {
        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_pausedCreditToSwap() public {
        vm.prank(manager);
        groveBasin.setPaused("creditToSwap", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactOut_pausedCreditToSwap() public {
        vm.prank(manager);
        groveBasin.setPaused("creditToSwap", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactOut(address(creditToken), address(swapToken), 100e6, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_pausedCollateralToCredit() public {
        vm.prank(manager);
        groveBasin.setPaused("collateralToCredit", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactOut_pausedCollateralToCredit() public {
        vm.prank(manager);
        groveBasin.setPaused("collateralToCredit", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactOut(address(collateralToken), address(creditToken), 80e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactIn_pausedCreditToCollateral() public {
        vm.prank(manager);
        groveBasin.setPaused("creditToCollateral", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactOut_pausedCreditToCollateral() public {
        vm.prank(manager);
        groveBasin.setPaused("creditToCollateral", true);

        vm.expectRevert(IGroveBasin.RoutePaused.selector);
        groveBasin.swapExactOut(address(creditToken), address(collateralToken), 100e18, type(uint256).max, receiver, 0);
    }

    /**********************************************************************************************/
    /*** Swap unpaused success tests                                                            ***/
    /**********************************************************************************************/

    function test_swapExactIn_swapToCreditUnpaused() public {
        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", true);

        vm.prank(manager);
        groveBasin.setPaused("swapToCredit", false);

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
        groveBasin.setPaused("deposits", true);

        address user = groveBasin.liquidityProvider();

        swapToken.mint(user, 100e6);
        vm.startPrank(user);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert(IGroveBasin.DepositsPaused.selector);
        groveBasin.deposit(address(swapToken), user, 100e6);
        vm.stopPrank();
    }

    function test_deposit_unpaused() public {
        vm.prank(manager);
        groveBasin.setPaused("deposits", true);

        vm.prank(manager);
        groveBasin.setPaused("deposits", false);

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
        groveBasin.setPaused("initiateRedeem", true);

        address redeemer = makeAddr("redeemer");

        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(redeemerRole, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(IGroveBasin.InitiateRedeemPaused.selector);
        groveBasin.initiateRedeem(makeAddr("redeemerContract"), 100e18);
    }

}
