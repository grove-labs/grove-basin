// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract SwapAllowlistTestBase is GroveBasinTestBase {

    address public manager          = makeAddr("manager");
    address public allowlistManager = makeAddr("allowlistManager");
    address public swapper          = makeAddr("swapper");
    address public receiver         = makeAddr("receiver");

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),           manager);
        groveBasin.grantRole(groveBasin.ALLOWLIST_MANAGER_ROLE(), allowlistManager);
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

        vm.prank(allowlistManager);
        groveBasin.addToSwapAllowlist(routeKey, caller);
    }

    function _allowGlobally(address caller) internal {
        bytes32 globalRouteKey = groveBasin.GLOBAL_ROUTE_KEY();

        vm.prank(allowlistManager);
        groveBasin.addToSwapAllowlist(globalRouteKey, caller);
    }

    function _gateRoute(address assetIn, address assetOut) internal {
        vm.prank(owner);
        groveBasin.setSwapAllowlist(assetIn, assetOut, true);
    }

    function _gateGlobally() internal {
        vm.prank(owner);
        groveBasin.setGlobalSwapAllowlist(true);
    }

    function _fundAllAssets(address caller) internal {
        swapToken.mint(caller,       1_000e6);
        collateralToken.mint(caller, 1_000e18);
        creditToken.mint(caller,     1_000e18);

        vm.startPrank(caller);
        swapToken.approve(address(groveBasin),       type(uint256).max);
        collateralToken.approve(address(groveBasin), type(uint256).max);
        creditToken.approve(address(groveBasin),     type(uint256).max);
        vm.stopPrank();
    }

}

contract SwapAllowlistAccessControlTests is SwapAllowlistTestBase {

    function test_setSwapAllowlist_notManagerAdmin() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.setSwapAllowlist(address(swapToken), address(creditToken), true);
    }

    function test_setGlobalSwapAllowlist_notManagerAdmin() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.setGlobalSwapAllowlist(true);
    }

    function test_setSwapAllowlist_notAllowlistManager() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                allowlistManager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(allowlistManager);
        groveBasin.setSwapAllowlist(address(swapToken), address(creditToken), true);
    }

    function test_setGlobalSwapAllowlist_notAllowlistManager() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                allowlistManager,
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        vm.prank(allowlistManager);
        groveBasin.setGlobalSwapAllowlist(true);
    }

    function test_addToSwapAllowlist_notAllowlistManager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                swapper,
                groveBasin.ALLOWLIST_MANAGER_ROLE()
            )
        );
        vm.prank(swapper);
        groveBasin.addToSwapAllowlist(routeKey, swapper);
    }

    function test_addToSwapAllowlist_manager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.ALLOWLIST_MANAGER_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.addToSwapAllowlist(routeKey, swapper);
    }

    function test_removeFromSwapAllowlist_notAllowlistManager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _allow(address(swapToken), address(creditToken), swapper);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                swapper,
                groveBasin.ALLOWLIST_MANAGER_ROLE()
            )
        );
        vm.prank(swapper);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);
    }

    function test_removeFromSwapAllowlist_manager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _allow(address(swapToken), address(creditToken), swapper);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                groveBasin.ALLOWLIST_MANAGER_ROLE()
            )
        );
        vm.prank(manager);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);
    }

    function test_removeFromSwapAllowlist_allowlistManager() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(allowlistManager);
        groveBasin.removeFromSwapAllowlist(routeKey, swapper);

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), false);
    }

}

