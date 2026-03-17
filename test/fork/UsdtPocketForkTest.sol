// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }  from "src/GroveBasin.sol";
import { UsdtPocket }  from "src/UsdtPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAaveV3Pool }  from "test/mocks/MockAaveV3Pool.sol";

abstract contract UsdtPocketForkTestBase is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");

    GroveBasin     public groveBasin;
    UsdtPocket     public pocket;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

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

        // swapToken = USDT, collateralToken = USDC, creditToken = USDS
        groveBasin = new GroveBasin(
            owner,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        mockAUsdt      = new MockERC20("aUSDT", "aUSDT", 6);
        mockAaveV3Pool = new MockAaveV3Pool(address(mockAUsdt), Ethereum.USDT);

        deal(Ethereum.USDT, address(mockAaveV3Pool), 10_000_000e6);
        mockAUsdt.mint(address(mockAaveV3Pool), 10_000_000e6);

        pocket = new UsdtPocket(
            address(groveBasin),
            manager,
            Ethereum.USDT,
            address(mockAUsdt),
            address(mockAaveV3Pool)
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

contract UsdtPocketForkTest_Deployment is UsdtPocketForkTestBase {

    function test_deployment() public view {
        assertEq(pocket.basin(),      address(groveBasin));
        assertEq(pocket.manager(),    manager);
        assertEq(address(pocket.usdt()),  Ethereum.USDT);
        assertEq(pocket.aaveV3Pool(), address(mockAaveV3Pool));
        assertEq(groveBasin.pocket(), address(pocket));
    }

}

/**********************************************************************************************/
/*** withdrawLiquidity tests                                                                    ***/
/**********************************************************************************************/

contract UsdtPocketForkTest_DrawLiquidity is UsdtPocketForkTestBase {

    function test_withdrawLiquidity_withdrawsFromAave() public {
        mockAUsdt.mint(address(pocket), 10_000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDT);

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 1000e6);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 9000e6);
    }

    function test_withdrawLiquidity_existingBalancePartialWithdraw() public {
        deal(Ethereum.USDT, address(pocket), 400e6);
        mockAUsdt.mint(address(pocket), 10_000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDT);

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 1000e6);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 9400e6);
    }

    function test_withdrawLiquidity_fullBalanceNoWithdraw() public {
        deal(Ethereum.USDT, address(pocket), 5000e6);
        mockAUsdt.mint(address(pocket), 10_000e6);

        vm.prank(address(groveBasin));
        pocket.withdrawLiquidity(1000e6, Ethereum.USDT);

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 5000e6);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 10_000e6);
    }

}

/**********************************************************************************************/
/*** setPocket migration tests                                                              ***/
/**********************************************************************************************/

contract UsdtPocketForkTest_SetPocket is UsdtPocketForkTestBase {

    function test_setPocket_migratesUsdtToNewPocket() public {
        deal(Ethereum.USDT, address(pocket), 500e6);
        mockAUsdt.mint(address(pocket), 1000e6);

        UsdtPocket pocket2 = new UsdtPocket(
            address(groveBasin),
            manager,
            Ethereum.USDT,
            address(mockAUsdt),
            address(mockAaveV3Pool)
        );

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket)), 0);
        assertEq(mockAUsdt.balanceOf(address(pocket)), 0);
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket2)), 1500e6);
        assertEq(groveBasin.pocket(), address(pocket2));
    }

}

/**********************************************************************************************/
/*** End-to-end swap tests                                                                  ***/
/**********************************************************************************************/

contract UsdtPocketForkTest_SwapE2E is UsdtPocketForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);
    }

    function test_swapExactIn_creditToSwapToken_e2e() public {
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
