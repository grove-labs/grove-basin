// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { UsdsUsdcPocket }    from "src/pockets/UsdsUsdcPocket.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

contract UsdsUsdcPocketTestBase is Test {

    address public owner      = makeAddr("owner");
    address public lp         = makeAddr("liquidityProvider");
    address public manager    = makeAddr("manager");
    address public groveProxy = makeAddr("groveProxy");

    GroveBasin     public groveBasin;
    UsdsUsdcPocket public pocket;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public psm;

    function setUp() public virtual {
        usds            = new MockERC20("USDS",       "USDS",   18);
        usdc            = new MockERC20("USDC",       "USDC",   6);
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
            address(usds),
            address(usdc),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        psm = new MockPSM(address(usds), address(usdc));
        usdc.mint(address(psm), 1_000_000_000e6);
        usds.mint(address(psm), 1_000_000_000e18);

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm),
            groveProxy
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       manager);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract UsdsUsdcPocketConstructorTests is UsdsUsdcPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert(IGroveBasinPocket.InvalidBasin.selector);
        new UsdsUsdcPocket(address(0), address(usdc), address(usds), address(psm), groveProxy);
    }

    function test_constructor_invalidUsdc() public {
        vm.expectRevert(UsdsUsdcPocket.InvalidUsdc.selector);
        new UsdsUsdcPocket(address(groveBasin), address(0), address(usds), address(psm), groveProxy);
    }

    function test_constructor_invalidUsds() public {
        vm.expectRevert(UsdsUsdcPocket.InvalidUsds.selector);
        new UsdsUsdcPocket(address(groveBasin), address(usdc), address(0), address(psm), groveProxy);
    }

    function test_constructor_invalidPsm() public {
        vm.expectRevert(UsdsUsdcPocket.InvalidPsm.selector);
        new UsdsUsdcPocket(address(groveBasin), address(usdc), address(usds), address(0), groveProxy);
    }

    function test_constructor_swapTokenMismatch() public {
        MockERC20 otherToken = new MockERC20("OTHER", "OTH", 18);
        vm.expectRevert(UsdsUsdcPocket.SwapTokenMismatch.selector);
        new UsdsUsdcPocket(address(groveBasin), address(usdc), address(otherToken), address(psm), groveProxy);
    }

    function test_constructor_collateralTokenMismatch() public {
        MockERC20 otherToken = new MockERC20("OTHER", "OTH", 6);
        vm.expectRevert(UsdsUsdcPocket.CollateralTokenMismatch.selector);
        new UsdsUsdcPocket(address(groveBasin), address(otherToken), address(usds), address(psm), groveProxy);
    }

    function test_constructor_zeroGroveProxy() public {
        UsdsUsdcPocket p = new UsdsUsdcPocket(address(groveBasin), address(usdc), address(usds), address(psm), address(0));
        assertEq(p.groveProxy(), address(0));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(),          address(groveBasin));
        assertEq(address(pocket.usdc()),  address(usdc));
        assertEq(address(pocket.usds()),  address(usds));
        assertEq(pocket.psm(),           address(psm));
        assertEq(pocket.groveProxy(),    groveProxy);

        assertEq(usds.allowance(address(pocket), address(groveBasin)), type(uint256).max);
        assertEq(usdc.allowance(address(pocket), address(groveBasin)), type(uint256).max);
        assertEq(usds.allowance(address(pocket), groveProxy),         type(uint256).max);
    }

}

/**********************************************************************************************/
/*** Access control tests                                                                   ***/
/**********************************************************************************************/

contract UsdsUsdcPocketAccessControlTests is UsdsUsdcPocketTestBase {

    function test_depositLiquidity_notAuthorized() public {
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.depositLiquidity(100e6, address(usdc));
    }

    function test_withdrawLiquidity_notAuthorized() public {
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.withdrawLiquidity(100e6, address(usdc));
    }

}

/**********************************************************************************************/
/*** MANAGER_ROLE deposit/withdraw tests                                                    ***/
/**********************************************************************************************/

