// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { UsdtPocket }        from "src/UsdtPocket.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAaveV3Pool }  from "test/mocks/MockAaveV3Pool.sol";

contract UsdtPocketTestBase is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");

    GroveBasin     public groveBasin;
    UsdtPocket     public pocket;

    MockERC20 public usdt;
    MockERC20 public aUsdt;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockAaveV3Pool public aaveV3Pool;

    function setUp() public virtual {
        usdt            = new MockERC20("USDT",       "USDT",       6);
        aUsdt           = new MockERC20("aUSDT",      "aUSDT",      6);
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

        aaveV3Pool = new MockAaveV3Pool(address(aUsdt), address(usdt));

        usdt.mint(address(aaveV3Pool), 1_000_000_000e6);
        aUsdt.mint(address(aaveV3Pool), 1_000_000_000e6);

        pocket = new UsdtPocket(
            address(groveBasin),
            manager,
            address(usdt),
            address(aUsdt),
            address(aaveV3Pool)
        );

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

contract UsdtPocketConstructorTests is UsdtPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert("UsdtPocket/invalid-basin");
        new UsdtPocket(address(0), manager, address(usdt), address(aUsdt), address(aaveV3Pool));
    }

    function test_constructor_invalidManager() public {
        vm.expectRevert("UsdtPocket/invalid-manager");
        new UsdtPocket(address(groveBasin), address(0), address(usdt), address(aUsdt), address(aaveV3Pool));
    }

    function test_constructor_invalidUsdt() public {
        vm.expectRevert("UsdtPocket/invalid-usdt");
        new UsdtPocket(address(groveBasin), manager, address(0), address(aUsdt), address(aaveV3Pool));
    }

    function test_constructor_invalidAUsdt() public {
        vm.expectRevert("UsdtPocket/invalid-aUsdt");
        new UsdtPocket(address(groveBasin), manager, address(usdt), address(0), address(aaveV3Pool));
    }

    function test_constructor_invalidAaveV3Pool() public {
        vm.expectRevert("UsdtPocket/invalid-aaveV3Pool");
        new UsdtPocket(address(groveBasin), manager, address(usdt), address(aUsdt), address(0));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(),      address(groveBasin));
        assertEq(pocket.manager(),    manager);
        assertEq(address(pocket.usdt()),  address(usdt));
        assertEq(address(pocket.aUsdt()), address(aUsdt));
        assertEq(pocket.aaveV3Pool(), address(aaveV3Pool));

        assertEq(usdt.allowance(address(pocket), address(groveBasin)), type(uint256).max);
    }

}

/**********************************************************************************************/
/*** Access control tests                                                                   ***/
/**********************************************************************************************/

contract UsdtPocketAccessControlTests is UsdtPocketTestBase {

    function test_withdrawLiquidity_notBasin() public {
        vm.expectRevert("UsdtPocket/not-basin");
        pocket.withdrawLiquidity(100e6, address(usdt));
    }

    function test_depositLiquidity_notBasin() public {
        vm.expectRevert("UsdtPocket/not-basin");
        pocket.depositLiquidity(100e6, address(usdt));
    }


}

/**********************************************************************************************/
/*** depositLiquidity tests                                                                 ***/
/**********************************************************************************************/

contract UsdtPocketDepositLiquidityTests is UsdtPocketTestBase {

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
        vm.expectRevert("UsdtPocket/invalid-asset");
        pocket.depositLiquidity(100e6, address(collateralToken));
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity tests                                                                    ***/
/**********************************************************************************************/

contract UsdtPocketDrawLiquidityTests is UsdtPocketTestBase {

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
        usdt.mint(address(pocket), 300e6);
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 800e6);
    }

    function test_withdrawLiquidity_noBalanceWithdrawsAll() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(500e6, address(usdt));

        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 500e6);
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
        vm.expectRevert("UsdtPocket/invalid-asset");
        pocket.withdrawLiquidity(100e6, address(collateralToken));
    }

}

/**********************************************************************************************/
/*** availableBalance tests                                                                 ***/
/**********************************************************************************************/

contract UsdtPocketAvailableBalanceTests is UsdtPocketTestBase {

    function test_availableBalance_usdtOnly() public {
        usdt.mint(address(pocket), 1000e6);
        assertEq(pocket.availableBalance(address(usdt)), 1000e6);
    }

    function test_availableBalance_aUsdtOnly() public {
        aUsdt.mint(address(pocket), 2000e6);
        assertEq(pocket.availableBalance(address(usdt)), 2000e6);
    }

    function test_availableBalance_combined() public {
        usdt.mint(address(pocket), 500e6);
        aUsdt.mint(address(pocket), 1500e6);
        assertEq(pocket.availableBalance(address(usdt)), 2000e6);
    }

    function test_availableBalance_unsupportedAsset() public {
        assertEq(pocket.availableBalance(address(collateralToken)), 0);
    }

}


