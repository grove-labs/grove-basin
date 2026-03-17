// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }      from "src/GroveBasin.sol";
import { UsdsUsdcPocket }  from "src/pockets/UsdsUsdcPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

abstract contract UsdsUsdcPocketForkTestBase is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");

    GroveBasin       public groveBasin;
    UsdsUsdcPocket   public pocket;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public mockPsm;

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

        mockPsm = new MockPSM(Ethereum.USDS, Ethereum.USDC);
        deal(Ethereum.USDC, address(mockPsm), 10_000_000e6);
        deal(Ethereum.USDS, address(mockPsm), 10_000_000e18);

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            Ethereum.USDC,
            Ethereum.USDS,
            address(mockPsm)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);
        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();
    }

    function _getBlock() internal pure virtual returns (uint256) {
        return 24_522_338;
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, user);

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

contract UsdsUsdcPocketForkTest_Deployment is UsdsUsdcPocketForkTestBase {

    function test_deployment() public view {
        assertEq(pocket.basin(),      address(groveBasin));
        assertEq(address(pocket.usdc()),  Ethereum.USDC);
        assertEq(address(pocket.usds()),  Ethereum.USDS);
        assertEq(pocket.psm(),       address(mockPsm));
        assertEq(groveBasin.pocket(), address(pocket));
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity USDC tests                                                               ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_DrawLiquidityUsdc is UsdsUsdcPocketForkTestBase {

    function test_withdrawLiquidity_usdc_swapsUsdsForUsdc() public {
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDC);

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 1000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 9000e18);
    }

    function test_withdrawLiquidity_usdc_existingBalancePartialSwap() public {
        deal(Ethereum.USDC, address(pocket), 400e6);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDC);

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 1000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 9400e18);
    }

    function test_withdrawLiquidity_usdc_fullBalanceNoSwap() public {
        deal(Ethereum.USDC, address(pocket), 5000e6);
        deal(Ethereum.USDS, address(pocket), 10_000e18);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDC);

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 5000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 10_000e18);
    }

}

/**********************************************************************************************/
/*** setPocket migration tests                                                              ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_SetPocket is UsdsUsdcPocketForkTestBase {

    function test_setPocket_withdrawsAllAssetsToNewPocket() public {
        deal(Ethereum.USDS, address(pocket), 5000e18);
        deal(Ethereum.USDC, address(pocket), 1000e6);

        UsdsUsdcPocket pocket2 = new UsdsUsdcPocket(
            address(groveBasin),
            Ethereum.USDC,
            Ethereum.USDS,
            address(mockPsm)
        );

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        // Old pocket should be empty
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 0);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 0);

        // USDS converted to USDC via PSM, total = 1000 + 5000 = 6000 USDC
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket2)), 6000e6);
        assertEq(groveBasin.pocket(), address(pocket2));
    }

}

/**********************************************************************************************/
/*** End-to-end swap tests                                                                  ***/
/**********************************************************************************************/

contract UsdsUsdcPocketForkTest_SwapE2E is UsdsUsdcPocketForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

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

    function test_swapExactIn_drawsLiquidityFromPsmWhenPocketLacksUsdc() public {
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
        assertLt(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 100_000e18);
    }

}
