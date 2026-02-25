// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { GroveBasinPocket }  from "src/GroveBasinPocket.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM3 }        from "test/mocks/MockPSM3.sol";
import { MockAaveV3Pool }  from "test/mocks/MockAaveV3Pool.sol";

contract GroveBasinPocketTestBase is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");

    GroveBasin       public groveBasin;
    GroveBasinPocket public pocket;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public usdt;
    MockERC20 public aUsdt;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM3       public psm3;
    MockAaveV3Pool public aaveV3Pool;

    function setUp() public virtual {
        usds        = new MockERC20("USDS",  "USDS",  18);
        usdc        = new MockERC20("USDC",  "USDC",  6);
        usdt        = new MockERC20("USDT",  "USDT",  6);
        aUsdt       = new MockERC20("aUSDT", "aUSDT", 6);
        creditToken = new MockERC20("CREDIT", "CREDIT", 18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(usdc),
            address(usdt),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        psm3       = new MockPSM3(address(usds), address(usdc));
        aaveV3Pool = new MockAaveV3Pool(address(aUsdt), address(usdt));

        // Fund MockAaveV3Pool with underlying USDT for withdrawals
        usdt.mint(address(aaveV3Pool), 1_000_000_000e6);

        pocket = new GroveBasinPocket(
            address(groveBasin),
            manager,
            address(usdc),
            address(usdt),
            address(usds),
            address(aUsdt),
            address(psm3),
            address(aaveV3Pool)
        );

        vm.prank(owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket));

        // Pocket approves GroveBasin to pull swapToken (USDC)
        vm.prank(address(pocket));
        usdc.approve(address(groveBasin), type(uint256).max);
    }

}

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract GroveBasinPocketConstructorTests is GroveBasinPocketTestBase {

    function test_constructor_invalidBasin() public {
        vm.expectRevert("GroveBasinPocket/invalid-basin");
        new GroveBasinPocket(address(0), manager, address(usdc), address(usdt), address(usds), address(aUsdt), address(psm3), address(aaveV3Pool));
    }

    function test_constructor_invalidManager() public {
        vm.expectRevert("GroveBasinPocket/invalid-manager");
        new GroveBasinPocket(address(groveBasin), address(0), address(usdc), address(usdt), address(usds), address(aUsdt), address(psm3), address(aaveV3Pool));
    }

    function test_constructor_invalidUsdc() public {
        vm.expectRevert("GroveBasinPocket/invalid-usdc");
        new GroveBasinPocket(address(groveBasin), manager, address(0), address(usdt), address(usds), address(aUsdt), address(psm3), address(aaveV3Pool));
    }

    function test_constructor_invalidUsdt() public {
        vm.expectRevert("GroveBasinPocket/invalid-usdt");
        new GroveBasinPocket(address(groveBasin), manager, address(usdc), address(0), address(usds), address(aUsdt), address(psm3), address(aaveV3Pool));
    }

    function test_constructor_invalidUsds() public {
        vm.expectRevert("GroveBasinPocket/invalid-usds");
        new GroveBasinPocket(address(groveBasin), manager, address(usdc), address(usdt), address(0), address(aUsdt), address(psm3), address(aaveV3Pool));
    }

    function test_constructor_invalidAUsdt() public {
        vm.expectRevert("GroveBasinPocket/invalid-aUsdt");
        new GroveBasinPocket(address(groveBasin), manager, address(usdc), address(usdt), address(usds), address(0), address(psm3), address(aaveV3Pool));
    }

    function test_constructor_invalidPsm3() public {
        vm.expectRevert("GroveBasinPocket/invalid-psm3");
        new GroveBasinPocket(address(groveBasin), manager, address(usdc), address(usdt), address(usds), address(aUsdt), address(0), address(aaveV3Pool));
    }

    function test_constructor_invalidAaveV3Pool() public {
        vm.expectRevert("GroveBasinPocket/invalid-aaveV3Pool");
        new GroveBasinPocket(address(groveBasin), manager, address(usdc), address(usdt), address(usds), address(aUsdt), address(psm3), address(0));
    }

    function test_constructor_success() public view {
        assertEq(pocket.basin(),      address(groveBasin));
        assertEq(pocket.manager(),    manager);
        assertEq(address(pocket.usdc()),  address(usdc));
        assertEq(address(pocket.usdt()),  address(usdt));
        assertEq(address(pocket.usds()),  address(usds));
        assertEq(address(pocket.aUsdt()), address(aUsdt));
        assertEq(pocket.psm3(),       address(psm3));
        assertEq(pocket.aaveV3Pool(), address(aaveV3Pool));

        assertEq(usds.allowance(address(pocket), address(psm3)), type(uint256).max);
        assertEq(aUsdt.allowance(address(pocket), address(aaveV3Pool)), type(uint256).max);
    }

}

/**********************************************************************************************/
/*** drawLiquidity access control tests                                                     ***/
/**********************************************************************************************/

contract GroveBasinPocketAccessControlTests is GroveBasinPocketTestBase {

    function test_drawLiquidity_notBasin() public {
        vm.expectRevert("GroveBasinPocket/not-basin");
        pocket.drawLiquidity(100e6, address(usdc));
    }

    function test_drawLiquidity_notBasin_manager() public {
        vm.prank(manager);
        vm.expectRevert("GroveBasinPocket/not-basin");
        pocket.drawLiquidity(100e6, address(usdc));
    }

}

/**********************************************************************************************/
/*** drawLiquidity USDC tests                                                               ***/
/**********************************************************************************************/

