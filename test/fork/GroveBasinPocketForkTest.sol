// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { GroveBasinPocket } from "src/GroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM3 }        from "test/mocks/MockPSM3.sol";
import { MockAaveV3Pool }  from "test/mocks/MockAaveV3Pool.sol";

abstract contract GroveBasinPocketForkTestBase is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");

    GroveBasin       public groveBasin;
    GroveBasinPocket public pocket;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM3       public mockPsm3;
    MockERC20      public mockAUsdt;
    MockAaveV3Pool public mockAaveV3Pool;

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1e27);

        // swapToken = USDC, collateralToken = USDT, creditToken = USDS
        groveBasin = new GroveBasin(
            owner,
            Ethereum.USDC,
            Ethereum.USDT,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        // Deploy mock PSM3 for USDS -> USDC swaps
        mockPsm3 = new MockPSM3(Ethereum.USDS, Ethereum.USDC);
        deal(Ethereum.USDC, address(mockPsm3), 10_000_000e6);

        // Deploy mock aUSDT and Aave pool for USDT withdrawals
        mockAUsdt      = new MockERC20("aUSDT", "aUSDT", 6);
        mockAaveV3Pool = new MockAaveV3Pool(address(mockAUsdt), Ethereum.USDT);

        // Fund mock Aave pool with real USDT for withdrawals and aUSDT for supply
        deal(Ethereum.USDT, address(mockAaveV3Pool), 10_000_000e6);
        mockAUsdt.mint(address(mockAaveV3Pool), 10_000_000e6);

        pocket = new GroveBasinPocket(
            address(groveBasin),
            manager,
            Ethereum.USDC,
            Ethereum.USDT,
            Ethereum.USDS,
            address(mockAUsdt),
            address(mockPsm3),
            address(mockAaveV3Pool)
        );

        vm.prank(owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket));

        // NOTE: GroveBasinPocket constructor already approves basin for USDC and USDT
    }

    function _getBlock() internal pure virtual returns (uint256) {
        return 24_522_338;
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        deal(asset, user, amount);
        vm.startPrank(user);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** Deployment tests                                                                       ***/
/**********************************************************************************************/

contract GroveBasinPocketForkTest_Deployment is GroveBasinPocketForkTestBase {

    function test_deployment() public view {
        assertEq(pocket.basin(),      address(groveBasin));
        assertEq(pocket.manager(),    manager);
        assertEq(address(pocket.usdc()),  Ethereum.USDC);
        assertEq(address(pocket.usdt()),  Ethereum.USDT);
        assertEq(address(pocket.usds()),  Ethereum.USDS);
        assertEq(pocket.psm3(),       address(mockPsm3));
        assertEq(pocket.aaveV3Pool(), address(mockAaveV3Pool));
        assertEq(groveBasin.pocket(), address(pocket));
    }

}

/**********************************************************************************************/
/*** USDC drawLiquidity via PSM3 tests                                                      ***/
/**********************************************************************************************/

contract GroveBasinPocketForkTest_DrawLiquidityUsdc is GroveBasinPocketForkTestBase {

    function test_drawLiquidity_usdc_swapsUsdsForUsdc() public {
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(1000e6, Ethereum.USDC);

        // drawLiquidity only converts, pocket now has USDC
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 1000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 9000e18);
    }

    function test_drawLiquidity_usdc_existingBalancePartialSwap() public {
        deal(Ethereum.USDC, address(pocket), 400e6);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(1000e6, Ethereum.USDC);

        // Pocket now has 400 + 600 = 1000 USDC
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 1000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 9400e18);
    }

    function test_drawLiquidity_usdc_fullBalanceNoSwap() public {
        deal(Ethereum.USDC, address(pocket), 5000e6);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(1000e6, Ethereum.USDC);

        // No swap needed, balance unchanged
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 5000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 10_000e18);
    }

}

/**********************************************************************************************/
/*** USDT drawLiquidity via Aave V3 tests (mocked Aave)                                    ***/
/**********************************************************************************************/

contract GroveBasinPocketForkTest_DrawLiquidityUsdt is GroveBasinPocketForkTestBase {

    function test_drawLiquidity_usdt_withdrawsFromAave() public {
        mockAUsdt.mint(address(pocket), 10_000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(1000e6, Ethereum.USDT);

        // Pocket received USDT from mock Aave withdrawal
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 1000e6);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 9000e6);
    }

    function test_drawLiquidity_usdt_existingBalancePartialWithdraw() public {
        deal(Ethereum.USDT, address(pocket), 400e6);
        mockAUsdt.mint(address(pocket), 10_000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(1000e6, Ethereum.USDT);

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 1000e6);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 9400e6);
    }

    function test_drawLiquidity_usdt_fullBalanceNoWithdraw() public {
        deal(Ethereum.USDT, address(pocket), 5000e6);
        mockAUsdt.mint(address(pocket), 10_000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(1000e6, Ethereum.USDT);

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 5000e6);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 10_000e6);
    }

}

/**********************************************************************************************/
/*** End-to-end swap tests with pocket                                                      ***/
/**********************************************************************************************/

contract GroveBasinPocketForkTest_SwapE2E is GroveBasinPocketForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Seed basin with credit tokens (USDS) and collateral tokens (USDT)
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

        // Seed pocket with swap tokens (USDC)
        deal(Ethereum.USDC, address(pocket), 100_000e6);
    }

    function test_swapExactIn_creditToSwapToken_e2e() public {
        uint256 amountIn = 1000e18;
        deal(Ethereum.USDS, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            Ethereum.USDS,
            Ethereum.USDC,
            amountIn,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut, 1000e6);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), 1000e6);
    }

    function test_swapExactIn_creditToCollateralToken_e2e() public {
        uint256 amountIn = 1000e18;
        deal(Ethereum.USDS, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            Ethereum.USDS,
            Ethereum.USDT,
            amountIn,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut, 1000e6);
        assertEq(IERC20(Ethereum.USDT).balanceOf(receiver), 1000e6);
    }

    function test_swapExactOut_creditToSwapToken_e2e() public {
        uint256 amountOut = 1000e6;
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.USDS, Ethereum.USDC, amountOut);

        deal(Ethereum.USDS, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(
            Ethereum.USDS,
            Ethereum.USDC,
            amountOut,
            expectedIn,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_drawsLiquidityFromPsm3WhenPocketLacksUsdc() public {
        // Drain pocket's USDC, seed with USDS instead
        deal(Ethereum.USDC, address(pocket), 0);
        deal(Ethereum.USDS, address(pocket), 100_000e18);

        uint256 amountIn = 1000e18;
        deal(Ethereum.USDS, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            Ethereum.USDS,
            Ethereum.USDC,
            amountIn,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut, 1000e6);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), 1000e6);
        // Pocket spent USDS via PSM3
        assertLt(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 100_000e18);
    }

    function test_swapExactIn_drawsLiquidityFromAaveWhenBasinLacksUsdt() public {
        // Drain basin's USDT
        deal(Ethereum.USDT, address(groveBasin), 0);

        // Give pocket aUSDT for Aave withdrawal
        mockAUsdt.mint(address(pocket), 100_000e6);

        // Re-deposit USDT to basin for accounting
        _deposit(Ethereum.USDT, makeAddr("lp3"), 100_000e6);

        uint256 amountIn = 1000e18;
        deal(Ethereum.USDS, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            Ethereum.USDS,
            Ethereum.USDT,
            amountIn,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut, 1000e6);
        assertEq(IERC20(Ethereum.USDT).balanceOf(receiver), 1000e6);
    }

}