contract UsdsUsdcPocketManagerTests is UsdsUsdcPocketTestBase {

    function test_depositLiquidity_manager_usdc_swapsToUsds() public {
        usdc.mint(address(pocket), 1000e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdc), 1000e6, 1000e18);
        pocket.depositLiquidity(1000e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 0);
        assertEq(usds.balanceOf(address(pocket)), 1000e18);
    }

    function test_depositLiquidity_manager_usds_holdsDirectly() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usds), 1000e18, 0);
        pocket.depositLiquidity(1000e18, address(usds));

        assertEq(usds.balanceOf(address(pocket)), 1000e18);
    }

    function test_withdrawLiquidity_manager_usdc() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdc), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 500e6);
        assertEq(usds.balanceOf(address(pocket)), 500e18);
    }

    function test_depositLiquidity_manager_zeroAmount() public {
        vm.prank(manager);
        uint256 result = pocket.depositLiquidity(0, address(usdc));
        assertEq(result, 0);
    }

    function test_withdrawLiquidity_manager_zeroAmount() public {
        vm.prank(manager);
        uint256 result = pocket.withdrawLiquidity(0, address(usdc));
        assertEq(result, 0);
    }

}

/**********************************************************************************************/
/*** Role management tests                                                                  ***/
/**********************************************************************************************/

contract UsdsUsdcPocketRoleManagementTests is UsdsUsdcPocketTestBase {

    function test_revokedManager_cannotDeposit() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.prank(manager);
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.depositLiquidity(100e6, address(usdc));
    }

    function test_revokedManager_cannotWithdraw() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.prank(manager);
        vm.expectRevert(IGroveBasinPocket.NotAuthorized.selector);
        pocket.withdrawLiquidity(100e6, address(usdc));
    }

    function test_multipleManagers() public {
        address manager2 = makeAddr("manager2");

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager2);
        vm.stopPrank();

        usdc.mint(address(pocket), 2000e6);

        vm.prank(manager);
        pocket.depositLiquidity(1000e6, address(usdc));

        usdc.mint(address(pocket), 1000e6);

        vm.prank(manager2);
        pocket.depositLiquidity(1000e6, address(usdc));

        assertEq(usds.balanceOf(address(pocket)), 2000e18);
    }

}

/**********************************************************************************************/
/*** Basin independence from roles tests                                                    ***/
/**********************************************************************************************/

contract UsdsUsdcPocketBasinIndependenceTests is UsdsUsdcPocketTestBase {

    function test_basin_canDepositRegardlessOfRoles() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        usdc.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdc));

        assertEq(usds.balanceOf(address(pocket)), 1000e18);
    }

    function test_basin_canWithdrawRegardlessOfRoles() public {
        vm.startPrank(owner);
        groveBasin.revokeRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 500e6);
    }

    function test_basin_doesNotNeedManagerRole() public view {
        assertFalse(groveBasin.hasRole(groveBasin.MANAGER_ROLE(), address(groveBasin)));
    }

}

/**********************************************************************************************/
/*** depositLiquidity tests (basin caller)                                                  ***/
/**********************************************************************************************/

contract UsdsUsdcPocketDepositLiquidityTests is UsdsUsdcPocketTestBase {

    function test_depositLiquidity_zeroAmount() public {
        vm.prank(address(groveBasin));
        pocket.depositLiquidity(0, address(usdc));
    }

    function test_depositLiquidity_usdc_swapsToUsds() public {
        usdc.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdc), 1000e6, 1000e18);
        pocket.depositLiquidity(1000e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 0);
        assertEq(usds.balanceOf(address(pocket)), 1000e18);
    }

    function test_depositLiquidity_usds_holdsDirectly() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usds), 1000e18, 0);
        pocket.depositLiquidity(1000e18, address(usds));

        assertEq(usds.balanceOf(address(pocket)), 1000e18);
    }

    function test_depositLiquidity_unsupportedAsset_reverts() public {
        vm.prank(address(groveBasin));
        vm.expectRevert(IGroveBasinPocket.InvalidAsset.selector);
        pocket.depositLiquidity(100e18, address(collateralToken));
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity tests                                                                    ***/
/**********************************************************************************************/

contract UsdsUsdcPocketDrawLiquidityTests is UsdsUsdcPocketTestBase {

    function test_withdrawLiquidity_zeroAmount() public {
        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(0, address(usdc));
    }

    function test_withdrawLiquidity_usdc_existingBalanceCoversAll() public {
        usdc.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 1000e6);
    }

    function test_withdrawLiquidity_usdc_partialBalanceSwapsRemainder() public {
        usdc.mint(address(pocket), 300e6);
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 500e6);
        assertEq(usds.balanceOf(address(pocket)), 800e18);
    }

    function test_withdrawLiquidity_usdc_noBalanceSwapsAll() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usdc.balanceOf(address(pocket)), 500e6);
        assertEq(usds.balanceOf(address(pocket)), 500e18);
    }

    function test_withdrawLiquidity_usdc_emitsEvent() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdc), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdc));
    }

    function test_withdrawLiquidity_usdc_revertsIfToutNonZero() public {
        usds.mint(address(pocket), 1000e18);

        psm.__setTout(1);

        vm.prank(address(groveBasin));
        vm.expectRevert(UsdsUsdcPocket.NonZeroPsmTout.selector);
        pocket.withdrawLiquidity(500e6, address(usdc));
    }

    function test_withdrawLiquidity_unsupportedAsset_reverts() public {
        vm.prank(address(groveBasin));
        vm.expectRevert(IGroveBasinPocket.InvalidAsset.selector);
        pocket.withdrawLiquidity(100e18, address(collateralToken));
    }

    function test_withdrawLiquidity_usds_returnsAmount() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        uint256 result = pocket.withdrawLiquidity(500e18, address(usds));

        assertEq(result, 500e18);
    }

}

