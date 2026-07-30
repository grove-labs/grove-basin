// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract SwapAllowlistTestBase is GroveBasinTestBase {

    address public manager  = makeAddr("manager");
    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        _deposit(address(swapToken),       makeAddr("seeder"), 1_000e6);
        _deposit(address(collateralToken), makeAddr("seeder"), 1_000e18);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000e18);

        swapToken.mint(swapper, 1_000e6);
        creditToken.mint(swapper, 1_000e18);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin),   type(uint256).max);
        creditToken.approve(address(groveBasin), type(uint256).max);
        vm.stopPrank();
    }

    function _routeKey(address assetIn, address assetOut) internal view returns (bytes32) {
        return groveBasin.getSwapRouteKey(assetIn, assetOut);
    }

    function _allow(address assetIn, address assetOut, address caller) internal {
        bytes32 routeKey = _routeKey(assetIn, assetOut);

        vm.prank(manager);
        groveBasin.addToSwapAllowlist(routeKey, caller);
    }

    function _gateRoute(address assetIn, address assetOut) internal {
        bytes32 routeKey = _routeKey(assetIn, assetOut);

        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(routeKey, true);
    }

    function _gateGlobally() internal {
        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(bytes32(0), true);
    }

}

contract SwapAllowlistAccessControlTests is SwapAllowlistTestBase {

    function test_setSwapAllowlistEnabled_notManagerAdmin() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.setSwapAllowlistEnabled(routeKey, true);
    }

    function test_setSwapAllowlistEnabled_globalNotManagerAdmin() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.setSwapAllowlistEnabled(bytes32(0), true);
    }

    function test_addToSwapAllowlist_notManager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                swapper,
                groveBasin.MANAGER_ROLE()
            )
        );
        vm.prank(swapper);
        groveBasin.addToSwapAllowlist(routeKey, swapper);
    }

    function test_removeFromSwapAllowlist_notManager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _allow(address(swapToken), address(creditToken), swapper);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                swapper,
                groveBasin.MANAGER_ROLE()
            )
        );
        vm.prank(swapper);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);
    }

    function test_removeFromSwapAllowlist_manager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(manager);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), false);
    }

}

contract SwapAllowlistRouteKeyTests is SwapAllowlistTestBase {

    function test_getSwapRouteKey() public view {
        assertEq(
            groveBasin.getSwapRouteKey(address(swapToken), address(creditToken)),
            keccak256(abi.encode(address(swapToken), address(creditToken)))
        );
    }

    function test_getSwapRouteKey_isUnidirectional() public view {
        assertTrue(
            groveBasin.getSwapRouteKey(address(swapToken), address(creditToken)) !=
            groveBasin.getSwapRouteKey(address(creditToken), address(swapToken))
        );
    }

    function test_getSwapRouteKey_isNeverZero() public view {
        assertTrue(groveBasin.getSwapRouteKey(address(0), address(0)) != bytes32(0));
    }

    /// @dev Route keys are unvalidated, matching the pause keys. Gating an unreachable route has
    ///      no effect on the routes that can actually be swapped.
    function test_setSwapAllowlistEnabled_arbitraryKeyIsInert() public {
        bytes32 unreachableRoute = _routeKey(address(swapToken), address(collateralToken));

        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(unreachableRoute, true);

        assertEq(groveBasin.swapAllowlistEnabled(unreachableRoute), true);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

}

contract SwapAllowlistConfigTests is SwapAllowlistTestBase {

    function test_setSwapAllowlistEnabled_global() public {
        assertEq(groveBasin.swapAllowlistEnabled(bytes32(0)), false);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(bytes32(0), true);
        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(bytes32(0), true);

        assertEq(groveBasin.swapAllowlistEnabled(bytes32(0)), true);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(bytes32(0), false);
        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(bytes32(0), false);

        assertEq(groveBasin.swapAllowlistEnabled(bytes32(0)), false);
    }

    function test_setSwapAllowlistEnabled_route() public {
        bytes32 routeKey = _routeKey(address(creditToken), address(swapToken));

        assertEq(groveBasin.swapAllowlistEnabled(routeKey), false);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(routeKey, true);
        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(routeKey, true);

        assertEq(groveBasin.swapAllowlistEnabled(routeKey), true);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(routeKey, false);
        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(routeKey, false);

        assertEq(groveBasin.swapAllowlistEnabled(routeKey), false);
    }

    function test_setSwapAllowlistEnabled_isUnidirectional() public {
        _gateRoute(address(creditToken), address(swapToken));

        assertEq(groveBasin.swapAllowlistEnabled(_routeKey(address(creditToken), address(swapToken))), true);
        assertEq(groveBasin.swapAllowlistEnabled(_routeKey(address(swapToken), address(creditToken))), false);
    }

    function test_setSwapAllowlistEnabled_globalDoesNotSetRouteKeys() public {
        _gateGlobally();

        assertEq(groveBasin.swapAllowlistEnabled(_routeKey(address(swapToken), address(creditToken))), false);
    }

    function test_addToSwapAllowlist() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), false);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistSet(routeKey, swapper, true);
        vm.prank(manager);
        groveBasin.addToSwapAllowlist(routeKey, swapper);

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), true);
    }

    function test_addToSwapAllowlist_isUnidirectional() public {
        _allow(address(swapToken), address(creditToken), swapper);

        assertEq(groveBasin.swapAllowlist(_routeKey(address(swapToken), address(creditToken)), swapper), true);
        assertEq(groveBasin.swapAllowlist(_routeKey(address(creditToken), address(swapToken)), swapper), false);
    }

    function test_removeFromSwapAllowlist() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _allow(address(swapToken), address(creditToken), swapper);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistSet(routeKey, swapper, false);
        vm.prank(manager);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), false);
    }

    function test_isSwapCallerAllowlisted_ungatedRouteAllowsEveryone() public view {
        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), true);
    }

    function test_isSwapCallerAllowlisted_gatedRoute() public {
        _gateRoute(address(swapToken), address(creditToken));

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), false);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), true);

        _allow(address(swapToken), address(creditToken), swapper);

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), true);
    }

    function test_isSwapCallerAllowlisted_globalKeySupersedesRouteKeys() public {
        _allow(address(swapToken), address(creditToken), swapper);

        _gateGlobally();

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), false);
    }

    /// @dev bytes32(0) is an enable flag only; entries stored under it never grant access.
    function test_isSwapCallerAllowlisted_globalKeyHoldsNoEntries() public {
        _gateGlobally();

        vm.prank(manager);
        groveBasin.addToSwapAllowlist(bytes32(0), swapper);

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), false);
    }

    function test_allowlistEntriesSurviveGateToggle() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(owner);
        groveBasin.setSwapAllowlistEnabled(routeKey, false);

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), true);

        _gateRoute(address(swapToken), address(creditToken));

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), true);
    }

}

