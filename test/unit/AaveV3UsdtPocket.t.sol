// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }           from "src/GroveBasin.sol";
import { AaveV3UsdtPocket }     from "src/pockets/AaveV3UsdtPocket.sol";
import { IGroveBasinPocket }    from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAaveV3Pool }  from "test/mocks/MockAaveV3Pool.sol";
import { MockAToken }      from "test/mocks/MockAToken.sol";

contract AaveV3UsdtPocketTestBase is Test {

    address public owner   = makeAddr("owner");
    address public lp      = makeAddr("liquidityProvider");
    address public manager = makeAddr("manager");

    GroveBasin       public groveBasin;
    AaveV3UsdtPocket public pocket;

    MockERC20  public usdt;
    MockAToken public aUsdt;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockAaveV3Pool public aaveV3Pool;

    function setUp() public virtual {
        usdt            = new MockERC20("USDT",       "USDT",    6);
        aUsdt           = new MockAToken("aUSDT",      "aUSDT",   6, address(usdt));
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

        aaveV3Pool = new MockAaveV3Pool(address(aUsdt), address(usdt));

        usdt.mint(address(aaveV3Pool), 1_000_000_000e6);
        aUsdt.mint(address(aaveV3Pool), 1_000_000_000e6);

        pocket = new AaveV3UsdtPocket(
            address(groveBasin),
            address(usdt),
            address(aUsdt),
            address(aaveV3Pool)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       manager);

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

contract AaveV3UsdtPocketConstructorTests is AaveV3UsdtPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert(IGroveBasinPocket.InvalidBasin.selector);
        new AaveV3UsdtPocket(address(0), address(usdt), address(aUsdt), address(aaveV3Pool));
    }

    function test_constructor_invalidUsdt() public {
        vm.expectRevert(AaveV3UsdtPocket.InvalidUsdt.selector);
        new AaveV3UsdtPocket(address(groveBasin), address(0), address(aUsdt), address(aaveV3Pool));
    }

    function test_constructor_invalidAUsdt() public {
        vm.expectRevert(AaveV3UsdtPocket.InvalidAUsdt.selector);
        new AaveV3UsdtPocket(address(groveBasin), address(usdt), address(0), address(aaveV3Pool));
    }

    function test_constructor_invalidAaveV3Pool() public {
        vm.expectRevert(AaveV3UsdtPocket.InvalidAaveV3Pool.selector);
        new AaveV3UsdtPocket(address(groveBasin), address(usdt), address(aUsdt), address(0));
    }

    function test_constructor_underlyingAssetMismatch() public {
        MockERC20 otherToken = new MockERC20("OTHER", "OTH", 6);
        MockAToken wrongAToken = new MockAToken("aOTHER", "aOTH", 6, address(otherToken));

        vm.expectRevert(AaveV3UsdtPocket.UnderlyingAssetMismatch.selector);
        new AaveV3UsdtPocket(address(groveBasin), address(usdt), address(wrongAToken), address(aaveV3Pool));
    }

    function test_constructor_swapTokenMismatch() public {
        MockERC20 otherSwap = new MockERC20("OTHER", "OTH", 6);

        GroveBasin mismatchedBasin = new GroveBasin(
            owner,
            lp,
            address(otherSwap),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.expectRevert(AaveV3UsdtPocket.SwapTokenMismatch.selector);
        new AaveV3UsdtPocket(address(mismatchedBasin), address(usdt), address(aUsdt), address(aaveV3Pool));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(),          address(groveBasin));
        assertEq(address(pocket.usdt()),  address(usdt));
        assertEq(address(pocket.aUsdt()), address(aUsdt));
        assertEq(pocket.aaveV3Pool(),     address(aaveV3Pool));

        assertEq(usdt.allowance(address(pocket), address(groveBasin)), type(uint256).max);
    }

}