/**********************************************************************************************/
/*** Approval cleanup tests                                                                 ***/
/**********************************************************************************************/

contract UsdsUsdcPocketApprovalCleanupTests is UsdsUsdcPocketTestBase {

    function test_depositLiquidity_usdc_clearsPsmApproval() public {
        usdc.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdc));

        assertEq(usdc.allowance(address(pocket), address(psm)), 0);
    }

    function test_depositLiquidity_usdc_doesNotLeaveUsdsPsmApproval() public {
        usdc.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.depositLiquidity(1000e6, address(usdc));

        assertEq(usds.allowance(address(pocket), address(psm)), 0);
    }

    function test_withdrawLiquidity_usdc_clearsUsdsPsmApproval() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usds.allowance(address(pocket), address(psm)), 0);
    }

    function test_withdrawLiquidity_usdc_doesNotLeaveUsdcPsmApproval() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdc));

        assertEq(usdc.allowance(address(pocket), address(psm)), 0);
    }

}

/**********************************************************************************************/
/*** availableBalance tests                                                                 ***/
/**********************************************************************************************/

contract UsdsUsdcPocketAvailableBalanceTests is UsdsUsdcPocketTestBase {

    function test_availableBalance_usdc_usdcOnly() public {
        usdc.mint(address(pocket), 1000e6);
        assertEq(pocket.availableBalance(address(usdc)), 1000e6);
    }

    function test_availableBalance_usdc_usdsOnly() public {
        usds.mint(address(pocket), 1000e18);
        assertEq(pocket.availableBalance(address(usdc)), 1000e6);
    }

    function test_availableBalance_usdc_combined() public {
        usdc.mint(address(pocket), 500e6);
        usds.mint(address(pocket), 1000e18);
        assertEq(pocket.availableBalance(address(usdc)), 1500e6);
    }

    function test_availableBalance_usds() public {
        usds.mint(address(pocket), 2000e18);
        assertEq(pocket.availableBalance(address(usds)), 2000e18);
    }

    function test_availableBalance_unsupportedAsset() public {
        assertEq(pocket.availableBalance(address(collateralToken)), 0);
    }

}

/**********************************************************************************************/
/*** Event emission tests for both callers                                                  ***/
/**********************************************************************************************/

contract UsdsUsdcPocketEventTests is UsdsUsdcPocketTestBase {

    function test_depositLiquidity_basin_emitsEvent() public {
        usdc.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdc), 1000e6, 1000e18);
        pocket.depositLiquidity(1000e6, address(usdc));
    }

    function test_depositLiquidity_manager_emitsEvent() public {
        usdc.mint(address(pocket), 500e6);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDeposited(address(usdc), 500e6, 500e18);
        pocket.depositLiquidity(500e6, address(usdc));
    }

    function test_withdrawLiquidity_basin_emitsEvent() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdc), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdc));
    }

    function test_withdrawLiquidity_manager_emitsEvent() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(manager);
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdc), 500e6, 500e6);
        pocket.withdrawLiquidity(500e6, address(usdc));
    }

}

/**********************************************************************************************/
/*** Grove Proxy withdrawal tests                                                           ***/
/**********************************************************************************************/

contract UsdsUsdcPocketGroveProxyTests is UsdsUsdcPocketTestBase {

    function test_groveProxy_canWithdrawUsds() public {
        usds.mint(address(pocket), 1000e18);

        vm.prank(groveProxy);
        usds.transferFrom(address(pocket), groveProxy, 1000e18);

        assertEq(usds.balanceOf(address(pocket)), 0);
        assertEq(usds.balanceOf(groveProxy),      1000e18);
    }

}