contract SwapAllowlistEnforcementTests is SwapAllowlistTestBase {

    function test_swapExactIn_ungatedRoute() public {
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        assertEq(creditToken.balanceOf(receiver), 80e18);
    }

    function test_swapExactIn_gatedRoute_notAllowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactIn_gatedRoute_allowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        assertEq(creditToken.balanceOf(receiver), 80e18);
    }

    function test_swapExactIn_gatedRoute_reverseRouteStaysOpen() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.prank(swapper);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);

        assertEq(swapToken.balanceOf(receiver), 100e6);
    }

    function test_swapExactIn_allowlistedOnReverseRouteOnly() public {
        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(creditToken), address(swapToken), swapper);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactIn_removedFromAllowlist() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(manager);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactIn_globalKeyGatesEveryRoute() public {
        _gateGlobally();

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);
    }

    function test_swapExactIn_globalKeyWithRouteAllowlistEntry() public {
        _allow(address(swapToken), address(creditToken), swapper);

        _gateGlobally();

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);
    }

    function test_swapExactIn_globalKeyDisabledLeavesRouteKeyActive() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.startPrank(owner);
        groveBasin.setSwapAllowlistEnabled(bytes32(0), true);
        groveBasin.setSwapAllowlistEnabled(bytes32(0), false);
        vm.stopPrank();

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_gatedRoute_notAllowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, type(uint256).max, receiver, 0);
    }

    function test_swapExactOut_gatedRoute_allowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(swapper);
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, type(uint256).max, receiver, 0);

        assertEq(creditToken.balanceOf(receiver), 80e18);
    }

    function test_allowlistIsPerCaller() public {
        address otherSwapper = makeAddr("otherSwapper");

        swapToken.mint(otherSwapper, 100e6);

        vm.prank(otherSwapper);
        swapToken.approve(address(groveBasin), type(uint256).max);

        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(otherSwapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    /// @dev The allowlist gates the caller, not the receiver.
    function test_allowlistedCallerCanSwapToAnyReceiver() public {
        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, makeAddr("unlistedReceiver"), 0);

        assertEq(creditToken.balanceOf(makeAddr("unlistedReceiver")), 80e18);
    }

}

contract SwapAllowlistPreviewTests is SwapAllowlistTestBase {

    function test_previewSwapExactIn_gatedRoute_notAllowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6);
    }

    function test_previewSwapExactIn_gatedRoute_allowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6), 80e18);
    }

    function test_previewSwapExactOut_gatedRoute_notAllowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);
    }

    function test_previewSwapExactOut_gatedRoute_allowlisted() public {
        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18), 100e6);
    }

    function test_previewSwapExactIn_reverseRouteStaysOpen() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 80e18), 100e6);
    }

}

contract SwapAllowlistGlobalEnabledTests is SwapAllowlistTestBase {

    function setUp() public override {
        super.setUp();

        _gateGlobally();
    }

    function test_deposit_notGatedByAllowlist() public {
        _deposit(address(swapToken), makeAddr("depositor"), 100e6);

        assertEq(groveBasin.shares(makeAddr("depositor")), 100e18);
    }

    function test_withdraw_notGatedByAllowlist() public {
        _deposit(address(swapToken), makeAddr("withdrawer"), 100e6);

        vm.prank(makeAddr("withdrawer"));
        groveBasin.withdraw(address(swapToken), receiver, 100e6);

        assertEq(swapToken.balanceOf(receiver), 100e6);
    }

}
