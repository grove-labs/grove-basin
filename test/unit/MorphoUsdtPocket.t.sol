// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { MorphoUsdtPocket }    from "src/MorphoUsdtPocket.sol";
import { IGroveBasinPocket }   from "src/interfaces/IGroveBasinPocket.sol";
import { IERC4626VaultLike }   from "src/interfaces/IERC4626VaultLike.sol";

import { MockRateProvider }   from "test/mocks/MockRateProvider.sol";
import { MockERC4626Vault }   from "test/mocks/MockERC4626Vault.sol";

contract MorphoUsdtPocketTestBase is Test {

    address public owner   = makeAddr("owner");
    address public admin   = makeAddr("admin");
    address public manager = makeAddr("manager");

    GroveBasin          public groveBasin;
    MorphoUsdtPocket    public pocket;

    MockERC20 public usdt;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockERC4626Vault public vault;

    function setUp() public virtual {
        usdt            = new MockERC20("USDT",       "USDT",       6);
        collateralToken = new MockERC20("COLLATERAL",  "COL",        18);
        creditToken     = new MockERC20("CREDIT",      "CREDIT",     18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(usdt),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vault = new MockERC4626Vault(address(usdt));

        // Fund vault with underlying for withdrawals
        usdt.mint(address(vault), 1_000_000_000e6);

        pocket = new MorphoUsdtPocket(
            address(groveBasin),
            admin,
            address(usdt),
            address(vault)
        );

        // Grant MANAGER_ROLE to manager
        vm.startPrank(admin);
        pocket.grantRole(pocket.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract MorphoUsdtPocketConstructorTests is MorphoUsdtPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert("MorphoUsdtPocket/invalid-basin");
        new MorphoUsdtPocket(address(0), admin, address(usdt), address(vault));
    }

    function test_constructor_invalidAdmin() public {
        vm.expectRevert("MorphoUsdtPocket/invalid-admin");
        new MorphoUsdtPocket(address(groveBasin), address(0), address(usdt), address(vault));
    }

    function test_constructor_invalidUsdt() public {
        vm.expectRevert("MorphoUsdtPocket/invalid-usdt");
        new MorphoUsdtPocket(address(groveBasin), admin, address(0), address(vault));
    }

    function test_constructor_invalidVault() public {
        vm.expectRevert("MorphoUsdtPocket/invalid-vault");
        new MorphoUsdtPocket(address(groveBasin), admin, address(usdt), address(0));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(), address(groveBasin));
        assertEq(address(pocket.usdt()), address(usdt));
        assertEq(pocket.vault(), address(vault));

        assertEq(usdt.allowance(address(pocket), address(groveBasin)), type(uint256).max);
    }

    function test_constructor_grantsDefaultAdminRole() public view {
        assertTrue(pocket.hasRole(pocket.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_constructor_managerRoleDefined() public view {
        assertEq(pocket.MANAGER_ROLE(), keccak256("MANAGER_ROLE"));
    }

    function test_constructor_vaultIsImmutable() public view {
        // Vault is an immutable — verify it's set and there's no setter function.
        // Solidity immutables have no setter by design; we confirm the value is correct.
        assertEq(pocket.vault(), address(vault));
    }

}

/**********************************************************************************************/
/*** Access control tests                                                                   ***/
/**********************************************************************************************/

contract MorphoUsdtPocketAccessControlTests is MorphoUsdtPocketTestBase {

    function test_depositLiquidity_notAuthorized() public {
        vm.expectRevert("MorphoUsdtPocket/not-authorized");
        pocket.depositLiquidity(100e6, address(usdt));
    }

    function test_withdrawLiquidity_notAuthorized() public {
        vm.expectRevert("MorphoUsdtPocket/not-authorized");
        pocket.withdrawLiquidity(100e6, address(usdt));
    }

    function test_depositLiquidity_adminOnly_notAuthorized() public {
        vm.prank(admin);
        vm.expectRevert("MorphoUsdtPocket/not-authorized");
        pocket.depositLiquidity(100e6, address(usdt));
    }

    function test_withdrawLiquidity_adminOnly_notAuthorized() public {
        vm.prank(admin);
        vm.expectRevert("MorphoUsdtPocket/not-authorized");
        pocket.withdrawLiquidity(100e6, address(usdt));
    }

}

/**********************************************************************************************/
/*** depositLiquidity tests (basin caller)                                                  ***/
/**********************************************************************************************/

contract MorphoUsdtPocketDepositLiquidityTests is MorphoUsdtPocketTestBase {

    function test_depositLiquidity_zeroAmount() public {
        vm.prank(address(groveBasin));
        uint256 result = pocket.depositLiquidity(0, address(usdt));
        assertEq(result, 0);
    }

    function test_depositLiquidity_invalidAsset() public {
        vm.prank(address(groveBasin));
        vm.expectRevert("MorphoUsdtPocket/invalid-asset");
        pocket.depositLiquidity(100e6, address(collateralToken));
    }

    function test_depositLiquidity_depositsToVault() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        uint256 result = pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(result, 1000e6);
        assertEq(usdt.balanceOf(address(pocket)), 0);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);
    }

    function test_depositLiquidity_emitsEvent() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdt), 1000e6, 1000e6);
        pocket.depositLiquidity(1000e6, address(usdt));
    }

    function test_depositLiquidity_consecutiveDeposits() public {
        // Tests USDT-safe approve(0)/approve(amount) pattern
        usdt.mint(address(pocket), 2000e6);

        vm.startPrank(address(groveBasin));

        pocket.depositLiquidity(1000e6, address(usdt));
        assertEq(vault.balanceOf(address(pocket)), 1000e6);

        pocket.depositLiquidity(1000e6, address(usdt));
        assertEq(vault.balanceOf(address(pocket)), 2000e6);

        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** MANAGER_ROLE deposit/withdraw tests                                                    ***/
/**********************************************************************************************/

contract MorphoUsdtPocketManagerTests is MorphoUsdtPocketTestBase {

    function test_depositLiquidity_manager_depositsToVault() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdt), 1000e6, 1000e6);
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 0);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);
    }

    function test_withdrawLiquidity_manager_withdrawsFromVault() public {
        // First deposit to vault
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(vault.balanceOf(address(pocket)), 500e6);
    }

    function test_depositLiquidity_manager_zeroAmount() public {
        vm.prank(manager);
        uint256 result = pocket.depositLiquidity(0, address(usdt));
        assertEq(result, 0);
    }

    function test_withdrawLiquidity_manager_zeroAmount() public {
        vm.prank(manager);
        uint256 result = pocket.withdrawLiquidity(0, address(usdt));
        assertEq(result, 0);
    }

    function test_depositLiquidity_manager_consecutiveDeposits() public {
        // Tests USDT-safe approve(0)/approve(amount) pattern via manager
        usdt.mint(address(pocket), 2000e6);

        vm.startPrank(manager);

        pocket.depositLiquidity(1000e6, address(usdt));
        assertEq(vault.balanceOf(address(pocket)), 1000e6);

        pocket.depositLiquidity(1000e6, address(usdt));
        assertEq(vault.balanceOf(address(pocket)), 2000e6);

        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity tests (basin caller)                                                 ***/
/**********************************************************************************************/

contract MorphoUsdtPocketWithdrawLiquidityTests is MorphoUsdtPocketTestBase {

    function test_withdrawLiquidity_zeroAmount() public {
        vm.prank(address(groveBasin));
        uint256 result = pocket.withdrawLiquidity(0, address(usdt));
        assertEq(result, 0);
    }

    function test_withdrawLiquidity_invalidAsset() public {
        vm.prank(address(groveBasin));
        vm.expectRevert("MorphoUsdtPocket/invalid-asset");
        pocket.withdrawLiquidity(100e6, address(collateralToken));
    }

    function test_withdrawLiquidity_existingBalanceCoversAll() public {
        usdt.mint(address(pocket), 1000e6);

        // Deposit some to vault to verify vault is NOT called when balance covers
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(500e6, address(usdt));

        uint256 vaultSharesBefore = vault.balanceOf(address(pocket));

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        // Vault shares unchanged — no vault interaction needed
        assertEq(vault.balanceOf(address(pocket)), vaultSharesBefore);
        assertEq(usdt.balanceOf(address(pocket)), 500e6);
    }

    function test_withdrawLiquidity_partialBalanceWithdrawsRemainder() public {
        usdt.mint(address(pocket), 300e6);

        // Deposit 1000 to vault
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        // pocket has 300 USDT + 1000 vault shares
        assertEq(usdt.balanceOf(address(pocket)), 300e6);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        // Should withdraw 200 from vault (500 - 300 balance)
        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(vault.balanceOf(address(pocket)), 800e6);
    }

    function test_withdrawLiquidity_noBalanceWithdrawsAllFromVault() public {
        // Deposit everything to vault
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 0);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(vault.balanceOf(address(pocket)), 500e6);
    }

    function test_withdrawLiquidity_emitsEvent() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

    function test_withdrawLiquidity_existingBalanceCoversAll_emitsZeroConverted() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 0);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

}

