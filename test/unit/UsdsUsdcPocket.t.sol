// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { UsdsUsdcPocket }    from "src/UsdsUsdcPocket.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

contract UsdsUsdcPocketTestBase is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");

    GroveBasin       public groveBasin;
    UsdsUsdcPocket   public pocket;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public psm;

    function setUp() public virtual {
        usds            = new MockERC20("USDS",       "USDS",       18);
        usdc            = new MockERC20("USDC",       "USDC",       6);
        collateralToken = new MockERC20("COLLATERAL", "COL",        18);
        creditToken     = new MockERC20("CREDIT",     "CREDIT",     18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(usdc),
            address(collateralToken),
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
            address(psm)
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

contract UsdsUsdcPocketConstructorTests is UsdsUsdcPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert("UsdsUsdcPocket/invalid-basin");
        new UsdsUsdcPocket(address(0), address(usdc), address(usds), address(psm));
    }

    function test_constructor_invalidUsdc() public {
        vm.expectRevert("UsdsUsdcPocket/invalid-usdc");
        new UsdsUsdcPocket(address(groveBasin), address(0), address(usds), address(psm));
    }

    function test_constructor_invalidUsds() public {
        vm.expectRevert("UsdsUsdcPocket/invalid-usds");
        new UsdsUsdcPocket(address(groveBasin), address(usdc), address(0), address(psm));
    }

    function test_constructor_invalidPsm() public {
        vm.expectRevert("UsdsUsdcPocket/invalid-psm");
        new UsdsUsdcPocket(address(groveBasin), address(usdc), address(usds), address(0));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(),      address(groveBasin));
        assertEq(address(pocket.usdc()),  address(usdc));
        assertEq(address(pocket.usds()),  address(usds));
        assertEq(pocket.psm(),       address(psm));

        assertEq(usds.allowance(address(pocket), address(groveBasin)), type(uint256).max);
        assertEq(usdc.allowance(address(pocket), address(groveBasin)), type(uint256).max);
    }

}

/**********************************************************************************************/
/*** Access control tests                                                                   ***/
/**********************************************************************************************/

contract UsdsUsdcPocketAccessControlTests is UsdsUsdcPocketTestBase {

    function test_withdrawLiquidity_notBasin() public {
        vm.expectRevert("UsdsUsdcPocket/not-basin");
        pocket.withdrawLiquidity(100e6, address(usdc));
    }

    function test_depositLiquidity_notBasin() public {
        vm.expectRevert("UsdsUsdcPocket/not-basin");
        pocket.depositLiquidity(100e6, address(usdc));
    }


}

/**********************************************************************************************/
/*** depositLiquidity tests                                                                 ***/
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

    function test_depositLiquidity_unsupportedAsset_noOp() public {
        vm.prank(address(groveBasin));
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
        emit IGroveBasinPocket.LiquidityDrawn(address(usdc), 500e6, 500e18);
        pocket.withdrawLiquidity(500e6, address(usdc));
    }

    function test_withdrawLiquidity_unsupportedAsset_noOp() public {
        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(100e18, address(collateralToken));
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