contract SwapAllowlistManagerRoleTests is SwapAllowlistTestBase {

    address public managerAdmin = makeAddr("managerAdmin");
    address public pauser       = makeAddr("pauser");

    bytes32 public allowlistManagerRole;
    bytes32 public managerAdminRole;

    function setUp() public override {
        super.setUp();

        allowlistManagerRole = groveBasin.ALLOWLIST_MANAGER_ROLE();
        managerAdminRole     = groveBasin.MANAGER_ADMIN_ROLE();

        vm.startPrank(owner);
        groveBasin.grantRole(managerAdminRole,         managerAdmin);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    function test_allowlistManagerRole_adminIsManagerAdmin() public view {
        assertEq(groveBasin.getRoleAdmin(allowlistManagerRole), managerAdminRole);
    }

    function test_allowlistManagerRole_isDistinctFromManagerRole() public view {
        assertTrue(allowlistManagerRole != groveBasin.MANAGER_ROLE());
        assertEq(allowlistManagerRole, keccak256("ALLOWLIST_MANAGER_ROLE"));
    }

    function test_managerAdmin_grantAllowlistManagerRole() public {
        address newAllowlistManager = makeAddr("newAllowlistManager");

        vm.prank(managerAdmin);
        groveBasin.grantRole(allowlistManagerRole, newAllowlistManager);

        assertTrue(groveBasin.hasRole(allowlistManagerRole, newAllowlistManager));
    }

    function test_managerAdmin_revokeAllowlistManagerRole() public {
        vm.prank(managerAdmin);
        groveBasin.revokeRole(allowlistManagerRole, allowlistManager);

        assertFalse(groveBasin.hasRole(allowlistManagerRole, allowlistManager));
    }

    function test_manager_cannotGrantAllowlistManagerRole() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        vm.prank(manager);
        groveBasin.grantRole(allowlistManagerRole, makeAddr("newAllowlistManager"));
    }

    function test_allowlistManager_cannotGrantAllowlistManagerRole() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                allowlistManager,
                managerAdminRole
            )
        );
        vm.prank(allowlistManager);
        groveBasin.grantRole(allowlistManagerRole, makeAddr("newAllowlistManager"));
    }

    function test_pauser_cannotGrantAllowlistManagerRole() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                pauser,
                managerAdminRole
            )
        );
        vm.prank(pauser);
        groveBasin.grantRole(allowlistManagerRole, makeAddr("newAllowlistManager"));
    }

    function test_pauser_revokeAllowlistManagerRole() public {
        vm.prank(pauser);
        groveBasin.revokeRole(allowlistManagerRole, allowlistManager);

        assertFalse(groveBasin.hasRole(allowlistManagerRole, allowlistManager));
    }

    function test_revokedAllowlistManager_cannotAddToAllowlist() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        vm.prank(managerAdmin);
        groveBasin.revokeRole(allowlistManagerRole, allowlistManager);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                allowlistManager,
                allowlistManagerRole
            )
        );
        vm.prank(allowlistManager);
        groveBasin.addToSwapAllowlist(routeKey, swapper);
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

    function test_getSwapRouteKey_isNeverGlobalRouteKey() public view {
        assertTrue(groveBasin.getSwapRouteKey(address(0), address(0)) != groveBasin.GLOBAL_ROUTE_KEY());
    }

    function test_globalRouteKey() public view {
        assertEq(groveBasin.GLOBAL_ROUTE_KEY(), bytes32(0));
    }

    /// @dev Gating a route that cannot be swapped has no effect on the routes that can.
    function test_setSwapAllowlist_unreachableRouteIsInert() public {
        bytes32 unreachableRoute = _routeKey(address(swapToken), address(collateralToken));

        vm.prank(owner);
        groveBasin.setSwapAllowlist(address(swapToken), address(collateralToken), true);

        assertEq(groveBasin.swapAllowlistEnabled(unreachableRoute), true);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_setSwapAllowlist_invalidAssetIn() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        vm.prank(owner);
        groveBasin.setSwapAllowlist(makeAddr("notAnAsset"), address(creditToken), true);
    }

    function test_setSwapAllowlist_invalidAssetOut() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        vm.prank(owner);
        groveBasin.setSwapAllowlist(address(swapToken), makeAddr("notAnAsset"), true);
    }

}