contract GroveBasinPocketDrawLiquidityUsdcTests is GroveBasinPocketTestBase {

    function test_drawLiquidity_usdc_zeroAmount() public {
        vm.prank(address(groveBasin));
        pocket.drawLiquidity(0, address(usdc));
    }

    function test_drawLiquidity_usdc_existingBalanceCoversAll() public {
        usdc.mint(address(pocket), 1000e6);

        uint256 pocketUsdcBefore = usdc.balanceOf(address(pocket));

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(500e6, address(usdc));

        // drawLiquidity only converts, does not transfer
        assertEq(usdc.balanceOf(address(pocket)), pocketUsdcBefore);
    }

    function test_drawLiquidity_usdc_partialBalanceSwapsRemainder() public {
        usdc.mint(address(pocket), 300e6);
        usds.mint(address(pocket), 1000e18);

        // Seed PSM3 with USDC for the swap
        usdc.mint(address(psm3), 1_000_000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(500e6, address(usdc));

        // Pocket now has 300 + 200 = 500 USDC (no transfer to basin)
        assertEq(usdc.balanceOf(address(pocket)), 500e6);
        // PSM3 took 200e6 * 1e12 = 200e18 USDS for the 200e6 USDC remainder
        assertEq(usds.balanceOf(address(pocket)), 1000e18 - 200e18);
    }

    function test_drawLiquidity_usdc_noBalanceSwapsAll() public {
        usds.mint(address(pocket), 1000e18);
        usdc.mint(address(psm3), 1_000_000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(500e6, address(usdc));

        // Pocket has 500 USDC from PSM3 swap (no transfer to basin)
        assertEq(usdc.balanceOf(address(pocket)), 500e6);
        assertEq(usds.balanceOf(address(pocket)), 1000e18 - 500e18);
    }

    function test_drawLiquidity_usdc_emitsEvent() public {
        usds.mint(address(pocket), 1000e18);
        usdc.mint(address(psm3), 1_000_000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdc), 500e6, 500e18);
        pocket.drawLiquidity(500e6, address(usdc));
    }

}

/**********************************************************************************************/
/*** drawLiquidity USDT tests                                                               ***/
/**********************************************************************************************/

contract GroveBasinPocketDrawLiquidityUsdtTests is GroveBasinPocketTestBase {

    function test_drawLiquidity_usdt_zeroAmount() public {
        vm.prank(address(groveBasin));
        pocket.drawLiquidity(0, address(usdt));
    }

    function test_drawLiquidity_usdt_existingBalanceCoversAll() public {
        usdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(500e6, address(usdt));

        // drawLiquidity only converts, does not transfer
        assertEq(usdt.balanceOf(address(pocket)), 1000e6);
    }

    function test_drawLiquidity_usdt_partialBalanceWithdrawsRemainder() public {
        usdt.mint(address(pocket), 300e6);
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(500e6, address(usdt));

        // Pocket has 300 + 200 = 500 USDT (no transfer to basin)
        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 1000e6 - 200e6);
    }

    function test_drawLiquidity_usdt_noBalanceWithdrawsAll() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        pocket.drawLiquidity(500e6, address(usdt));

        // Pocket has 500 USDT from Aave withdrawal (no transfer to basin)
        assertEq(usdt.balanceOf(address(pocket)), 500e6);
        assertEq(aUsdt.balanceOf(address(pocket)), 500e6);
    }

    function test_drawLiquidity_usdt_emitsEvent() public {
        aUsdt.mint(address(pocket), 1000e6);

        vm.prank(address(groveBasin));
        vm.expectEmit(address(pocket));
        emit IGroveBasinPocket.LiquidityDrawn(address(usdt), 500e6, 500e6);
        pocket.drawLiquidity(500e6, address(usdt));
    }

}

/**********************************************************************************************/
/*** drawLiquidity unsupported asset tests                                                  ***/
/**********************************************************************************************/

contract GroveBasinPocketDrawLiquidityUnsupportedTests is GroveBasinPocketTestBase {

    function test_drawLiquidity_unsupportedAsset_noOp() public {
        vm.prank(address(groveBasin));
        pocket.drawLiquidity(100e18, address(creditToken));
    }

}

/**********************************************************************************************/
/*** Integration with GroveBasin swap tests                                                 ***/
/**********************************************************************************************/

contract GroveBasinPocketSwapIntegrationTests is GroveBasinPocketTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Seed the basin with credit tokens and collateral tokens
        creditToken.mint(address(groveBasin), 100_000e18);
        usdt.mint(address(groveBasin), 100_000e6);

        // Seed the pocket with swap tokens (USDC) for the basin
        usdc.mint(address(pocket), 100_000e6);

        // Seed the pocket with aUSDT for drawLiquidity USDT path
        aUsdt.mint(address(pocket), 100_000e6);

        // Seed the pocket with USDS for drawLiquidity USDC path
        usds.mint(address(pocket), 100_000e18);

        // Seed PSM3 with USDC for swaps
        usdc.mint(address(psm3), 1_000_000e6);
    }

    function test_swapExactIn_creditTokenToSwapToken_drawsFromPocket() public {
        creditToken.mint(swapper, 100e18);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 100e18);

        uint256 amountOut = groveBasin.swapExactIn(
            address(creditToken),
            address(usdc),
            100e18,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(usdc.balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_creditTokenToSwapToken_drawsFromPocket() public {
        uint256 amountOut = 100e6;
        uint256 expectedIn = groveBasin.previewSwapExactOut(
            address(creditToken),
            address(usdc),
            amountOut
        );

        creditToken.mint(swapper, expectedIn);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(
            address(creditToken),
            address(usdc),
            amountOut,
            expectedIn,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(usdc.balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_creditTokenToCollateralToken_drawsFromPocket() public {
        creditToken.mint(swapper, 100e18);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 100e18);

        uint256 amountOut = groveBasin.swapExactIn(
            address(creditToken),
            address(usdt),
            100e18,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(usdt.balanceOf(receiver), amountOut);
    }

}
