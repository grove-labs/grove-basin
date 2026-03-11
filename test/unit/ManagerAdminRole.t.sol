// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockRateProvider }  from "test/mocks/MockRateProvider.sol";

contract GroveBasinManagerAdminRoleTests is GroveBasinTestBase {

    address managerAdmin = makeAddr("managerAdmin");
    address manager      = makeAddr("manager");

    bytes32 managerAdminRole;
    bytes32 managerRole;

    function setUp() public override {
        super.setUp();
        managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        managerRole      = groveBasin.MANAGER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(managerAdminRole, managerAdmin);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can set rate providers                                              ***/
    /**********************************************************************************************/

    function test_managerAdmin_setRateProvider() public {
        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(1e27);

        vm.prank(managerAdmin);
        groveBasin.setRateProvider(address(swapToken), address(newProvider));

        assertEq(groveBasin.swapTokenRateProvider(), address(newProvider));
    }

    function test_unauthorized_setRateProvider() public {
        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(1e27);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.setRateProvider(address(swapToken), address(newProvider));
    }

    function test_manager_cannotSetRateProvider() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(1e27);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        groveBasin.setRateProvider(address(swapToken), address(newProvider));
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can set credit token deposits disabled                              ***/
    /**********************************************************************************************/

    function test_managerAdmin_setCreditTokenDepositsDisabled() public {
        vm.prank(managerAdmin);
        groveBasin.setCreditTokenDepositsDisabled(true);

        assertTrue(groveBasin.creditTokenDepositsDisabled());
    }

    function test_unauthorized_setCreditTokenDepositsDisabled() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.setCreditTokenDepositsDisabled(true);
    }

    function test_manager_cannotSetCreditTokenDepositsDisabled() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        groveBasin.setCreditTokenDepositsDisabled(true);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can set fee bounds                                                  ***/
    /**********************************************************************************************/

    function test_managerAdmin_setFeeBounds() public {
        vm.prank(managerAdmin);
        groveBasin.setFeeBounds(0, 500);

        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 500);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can set max swap size                                               ***/
    /**********************************************************************************************/

    function test_managerAdmin_setMaxSwapSize() public {
        vm.prank(managerAdmin);
        groveBasin.setMaxSwapSize(1_000_000e18);

        assertEq(groveBasin.maxSwapSize(), 1_000_000e18);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can set pocket                                                      ***/
    /**********************************************************************************************/

    function test_managerAdmin_setPocket() public {
        address newPocket = address(new MockRateProvider());

        vm.prank(managerAdmin);
        groveBasin.setPocket(newPocket);

        assertEq(groveBasin.pocket(), newPocket);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can grant/revoke MANAGER_ROLE                                       ***/
    /**********************************************************************************************/

    function test_managerAdmin_grantManagerRole() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        assertTrue(groveBasin.hasRole(managerRole, manager));
    }

    function test_managerAdmin_revokeManagerRole() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(managerAdmin);
        groveBasin.revokeRole(managerRole, manager);

        assertFalse(groveBasin.hasRole(managerRole, manager));
    }

    function test_managerAdmin_managerRoleAdmin() public {
        assertEq(groveBasin.getRoleAdmin(managerRole), managerAdminRole);
    }

    /**********************************************************************************************/
    /*** LIQUIDITY_PROVIDER_ROLE is admin-only (DEFAULT_ADMIN_ROLE)                             ***/
    /**********************************************************************************************/

    function test_managerAdmin_cannotGrantLiquidityProviderRole() public {
        address lp = makeAddr("lp");
        bytes32 lpRole   = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        bytes32 adminRole = groveBasin.DEFAULT_ADMIN_ROLE();

        vm.prank(managerAdmin);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                managerAdmin,
                adminRole
            )
        );
        groveBasin.grantRole(lpRole, lp);
    }

    function test_liquidityProviderRoleAdmin() public {
        bytes32 lpRole   = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        bytes32 adminRole = groveBasin.DEFAULT_ADMIN_ROLE();
        assertEq(groveBasin.getRoleAdmin(lpRole), adminRole);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE can set staleness threshold bounds                                  ***/
    /**********************************************************************************************/

    function test_managerAdmin_setStalenessThresholdBounds() public {
        vm.prank(managerAdmin);
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);

        assertEq(groveBasin.minStalenessThreshold(), 1 minutes);
        assertEq(groveBasin.maxStalenessThreshold(), 24 hours);
    }

    /**********************************************************************************************/
    /*** MANAGER_ROLE can set staleness threshold                                               ***/
    /**********************************************************************************************/

    function test_manager_setStalenessThreshold() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 hours);

        assertEq(groveBasin.stalenessThreshold(), 1 hours);
    }

    function test_managerAdmin_cannotSetStalenessThreshold() public {
        vm.prank(managerAdmin);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                managerAdmin,
                managerRole
            )
        );
        groveBasin.setStalenessThreshold(1 hours);
    }

    /**********************************************************************************************/
    /*** DEFAULT_ADMIN_ROLE retains access                                                      ***/
    /**********************************************************************************************/

    function test_admin_setFeeBounds() public {
        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);

        assertEq(groveBasin.maxFee(), 500);
    }

    function test_admin_setMaxSwapSize() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(2_000_000e18);

        assertEq(groveBasin.maxSwapSize(), 2_000_000e18);
    }

    function test_admin_setPocket() public {
        address newPocket = address(new MockRateProvider());

        vm.prank(owner);
        groveBasin.setPocket(newPocket);

        assertEq(groveBasin.pocket(), newPocket);
    }

    function test_admin_setStalenessThresholdBounds() public {
        vm.prank(owner);
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);

        assertEq(groveBasin.minStalenessThreshold(), 1 minutes);
        assertEq(groveBasin.maxStalenessThreshold(), 24 hours);
    }

    /**********************************************************************************************/
    /*** MANAGER_ADMIN_ROLE cannot do admin-only things                                         ***/
    /**********************************************************************************************/

    function test_managerAdmin_cannotGrantAdminRole() public {
        address other = makeAddr("other");
        bytes32 adminRole = groveBasin.DEFAULT_ADMIN_ROLE();
        vm.prank(managerAdmin);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                managerAdmin,
                adminRole
            )
        );
        groveBasin.grantRole(adminRole, other);
    }

    function test_managerAdmin_cannotGrantManagerAdminRole() public {
        address other = makeAddr("other");
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                managerAdmin,
                groveBasin.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerAdminRole, other);
    }

    /**********************************************************************************************/
    /*** Unauthorized accounts cannot use MANAGER_ADMIN_ROLE functions                          ***/
    /**********************************************************************************************/

    function test_unauthorized_setFeeBounds() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.setFeeBounds(0, 100);
    }

    function test_unauthorized_setMaxSwapSize() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.setMaxSwapSize(1e18);
    }

    function test_unauthorized_setPocket() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.setPocket(address(1));
    }

    function test_manager_cannotSetFeeBounds() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        groveBasin.setFeeBounds(0, 100);
    }

    function test_manager_cannotSetMaxSwapSize() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        groveBasin.setMaxSwapSize(1e18);
    }

    function test_manager_cannotSetPocket() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        groveBasin.setPocket(address(1));
    }

    function test_unauthorized_setStalenessThresholdBounds() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);
    }

    function test_manager_cannotSetStalenessThresholdBounds() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                managerAdminRole
            )
        );
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);
    }

    function test_unauthorized_setStalenessThreshold() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerRole
            )
        );
        groveBasin.setStalenessThreshold(1 hours);
    }

    /**********************************************************************************************/
    /*** End-to-end: MANAGER_ADMIN_ROLE grants MANAGER_ROLE, manager sets fees                  ***/
    /**********************************************************************************************/

    function test_endToEnd_managerAdminGrantsManagerAndManagerSetsFees() public {
        vm.prank(managerAdmin);
        groveBasin.setFeeBounds(0, 500);

        vm.prank(managerAdmin);
        groveBasin.grantRole(managerRole, manager);

        vm.startPrank(manager);
        groveBasin.setPurchaseFee(100);
        groveBasin.setRedemptionFee(200);
        vm.stopPrank();

        assertEq(groveBasin.purchaseFee(),   100);
        assertEq(groveBasin.redemptionFee(), 200);
    }

}