/**********************************************************************************************/
/*** Access control tests                                                                   ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketAccessControlTests is AaveV3UsdtPocketTestBase {

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
/*** MANAGER_ROLE deposit/withdraw tests                                                    ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketManagerTests is AaveV3UsdtPocketTestBase {

    function test_depositLiquidity_manager_suppliesToAave() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdt), 1000e6, 1000e6);
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 0);
        assertEq(aUsdt.balanceOf(address(pocket)), 1000e6);
    }

    function test_withdrawLiquidity_manager_withdrawsFromAave() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 500e6);
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

}

/**********************************************************************************************/
/*** Role management tests                                                                  ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketRoleManagementTests is AaveV3UsdtPocketTestBase {

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

        assertEq(aUsdt.balanceOf(address(pocket)), 2000e6);
    }

}

/**********************************************************************************************/
/*** Basin independence from roles tests                                                    ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketBasinIndependenceTests is AaveV3UsdtPocketTestBase {

    function test_basin_canDepositRegardlessOfRoles() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(aUsdt.balanceOf(address(pocket)), 1000e6);
    }

    function test_basin_canWithdrawRegardlessOfRoles() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
    }

    function test_basin_doesNotNeedManagerRole() public view {
        assertFalse(groveBasin.hasRole(groveBasin.MANAGER_ROLE(), address(groveBasin)));
    }

}

/**********************************************************************************************/
/*** depositLiquidity tests (basin caller)                                                  ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketDepositLiquidityTests is AaveV3UsdtPocketTestBase {

    function test_depositLiquidity_zeroAmount() public {
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(0, address(usdt));
    }

    function test_depositLiquidity_suppliesToAave() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdt), 1000e6, 1000e6);
        pocket.depositLiquidity(1000e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 0);
        assertEq(aUsdt.balanceOf(address(pocket)), 1000e6);
    }

    function test_depositLiquidity_invalidAsset() public {
        vm.prank(address(groveBasin));
        vm.expectRevert(IGroveBasinPocket.InvalidAsset.selector);
        pocket.depositLiquidity(100e6, address(collateralToken));
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity tests (basin caller)                                                 ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketDrawLiquidityTests is AaveV3UsdtPocketTestBase {

    function test_withdrawLiquidity_zeroAmount() public {
        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(0, address(usdt));
    }

    function test_withdrawLiquidity_existingBalanceCoversAll() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 1000e6);
    }

    function test_withdrawLiquidity_partialBalanceWithdrawsRemainder() public {
        usdt.mint(address(pocket),  300e6);
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)),  500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 800e6);
    }

    function test_withdrawLiquidity_noBalanceWithdrawsAll() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 500e6);
    }

    function test_withdrawLiquidity_uintMaxBalanceFails() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectRevert(AaveV3UsdtPocket.NoWithdrawMaxUint.selector);
        pocket.withdrawLiquidity(type(uint256).max, address(usdt));
    }

    function test_withdrawLiquidity_emitsEvent() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

    function test_withdrawLiquidity_invalidAsset() public {
        vm.prank(address(groveBasin));
        vm.expectRevert(IGroveBasinPocket.InvalidAsset.selector);
        pocket.withdrawLiquidity(100e6, address(collateralToken));
    }

}

/**********************************************************************************************/
/*** availableBalance tests                                                                 ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketAvailableBalanceTests is AaveV3UsdtPocketTestBase {

    function test_availableBalance_usdtOnly() public {
        usdt.mint(address(pocket), 1000e6);
        assertEq(pocket.availableBalance(address(usdt)), 1000e6);
    }

    function test_availableBalance_aUsdtOnly() public {
        aUsdt.mint(address(pocket), 2000e6);
        assertEq(pocket.availableBalance(address(usdt)), 2000e6);
    }

    function test_availableBalance_combined() public {
        usdt.mint(address(pocket),  500e6);
        aUsdt.mint(address(pocket), 1500e6);
        assertEq(pocket.availableBalance(address(usdt)), 2000e6);
    }

    function test_availableBalance_unsupportedAsset() public view {
        assertEq(pocket.availableBalance(address(collateralToken)), 0);
    }

}

/**********************************************************************************************/
/*** Event emission tests for both callers                                                  ***/
/**********************************************************************************************/

contract AaveV3UsdtPocketEventTests is AaveV3UsdtPocketTestBase {

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
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

    function test_withdrawLiquidity_manager_emitsEvent() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdt));
    }

}