contract SwapAllowlistConfigTests is SwapAllowlistTestBase {

    function test_setGlobalSwapAllowlist() public {
        bytes32 globalRouteKey = groveBasin.GLOBAL_ROUTE_KEY();

        assertEq(groveBasin.swapAllowlistEnabled(globalRouteKey), false);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(globalRouteKey, true);
        vm.prank(owner);
        groveBasin.setGlobalSwapAllowlist(true);

        assertEq(groveBasin.swapAllowlistEnabled(globalRouteKey), true);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(globalRouteKey, false);
        vm.prank(owner);
        groveBasin.setGlobalSwapAllowlist(false);

        assertEq(groveBasin.swapAllowlistEnabled(globalRouteKey), false);
    }

    function test_setSwapAllowlist_route() public {
        bytes32 routeKey = _routeKey(address(creditToken), address(swapToken));

        assertEq(groveBasin.swapAllowlistEnabled(routeKey), false);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(routeKey, true);
        vm.prank(owner);
        groveBasin.setSwapAllowlist(address(creditToken), address(swapToken), true);

        assertEq(groveBasin.swapAllowlistEnabled(routeKey), true);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistEnabledSet(routeKey, false);
        vm.prank(owner);
        groveBasin.setSwapAllowlist(address(creditToken), address(swapToken), false);

        assertEq(groveBasin.swapAllowlistEnabled(routeKey), false);
    }

    function test_setSwapAllowlist_isUnidirectional() public {
        _gateRoute(address(creditToken), address(swapToken));

        assertEq(groveBasin.swapAllowlistEnabled(_routeKey(address(creditToken), address(swapToken))), true);
        assertEq(groveBasin.swapAllowlistEnabled(_routeKey(address(swapToken), address(creditToken))), false);
    }

    function test_setGlobalSwapAllowlist_doesNotSetRouteKeys() public {
        _gateGlobally();

        assertEq(groveBasin.swapAllowlistEnabled(_routeKey(address(swapToken), address(creditToken))), false);
    }

    function test_addToSwapAllowlist() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        assertEq(groveBasin.swapAllowlist(routeKey, swapper), false);

        vm.expectEmit(address(groveBasin));
        emit IGroveBasin.SwapAllowlistSet(routeKey, swapper, true);
        vm.prank(allowlistManager);
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
        vm.prank(allowlistManager);
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

    function test_isSwapCallerAllowlisted_globalKeyGatesRoutesWithoutOwnGate() public {
        _gateGlobally();

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), false);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), false);

        _allowGlobally(swapper);

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), true);
    }

    /// @dev A route with its own gate reads only its own entries, so the global set can neither
    ///      widen nor narrow it.
    function test_isSwapCallerAllowlisted_routeKeySupersedesGlobalKey() public {
        _gateGlobally();
        _allowGlobally(swapper);

        _gateRoute(address(creditToken), address(swapToken));

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), false);

        _allow(address(creditToken), address(swapToken), swapper);

        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken), swapper), true);
    }

    /// @dev Route entries stay dormant until the route is gated, so the global set governs a route
    ///      that only the global gate covers.
    function test_isSwapCallerAllowlisted_routeEntryDormantUnderGlobalGateOnly() public {
        _allow(address(swapToken), address(creditToken), swapper);

        _gateGlobally();

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), false);
    }

    /// @dev Global entries never bypass a route that carries its own gate.
    function test_isSwapCallerAllowlisted_globalEntryDoesNotBypassRouteGate() public {
        _allowGlobally(swapper);

        _gateRoute(address(swapToken), address(creditToken));

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), swapper), false);
    }

    function test_allowlistEntriesSurviveGateToggle() public {
        bytes32 routeKey = _routeKey(address(swapToken), address(creditToken));

        _gateRoute(address(swapToken), address(creditToken));
        _allow(address(swapToken), address(creditToken), swapper);

        vm.prank(owner);
        groveBasin.setSwapAllowlist(address(swapToken), address(creditToken), false);

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

        vm.prank(allowlistManager);
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

    function test_swapExactIn_globalKeyWithGlobalAllowlistEntry() public {
        _gateGlobally();
        _allowGlobally(swapper);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);

        assertEq(creditToken.balanceOf(receiver), 80e18);
        assertEq(swapToken.balanceOf(receiver),   100e6);
    }

    function test_swapExactIn_globalKeyWithRouteAllowlistEntry() public {
        _allow(address(swapToken), address(creditToken), swapper);

        _gateGlobally();

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        _gateRoute(address(swapToken), address(creditToken));

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        assertEq(creditToken.balanceOf(receiver), 80e18);
    }

    function test_swapExactIn_globalKeyDisabledLeavesRouteKeyActive() public {
        _gateRoute(address(swapToken), address(creditToken));

        vm.startPrank(owner);
        groveBasin.setGlobalSwapAllowlist(true);
        groveBasin.setGlobalSwapAllowlist(false);
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

/// @dev Basin with permissionless subscriptions and every redemption route flowing through the
///      advance rate module. No global gate, so only the two redemption routes carry an allowlist.
contract SwapAllowlistOpenSubscriptionTests is SwapAllowlistTestBase {

    address public customer          = makeAddr("customer");
    address public advanceRateModule = makeAddr("advanceRateModule");

    function setUp() public override {
        super.setUp();

        _fundAllAssets(customer);
        _fundAllAssets(advanceRateModule);

        _gateRoute(address(creditToken), address(swapToken));
        _gateRoute(address(creditToken), address(collateralToken));

        _allow(address(creditToken), address(swapToken),       advanceRateModule);
        _allow(address(creditToken), address(collateralToken), advanceRateModule);
    }

    function test_swapExactIn_subscriptionsArePermissionless() public {
        vm.prank(customer);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        vm.prank(customer);
        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 100e18, 0, receiver, 0);

        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);

        assertEq(creditToken.balanceOf(receiver), 240e18);
    }

    function test_swapExactIn_redemptionsRestrictedToAdvanceRateModule() public {
        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(customer);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(customer);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 80e18, 0, receiver, 0);

        vm.prank(advanceRateModule);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);

        vm.prank(advanceRateModule);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 80e18, 0, receiver, 0);

        assertEq(swapToken.balanceOf(receiver),       100e6);
        assertEq(collateralToken.balanceOf(receiver), 100e18);
    }

}

