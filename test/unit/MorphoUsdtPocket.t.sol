// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { MorphoUsdtPocket }    from "src/pockets/MorphoUsdtPocket.sol";
import { IGroveBasinPocket }   from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider }   from "test/mocks/MockRateProvider.sol";
import { MockERC4626Vault }   from "test/mocks/MockERC4626Vault.sol";

contract MorphoUsdtPocketTestBase is Test {

    address public owner   = makeAddr("owner");
    address public lp      = makeAddr("liquidityProvider");
    address public manager = makeAddr("manager");

    GroveBasin       public groveBasin;
    MorphoUsdtPocket public pocket;

    MockERC20 public usdt;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockERC4626Vault public vault;

    function setUp() public virtual {
        usdt            = new MockERC20("USDT",       "USDT",   6);
        collateralToken = new MockERC20("COLLATERAL", "COL",    18);
        creditToken     = new MockERC20("CREDIT",     "CREDIT", 18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            lp,
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
            address(usdt),
            address(vault)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();

        vm.prank(manager);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
    }

}

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract MorphoUsdtPocketConstructorTests is MorphoUsdtPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert(IGroveBasinPocket.InvalidBasin.selector);
        new MorphoUsdtPocket(address(0), address(usdt), address(vault));
    }

    function test_constructor_invalidUsdt() public {
        vm.expectRevert(MorphoUsdtPocket.InvalidUsdt.selector);
        new MorphoUsdtPocket(address(groveBasin), address(0), address(vault));
    }

    function test_constructor_invalidVault() public {
        vm.expectRevert(MorphoUsdtPocket.InvalidVault.selector);
        new MorphoUsdtPocket(address(groveBasin), address(usdt), address(0));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(), address(groveBasin));
        assertEq(address(pocket.usdt()), address(usdt));
        assertEq(pocket.vault(), address(vault));

        assertEq(usdt.allowance(address(pocket), address(groveBasin)), type(uint256).max);
    }

    function test_constructor_vaultIsImmutable() public view {
        assertEq(pocket.vault(), address(vault));
    }

}

/**********************************************************************************************/
/*** Access control tests                                                                   ***/
/**********************************************************************************************/

contract MorphoUsdtPocketAccessControlTests is MorphoUsdtPocketTestBase {

    function test_depositLiquidity_notAuthorized() public {
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.depositLiquidity(100e6, address(usdt));
    }

    function test_withdrawLiquidity_notAuthorized() public {
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
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
        vm.expectRevert(IGroveBasinPocket.InvalidAsset.selector);
        pocket.depositLiquidity(100e6, address(collateralToken));
    }

    function test_depositLiquidity_depositsToVault() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        uint256 result = pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(result, 1000e6);
        assertEq(usdt.balanceOf(address(pocket)),  0);
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

        assertEq(usdt.balanceOf(address(pocket)),  0);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);
    }

    function test_withdrawLiquidity_manager_withdrawsFromVault() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)),  500e6);
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
        vm.expectRevert(IGroveBasinPocket.InvalidAsset.selector);
        pocket.withdrawLiquidity(100e6, address(collateralToken));
    }

    function test_withdrawLiquidity_existingBalanceCoversAll() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(500e6, address(usdt));

        uint256 vaultSharesBefore = vault.balanceOf(address(pocket));

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(vault.balanceOf(address(pocket)), vaultSharesBefore);
        assertEq(usdt.balanceOf(address(pocket)), 500e6);
    }

    function test_withdrawLiquidity_partialBalanceWithdrawsRemainder() public {
        usdt.mint(address(pocket), 300e6);

        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)),  300e6);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)),  500e6);
        assertEq(vault.balanceOf(address(pocket)), 800e6);
    }

    function test_withdrawLiquidity_noBalanceWithdrawsAllFromVault() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)),  0);
        assertEq(vault.balanceOf(address(pocket)), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)),  500e6);
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

        assertEq(pocket.availableBalance(address(usdt)), 1500e6);
    }

    function test_availableBalance_unsupportedAsset() public view {
        assertEq(pocket.availableBalance(address(collateralToken)), 0);
    }

    function test_availableBalance_exchangeRateChange() public {
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(pocket.availableBalance(address(usdt)), 1000e6);

        vault.setExchangeRate(3, 2);

        assertEq(pocket.availableBalance(address(usdt)), 1500e6);
    }

}

/**********************************************************************************************/
/*** Role management tests                                                                  ***/
/**********************************************************************************************/

contract MorphoUsdtPocketRoleManagementTests is MorphoUsdtPocketTestBase {

    function test_revokedManager_cannotDeposit() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.prank(manager);
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.depositLiquidity(100e6, address(usdt));
    }

    function test_revokedManager_cannotWithdraw() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.prank(manager);
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.withdrawLiquidity(100e6, address(usdt));
    }

    function test_multipleManagers() public {
        address manager2 = makeAddr("manager2");

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager2);
        vm.stopPrank();

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

    function test_basin_canDepositRegardlessOfRoles() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(vault.balanceOf(address(pocket)), 1000e6);
    }

    function test_basin_canWithdrawRegardlessOfRoles() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
    }

    function test_basin_doesNotNeedManagerRole() public view {
        assertFalse(groveBasin.hasRole(groveBasin.MANAGER_ROLE(), address(groveBasin)));
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
        usdt.mint(address(pocket), 1000e6);
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        vault.setExchangeRate(3, 2);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 600e6, 600e6);
        pocket.withdrawLiquidity(600e6, address(usdt));
    }

}