/**********************************************************************************************/
/*** availableBalance tests                                                                 ***/
/**********************************************************************************************/

contract MorphoUsdtPocketAvailableBalanceTests is MorphoUsdtPocketTestBase {

    function test_availableBalance_usdtOnly() public {
        usdt.mint(address(pocket), 1000e6);
        assertEq(pocket.availableBalance(address(usdt)), 1000e6);
    }

    function test_availableBalance_vaultSharesOnly() public {
        usdt.mint(address(pocket), 2000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(2000e6, address(usdt));

        assertEq(pocket.availableBalance(address(usdt)), 2000e6);
    }

    function test_availableBalance_combined() public {
        usdt.mint(address(pocket), 1500e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        // 500 USDT + 1000 shares (1:1 rate)
        assertEq(pocket.availableBalance(address(usdt)), 1500e6);
    }

    function test_availableBalance_unsupportedAsset() public view {
        assertEq(pocket.availableBalance(address(collateralToken)), 0);
    }

    function test_availableBalance_exchangeRateChange() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        // Verify initial balance (1:1 rate)
        assertEq(pocket.availableBalance(address(usdt)), 1000e6);

        // Simulate yield accrual: 1 share = 1.5 USDT (3/2)
        vault.setExchangeRate(3, 2);

        // 1000 shares * 3/2 = 1500 USDT
        assertEq(pocket.availableBalance(address(usdt)), 1500e6);
    }

}

/**********************************************************************************************/
/*** Role management tests                                                                  ***/
/**********************************************************************************************/

contract MorphoUsdtPocketRoleManagementTests is MorphoUsdtPocketTestBase {

    bytes32 managerRole;

    function setUp() public override {
        super.setUp();
        managerRole = pocket.MANAGER_ROLE();
    }

    function test_admin_grantManagerRole() public {
        address newManager = makeAddr("newManager");

        vm.prank(admin);
        pocket.grantRole(managerRole, newManager);

        assertTrue(pocket.hasRole(managerRole, newManager));
    }

    function test_admin_revokeManagerRole() public {
        vm.prank(admin);
        pocket.revokeRole(managerRole, manager);

        assertFalse(pocket.hasRole(managerRole, manager));
    }

    function test_revokedManager_cannotDeposit() public {
        vm.prank(admin);
        pocket.revokeRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert("MorphoUsdtPocket/not-authorized");
        pocket.depositLiquidity(100e6, address(usdt));
    }

    function test_revokedManager_cannotWithdraw() public {
        vm.prank(admin);
        pocket.revokeRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert("MorphoUsdtPocket/not-authorized");
        pocket.withdrawLiquidity(100e6, address(usdt));
    }

    function test_manager_canRenounceOwnRole() public {
        vm.prank(manager);
        pocket.renounceRole(managerRole, manager);

        assertFalse(pocket.hasRole(managerRole, manager));
    }

    function test_nonAdmin_cannotGrantManagerRole() public {
        address randomUser = makeAddr("randomUser");
        address newManager = makeAddr("newManager");

        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomUser,
                pocket.DEFAULT_ADMIN_ROLE()
            )
        );
        pocket.grantRole(managerRole, newManager);
        vm.stopPrank();
    }

    function test_nonAdmin_cannotRevokeManagerRole() public {
        address randomUser = makeAddr("randomUser");

        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomUser,
                pocket.DEFAULT_ADMIN_ROLE()
            )
        );
        pocket.revokeRole(managerRole, manager);
        vm.stopPrank();
    }

    function test_multipleManagers() public {
        address manager2 = makeAddr("manager2");

        vm.prank(admin);
        pocket.grantRole(managerRole, manager2);

        usdt.mint(address(pocket), 2000e6);

        vm.prank(manager);
        pocket.depositLiquidity(1000e6, address(usdt));

        usdt.mint(address(pocket), 1000e6);

        vm.prank(manager2);
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(vault.balanceOf(address(pocket)), 2000e6);
    }

}

