// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { UsdsUsdcPocket }   from "src/pockets/UsdsUsdcPocket.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

contract UsdsSwapScenarioTestBase is Test {

    address public owner      = makeAddr("owner");
    address public grove      = makeAddr("grove");
    address public groveProxy = makeAddr("groveProxy");

    GroveBasin     public groveBasin;
    UsdsUsdcPocket public pocket;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public jtrsy;

    MockRateProvider public usdsRateProvider;
    MockRateProvider public usdcRateProvider;
    MockRateProvider public jtrsyRateProvider;

    MockPSM public psm;

    function setUp() public virtual {
        usds  = new MockERC20("USDS",  "USDS",  18);
        usdc  = new MockERC20("USDC",  "USDC",  6);
        jtrsy = new MockERC20("JTRSY", "JTRSY", 18);

        usdsRateProvider  = new MockRateProvider();
        usdcRateProvider  = new MockRateProvider();
        jtrsyRateProvider = new MockRateProvider();

        usdsRateProvider.__setConversionRate(1e27);
        usdcRateProvider.__setConversionRate(1e27);
        jtrsyRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            grove,           // liquidityProvider
            address(usds),   // swapToken
            address(usdc),   // collateralToken
            address(jtrsy),  // creditToken
            address(usdsRateProvider),
            address(usdcRateProvider),
            address(jtrsyRateProvider)
        );

        psm = new MockPSM(address(usds), address(usdc));

        usds.mint(address(psm), 1_000_000_000e18);
        usdc.mint(address(psm), 1_000_000e6);

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm),
            groveProxy
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(),      owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),            owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();

    }

}

contract UsdsSwapScenarioTests is UsdsSwapScenarioTestBase {

    address public user = makeAddr("user");

    function test_swapJtrsyForUsdc_groveDepositsUsdsOnly() public {
        // Grove deposits 10,000 USDS as the sole LP
        uint256 groveDepositAmount = 10_000e18;

        vm.startPrank(grove);
        usds.mint(grove, groveDepositAmount);
        usds.approve(address(groveBasin), groveDepositAmount);
        groveBasin.deposit(address(usds), grove, groveDepositAmount);
        vm.stopPrank();

        // Pocket holds USDS; withdrawLiquidity converts USDS -> USDC via PSM on demand
        assertEq(usds.balanceOf(address(pocket)), groveDepositAmount);
        assertEq(usdc.balanceOf(address(pocket)), 0);

        // User swaps 100 JTRSY -> USDC
        // 1 JTRSY = $1.25, 1 USDC = $1 => 100 JTRSY = 125 USDC
        uint256 jtrsyAmountIn   = 100e18;
        uint256 expectedUsdcOut = 125e6;

        jtrsy.mint(user, jtrsyAmountIn);

        vm.startPrank(user);
        jtrsy.approve(address(groveBasin), jtrsyAmountIn);

        uint256 amountOut = groveBasin.swapExactIn(
            address(jtrsy),
            address(usdc),
            jtrsyAmountIn,
            expectedUsdcOut,
            user,
            0
        );
        vm.stopPrank();

        assertEq(amountOut, expectedUsdcOut);
        assertEq(usdc.balanceOf(user), expectedUsdcOut);
        assertEq(jtrsy.balanceOf(user), 0);
    }

    function test_totalAssets_afterGroveDepositsUsdsOnly() public {
        uint256 groveDepositAmount = 10_000e18;

        vm.startPrank(grove);
        usds.mint(grove, groveDepositAmount);
        usds.approve(address(groveBasin), groveDepositAmount);
        groveBasin.deposit(address(usds), grove, groveDepositAmount);
        vm.stopPrank();

        // USDS rate = 1e27, precision = 1e18
        assertEq(groveBasin.totalAssets(), groveDepositAmount);

        // Shares match 1:1
        assertEq(groveBasin.shares(grove), groveDepositAmount);
        assertEq(groveBasin.totalShares(), groveDepositAmount);
    }

}