/// @dev Basin where every subscription route serves the same customer set and every redemption
///      route flows through the advance rate module. The customer set is stored once under
///      GLOBAL_ROUTE_KEY and the two redemption routes hold only the module, so a route-specific
///      allowlist takes precedence over the global one rather than being unioned with it.
contract SwapAllowlistGlobalCustomerSetTests is SwapAllowlistTestBase {

    address public customerA         = makeAddr("customerA");
    address public customerB         = makeAddr("customerB");
    address public advanceRateModule = makeAddr("advanceRateModule");

    function setUp() public override {
        super.setUp();

        _fundAllAssets(customerA);
        _fundAllAssets(customerB);
        _fundAllAssets(advanceRateModule);

        _gateGlobally();
        _gateRoute(address(creditToken), address(swapToken));
        _gateRoute(address(creditToken), address(collateralToken));

        _allowGlobally(customerA);
        _allowGlobally(customerB);
        _allow(address(creditToken), address(swapToken),       advanceRateModule);
        _allow(address(creditToken), address(collateralToken), advanceRateModule);
    }

    function test_globalCustomerSetGatesSubscriptionRoutes() public view {
        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken),       address(creditToken), customerA), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(collateralToken), address(creditToken), customerA), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken),       address(creditToken), customerB), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(collateralToken), address(creditToken), customerB), true);

        assertEq(groveBasin.isSwapCallerAllowlisted(address(swapToken),       address(creditToken), swapper), false);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(collateralToken), address(creditToken), swapper), false);
    }

    function test_redemptionRoutesOverrideGlobalCustomerSet() public view {
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken),       advanceRateModule), true);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(collateralToken), advanceRateModule), true);

        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(swapToken),       customerA), false);
        assertEq(groveBasin.isSwapCallerAllowlisted(address(creditToken), address(collateralToken), customerA), false);
    }

    function test_swapExactIn_customerSubscribesOnEveryRoute() public {
        vm.prank(customerA);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, customerA, 0);

        vm.prank(customerB);
        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 100e18, 0, customerB, 0);

        assertEq(creditToken.balanceOf(customerA), 1_080e18);
        assertEq(creditToken.balanceOf(customerB), 1_080e18);
    }

    function test_swapExactIn_nonCustomerCannotSubscribe() public {
        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(swapper);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactIn_onlyAdvanceRateModuleRedeems() public {
        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(customerA);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, customerA, 0);

        vm.expectRevert(IGroveBasin.NotAllowlisted.selector);
        vm.prank(customerA);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 80e18, 0, customerA, 0);

        vm.prank(advanceRateModule);
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);

        vm.prank(advanceRateModule);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 80e18, 0, receiver, 0);

        assertEq(swapToken.balanceOf(receiver),       100e6);
        assertEq(collateralToken.balanceOf(receiver), 100e18);
    }

}