/**********************************************************************************************/
/*** Basin independence from roles tests                                                    ***/
/**********************************************************************************************/

contract MorphoUsdtPocketBasinIndependenceTests is MorphoUsdtPocketTestBase {

    bytes32 managerRole;

    function setUp() public override {
        super.setUp();
        managerRole = pocket.MANAGER_ROLE();
    }

    function test_basin_canDepositRegardlessOfRoles() public {
        vm.prank(admin);
        pocket.revokeRole(managerRole, manager);

        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(vault.balanceOf(address(pocket)), 1000e6);
    }

    function test_basin_canWithdrawRegardlessOfRoles() public {
        vm.prank(admin);
        pocket.revokeRole(managerRole, manager);

        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
    }

    function test_basin_doesNotNeedManagerRole() public view {
        assertFalse(pocket.hasRole(managerRole, address(groveBasin)));
    }

}

/**********************************************************************************************/
/*** Event emission tests for both callers                                                  ***/
/**********************************************************************************************/

contract MorphoUsdtPocketEventTests is MorphoUsdtPocketTestBase {

    function test_depositLiquidity_basin_emitsEvent() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdt), 1000e6, 1000e6);
        pocket.depositLiquidity(1000e6, address(usdt));
    }

    function test_depositLiquidity_manager_emitsEvent() public {
        usdt.mint(address(pocket), 500e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdt), 500e6, 500e6);
        pocket.depositLiquidity(500e6, address(usdt));
    }

    function test_withdrawLiquidity_basin_emitsEvent() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

    function test_withdrawLiquidity_manager_emitsEvent() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

    function test_withdrawLiquidity_nonOneToOneRate_emitsUsdtAmount() public {
        // Deposit 1000 USDT at 1:1 rate → 1000 shares
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        // Change exchange rate: 1 share = 1.5 USDT (3/2)
        vault.setExchangeRate(3, 2);

        // Withdraw 600 USDT from vault.
        // At 3/2 rate, vault.withdraw(600e6) burns 400e6 shares (600 * 2/3 = 400).
        // convertedAmount should be 600e6 (USDT amount), NOT 400e6 (shares burned).
        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 600e6, 600e6);
        pocket.withdrawLiquidity(600e6, address(usdt));
    }

}
