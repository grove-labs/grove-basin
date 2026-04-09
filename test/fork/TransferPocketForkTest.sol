// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";
import { MockERC20 } from "erc20-helpers/MockERC20.sol";
import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }         from "src/GroveBasin.sol";
import { AaveV3UsdtPocket }   from "src/pockets/AaveV3UsdtPocket.sol";
import { MorphoUsdtPocket }   from "src/pockets/MorphoUsdtPocket.sol";
import { UsdsUsdcPocket }     from "src/pockets/UsdsUsdcPocket.sol";
import { IGroveBasin }        from "src/interfaces/IGroveBasin.sol";

import { MockRateProvider }  from "test/mocks/MockRateProvider.sol";
import { MockAaveV3Pool }   from  "test/mocks/MockAaveV3Pool.sol";
import { MockERC4626Vault } from  "test/mocks/MockERC4626Vault.sol";
import { MockPSM }          from  "test/mocks/MockPSM.sol";

/**********************************************************************************************/
/*** Base for USDT basin transfer pocket tests                                              ***/
/**********************************************************************************************/

abstract contract TransferPocketForkTestBase is Test {

    using SafeERC20 for IERC20;

    address public owner      = makeAddr("owner");
    address public lp         = makeAddr("liquidityProvider");
    address public admin      = makeAddr("admin");
    address public groveProxy = makeAddr("groveProxy");

    GroveBasin public groveBasin;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;
    MockERC20        public mockAUsdt;
    MockAaveV3Pool   public mockAaveV3Pool;
    MockERC4626Vault public mockVault;

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
            lp,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        // Set up mock Aave
        mockAUsdt      = new MockERC20("aUSDT", "aUSDT", 6);
        mockAaveV3Pool = new MockAaveV3Pool(address(mockAUsdt), Ethereum.USDT);

        deal(Ethereum.USDT, address(mockAaveV3Pool), 1_000_000_000e6);
        mockAUsdt.mint(address(mockAaveV3Pool), 1_000_000_000e6);

        // Set up mock ERC4626 vault
        mockVault = new MockERC4626Vault(Ethereum.USDT);
        deal(Ethereum.USDT, address(mockVault), 1_000_000_000e6);

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),      owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        vm.stopPrank();
    }

    function _getBlock() internal pure virtual returns (uint256) {
        return 24_522_338;
    }

    function _createAavePocket() internal returns (AaveV3UsdtPocket) {
        return new AaveV3UsdtPocket(
            address(groveBasin),
            Ethereum.USDT,
            address(mockAUsdt),
            address(mockAaveV3Pool)
        );
    }

    function _createMorphoPocket() internal returns (MorphoUsdtPocket) {
        return new MorphoUsdtPocket(
            address(groveBasin),
            Ethereum.USDT,
            address(mockVault)
        );
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        address lp_ = groveBasin.liquidityProvider();
        vm.startPrank(lp_);
        deal(asset, lp_, amount);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

    function _withdraw(address asset, address user, uint256 amount) internal {
        vm.prank(user);
        groveBasin.withdraw(asset, user, amount);
    }

}

/**********************************************************************************************/
/*** No pocket → AaveV3UsdtPocket                                                          ***/
/**********************************************************************************************/

contract TransferPocketForkTest_NoPocketToAave is TransferPocketForkTestBase {

    function test_setPocket_noPocketToAave_transfersUsdt() public {
        // Basin holds USDT directly (no pocket set)
        deal(Ethereum.USDT, address(groveBasin), 10_000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(groveBasin), address(aavePocket), 10_000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Basin should have zero USDT
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 0);
        // New pocket has the full balance
        assertEq(aavePocket.availableBalance(Ethereum.USDT), 10_000e6);
        // totalAssets strictly equal
        assertEq(totalAssetsAfter, totalAssetsBefore);
        // Pocket correctly set
        assertEq(groveBasin.pocket(), address(aavePocket));
    }

}

/**********************************************************************************************/
/*** No pocket → MorphoUsdtPocket                                                          ***/
/**********************************************************************************************/

contract TransferPocketForkTest_NoPocketToMorpho is TransferPocketForkTestBase {

    function test_setPocket_noPocketToMorpho_transfersUsdt() public {
        deal(Ethereum.USDT, address(groveBasin), 10_000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(groveBasin), address(morphoPocket), 10_000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 0);
        assertEq(morphoPocket.availableBalance(Ethereum.USDT), 10_000e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
        assertEq(groveBasin.pocket(), address(morphoPocket));
    }

}

/**********************************************************************************************/
/*** AaveV3UsdtPocket → MorphoUsdtPocket                                                   ***/
/**********************************************************************************************/

contract TransferPocketForkTest_AaveToMorpho is TransferPocketForkTestBase {

    AaveV3UsdtPocket public aavePocket;

    function setUp() public override {
        super.setUp();

        aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));
    }

    function test_setPocket_aaveToMorpho_transfersAllFunds() public {
        // Deposit into Aave pocket (USDT goes to pocket, then Aave via depositLiquidity)
        deal(Ethereum.USDT, address(aavePocket), 500e6);
        mockAUsdt.mint(address(aavePocket), 1000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(aavePocket), address(morphoPocket), 1500e6);

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero USDT and zero aUSDT — NO DUST
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(aavePocket)), 0);
        assertEq(mockAUsdt.balanceOf(address(aavePocket)), 0);
        // New pocket has the full balance
        assertEq(morphoPocket.availableBalance(Ethereum.USDT), 1500e6);
        // totalAssets strictly equal
        assertEq(totalAssetsAfter, totalAssetsBefore);
        assertEq(groveBasin.pocket(), address(morphoPocket));
    }

}

/**********************************************************************************************/
/*** MorphoUsdtPocket → AaveV3UsdtPocket                                                   ***/
/**********************************************************************************************/

contract TransferPocketForkTest_MorphoToAave is TransferPocketForkTestBase {

    MorphoUsdtPocket public morphoPocket;

    function setUp() public override {
        super.setUp();

        morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));
    }

    function test_setPocket_morphoToAave_transfersAllFunds() public {
        // Simulate funds in Morpho pocket: some USDT + some in vault
        deal(Ethereum.USDT, address(morphoPocket), 500e6);

        // Deposit USDT into vault to simulate vault shares
        vm.startPrank(address(morphoPocket));
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(mockVault), 0);
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(mockVault), 500e6);
        mockVault.deposit(500e6, address(morphoPocket));
        vm.stopPrank();

        // Now pocket has 0 USDT + 500e6 vault shares (= 500e6 USDT value)
        // Give pocket more USDT to have a mixed balance
        deal(Ethereum.USDT, address(morphoPocket), 300e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(morphoPocket), address(aavePocket), 800e6);

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero USDT and zero vault shares — NO DUST
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(morphoPocket)), 0);
        assertEq(mockVault.balanceOf(address(morphoPocket)), 0);
        // New pocket has the full balance
        assertEq(aavePocket.availableBalance(Ethereum.USDT), 800e6);
        // totalAssets strictly equal
        assertEq(totalAssetsAfter, totalAssetsBefore);
        assertEq(groveBasin.pocket(), address(aavePocket));
    }

}

/**********************************************************************************************/
/*** Same-type migrations                                                                   ***/
/**********************************************************************************************/

contract TransferPocketForkTest_SameType is TransferPocketForkTestBase {

    function test_setPocket_aaveToAave_transfersAllFunds() public {
        AaveV3UsdtPocket pocket1 = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        deal(Ethereum.USDT, address(pocket1), 500e6);
        mockAUsdt.mint(address(pocket1), 1000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        AaveV3UsdtPocket pocket2 = _createAavePocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(pocket1), address(pocket2), 1500e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero USDT and zero aUSDT
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket1)), 0);
        assertEq(mockAUsdt.balanceOf(address(pocket1)), 0);
        // New pocket has the full balance
        assertEq(pocket2.availableBalance(Ethereum.USDT), 1500e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

    function test_setPocket_morphoToMorpho_transfersAllFunds() public {
        MorphoUsdtPocket pocket1 = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        // Deposit into vault through pocket
        deal(Ethereum.USDT, address(pocket1), 1000e6);
        vm.startPrank(address(pocket1));
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(mockVault), 0);
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(mockVault), 700e6);
        mockVault.deposit(700e6, address(pocket1));
        vm.stopPrank();

        // pocket1 has 300 USDT + 700 in vault = 1000 total
        uint256 totalAssetsBefore = groveBasin.totalAssets();

        MorphoUsdtPocket pocket2 = _createMorphoPocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(pocket1), address(pocket2), 1000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero USDT and zero vault shares
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(pocket1)), 0);
        assertEq(mockVault.balanceOf(address(pocket1)), 0);
        // New pocket has the full balance
        assertEq(pocket2.availableBalance(Ethereum.USDT), 1000e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

}

/**********************************************************************************************/
/*** Post-migration operation tests                                                         ***/
/**********************************************************************************************/

contract TransferPocketForkTest_PostMigrationOps is TransferPocketForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function test_swapAfterAaveToMorphoMigration() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Deposit liquidity
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

        // Migrate Aave → Morpho
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // Execute swap with new pocket
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

    function test_swapAfterMorphoToAaveMigration() public {
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // Deposit liquidity
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

        // Migrate Morpho → Aave
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Execute swap with new pocket
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

/**********************************************************************************************/
/*** Edge cases                                                                             ***/
/**********************************************************************************************/

contract TransferPocketForkTest_EdgeCases is TransferPocketForkTestBase {

    function test_setPocket_zeroBalance_noPocketToAave() public {
        // Clear seed deposit balance so basin truly has zero USDT
        deal(Ethereum.USDT, address(groveBasin), 0);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(groveBasin), address(aavePocket), 0);

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 0);
        assertEq(aavePocket.availableBalance(Ethereum.USDT), 0);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

    function test_setPocket_zeroBalance_aaveToMorpho() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Clear seed deposit balance so pocket truly has zero
        deal(Ethereum.USDT, address(aavePocket), 0);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(aavePocket)), 0);
        assertEq(mockAUsdt.balanceOf(address(aavePocket)), 0);
        assertEq(morphoPocket.availableBalance(Ethereum.USDT), 0);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

    function test_setPocket_largeBalance_noPocketToAave() public {
        uint256 largeAmount = 100_000_000e6; // 100M USDT
        deal(Ethereum.USDT, address(groveBasin), largeAmount);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 0);
        assertEq(aavePocket.availableBalance(Ethereum.USDT), largeAmount);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

    function test_setPocket_largeBalance_aaveToMorpho() public {
        uint256 largeAmount = 100_000_000e6; // 100M USDT
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Give pocket large amount in Aave
        deal(Ethereum.USDT, address(aavePocket), largeAmount / 2);
        mockAUsdt.mint(address(aavePocket), largeAmount / 2);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(aavePocket)), 0);
        assertEq(mockAUsdt.balanceOf(address(aavePocket)), 0);
        assertEq(morphoPocket.availableBalance(Ethereum.USDT), largeAmount);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

}

/**********************************************************************************************/
/*** Reverse migrations (pocket → no-pocket / back to basin)                                ***/
/**********************************************************************************************/

contract TransferPocketForkTest_ReverseMigrations is TransferPocketForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function test_setPocket_aaveToBasin_withdrawsAllToBasin() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Fund the pocket
        deal(Ethereum.USDT, address(aavePocket), 500e6);
        mockAUsdt.mint(address(aavePocket), 1000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(aavePocket), address(groveBasin), 1500e6);

        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero everything
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(aavePocket)), 0);
        assertEq(mockAUsdt.balanceOf(address(aavePocket)), 0);
        // Basin holds USDT directly
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 1500e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
        // No pocket set (_hasPocket() returns false)
        assertEq(groveBasin.pocket(), address(groveBasin));
    }

    function test_setPocket_morphoToBasin_withdrawsAllToBasin() public {
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // Fund the pocket with vault shares
        deal(Ethereum.USDT, address(morphoPocket), 1000e6);
        vm.startPrank(address(morphoPocket));
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(mockVault), 0);
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(mockVault), 700e6);
        mockVault.deposit(700e6, address(morphoPocket));
        vm.stopPrank();

        // pocket has 300 USDT + 700 in vault = 1000 total
        uint256 totalAssetsBefore = groveBasin.totalAssets();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(morphoPocket), address(groveBasin), 1000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero everything
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(morphoPocket)), 0);
        assertEq(mockVault.balanceOf(address(morphoPocket)), 0);
        // Basin holds USDT directly
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 1000e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
        assertEq(groveBasin.pocket(), address(groveBasin));
    }

    function test_setPocket_aaveToBasin_postMigrationOpsWork() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Deposit liquidity into basin
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

        // Migrate back to basin
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        // Swap should work without a pocket
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

        // Deposit/withdraw should also work
        _deposit(Ethereum.USDT, makeAddr("lp3"), 5_000e6);
        _withdraw(Ethereum.USDT, makeAddr("lp3"), 2_000e6);
        assertEq(IERC20(Ethereum.USDT).balanceOf(makeAddr("lp3")), 2_000e6);
    }

    function test_setPocket_morphoToBasin_postMigrationOpsWork() public {
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // Deposit liquidity
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

        // Migrate back to basin
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        // Swap should work
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

/**********************************************************************************************/
/*** Sequential multi-migration                                                             ***/
/**********************************************************************************************/

contract TransferPocketForkTest_SequentialMigration is TransferPocketForkTestBase {

    function test_sequentialMigration_noPocket_aave_morpho_aave() public {
        // Start with funds in basin (no pocket)
        deal(Ethereum.USDT, address(groveBasin), 50_000e6);

        uint256 totalAssetsStep0 = groveBasin.totalAssets();

        // Step 1: No pocket → AaveV3
        AaveV3UsdtPocket aavePocket1 = _createAavePocket();
        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket1));

        uint256 totalAssetsStep1 = groveBasin.totalAssets();
        assertEq(totalAssetsStep1, totalAssetsStep0);
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(groveBasin)), 0);
        assertEq(aavePocket1.availableBalance(Ethereum.USDT), 50_000e6);

        // Step 2: AaveV3 → Morpho
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();
        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        uint256 totalAssetsStep2 = groveBasin.totalAssets();
        assertEq(totalAssetsStep2, totalAssetsStep0);
        // Old pocket has zero
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(aavePocket1)), 0);
        assertEq(mockAUsdt.balanceOf(address(aavePocket1)), 0);
        assertEq(morphoPocket.availableBalance(Ethereum.USDT), 50_000e6);

        // Step 3: Morpho → AaveV3
        AaveV3UsdtPocket aavePocket2 = _createAavePocket();
        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket2));

        uint256 totalAssetsStep3 = groveBasin.totalAssets();
        assertEq(totalAssetsStep3, totalAssetsStep0);
        // Old pocket has zero
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(morphoPocket)), 0);
        assertEq(mockVault.balanceOf(address(morphoPocket)), 0);
        // New pocket has the full balance, no cumulative dust
        assertEq(aavePocket2.availableBalance(Ethereum.USDT), 50_000e6);
    }

}

/**********************************************************************************************/
/*** Round-trip: deposit → migrate → withdraw                                               ***/
/**********************************************************************************************/

contract TransferPocketForkTest_RoundTrip is TransferPocketForkTestBase {

    function test_roundTrip_depositMigrateWithdraw() public {
        address lp = makeAddr("lp");
        uint256 depositAmount = 10_000e6;

        // Start with Aave pocket
        AaveV3UsdtPocket aavePocket = _createAavePocket();
        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // LP deposits USDT
        _deposit(Ethereum.USDT, lp, depositAmount);

        uint256 lpShares = groveBasin.shares(lp);
        assertTrue(lpShares > 0);

        // Migrate to Morpho
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();
        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // LP withdraws full balance (pass large amount, withdraw caps to available)
        _withdraw(Ethereum.USDT, lp, depositAmount);

        uint256 recoveredAmount = IERC20(Ethereum.USDT).balanceOf(lp);

        // Recovered amount == deposited amount (within 1 wei rounding)
        assertApproxEqAbs(recoveredAmount, depositAmount, 1);
    }

}

/**********************************************************************************************/
/*** Manager-deposited funds in migration                                                   ***/
/**********************************************************************************************/

contract TransferPocketForkTest_ManagerDeposit is TransferPocketForkTestBase {

    function test_setPocket_managerDepositedFundsIncludedInMigration() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // LP deposits via basin
        _deposit(Ethereum.USDT, makeAddr("lp"), 5_000e6);

        // Manager deposits directly to pocket (bypassing basin)
        address pocketManager = makeAddr("pocketManager");

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), pocketManager);
        vm.stopPrank();

        uint256 managerAmount = 3_000e6;
        deal(Ethereum.USDT, address(aavePocket), managerAmount);

        vm.prank(pocketManager);
        aavePocket.depositLiquidity(managerAmount, Ethereum.USDT);

        // Verify pocket has both LP and manager funds
        uint256 totalPocketBalance = aavePocket.availableBalance(Ethereum.USDT);
        assertEq(totalPocketBalance, 8_000e6); // 5000 + 3000

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        // Migrate to Morpho
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // Manager-deposited funds are included in migration
        assertEq(morphoPocket.availableBalance(Ethereum.USDT), 8_000e6);

        // Old pocket has zero balance
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(aavePocket)), 0);
        assertEq(mockAUsdt.balanceOf(address(aavePocket)), 0);

        // totalAssets still strictly equal
        assertEq(groveBasin.totalAssets(), totalAssetsBefore);
    }

}

/**********************************************************************************************/
/*** Token approval chain verification                                                      ***/
/**********************************************************************************************/

contract TransferPocketForkTest_ApprovalChain is TransferPocketForkTestBase {

    function test_approvalChain_afterNoPocketToAave() public {
        deal(Ethereum.USDT, address(groveBasin), 10_000e6);

        AaveV3UsdtPocket aavePocket = _createAavePocket();

        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        // Verify approval: newPocket approves basin for max
        assertEq(
            IERC20(Ethereum.USDT).allowance(address(aavePocket), address(groveBasin)),
            type(uint256).max
        );
    }

    function test_approvalChain_afterAaveToMorpho() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();
        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        deal(Ethereum.USDT, address(aavePocket), 1000e6);

        MorphoUsdtPocket morphoPocket = _createMorphoPocket();
        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        assertEq(
            IERC20(Ethereum.USDT).allowance(address(morphoPocket), address(groveBasin)),
            type(uint256).max
        );
    }

    function test_approvalChain_afterMorphoToAave() public {
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();
        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        deal(Ethereum.USDT, address(morphoPocket), 1000e6);

        AaveV3UsdtPocket aavePocket = _createAavePocket();
        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        assertEq(
            IERC20(Ethereum.USDT).allowance(address(aavePocket), address(groveBasin)),
            type(uint256).max
        );
    }

    function test_approvalChain_swapWorksAfterMigration() public {
        AaveV3UsdtPocket aavePocket = _createAavePocket();
        vm.prank(owner);
        groveBasin.setPocket(address(aavePocket));

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDT, makeAddr("lp2"), 100_000e6);

        // Migrate to morpho
        MorphoUsdtPocket morphoPocket = _createMorphoPocket();
        vm.prank(owner);
        groveBasin.setPocket(address(morphoPocket));

        // The swap proves the approval chain works (basin can transferFrom pocket)
        address swapper  = makeAddr("swapper");
        address receiver = makeAddr("receiver");
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

/**********************************************************************************************/
/*** USDC Basin Transitions (UsdsUsdcPocket)                                                ***/
/**********************************************************************************************/

abstract contract TransferPocketForkTestBase_USDC is Test {

    using SafeERC20 for IERC20;

    address public owner      = makeAddr("owner");
    address public lp         = makeAddr("liquidityProvider");
    address public admin      = makeAddr("admin");
    address public groveProxy = makeAddr("groveProxy");

    GroveBasin public groveBasin;

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
            lp,
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

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        vm.stopPrank();
    }

    function _getBlock() internal pure virtual returns (uint256) {
        return 24_522_338;
    }

    function _createUsdcPocket() internal returns (UsdsUsdcPocket) {
        return new UsdsUsdcPocket(
            address(groveBasin),
            Ethereum.USDC,
            Ethereum.USDS,
            address(mockPsm),
            groveProxy
        );
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        address lp_ = groveBasin.liquidityProvider();
        vm.startPrank(lp_);
        deal(asset, lp_, amount);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** No pocket → UsdsUsdcPocket                                                            ***/
/**********************************************************************************************/

contract TransferPocketForkTest_NoPocketToUsdc is TransferPocketForkTestBase_USDC {

    function test_setPocket_noPocketToUsdc_transfersUsdc() public {
        deal(Ethereum.USDC, address(groveBasin), 10_000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        UsdsUsdcPocket usdcPocket = _createUsdcPocket();

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(groveBasin), address(usdcPocket), 10_000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(usdcPocket));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(groveBasin)), 0);
        assertEq(usdcPocket.availableBalance(Ethereum.USDC), 10_000e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
        assertEq(groveBasin.pocket(), address(usdcPocket));
    }

}

/**********************************************************************************************/
/*** UsdsUsdcPocket → UsdsUsdcPocket (same-type migration)                                  ***/
/**********************************************************************************************/

contract TransferPocketForkTest_UsdcToUsdc is TransferPocketForkTestBase_USDC {

    function test_setPocket_usdcToUsdc_transfersAllFunds() public {
        UsdsUsdcPocket pocket1 = _createUsdcPocket();

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        // Fund the pocket with USDC and USDS
        deal(Ethereum.USDC, address(pocket1), 1000e6);
        deal(Ethereum.USDS, address(pocket1), 5000e18);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        UsdsUsdcPocket pocket2 = _createUsdcPocket();

        // USDS is converted to USDC via PSM, so total = 1000 + 5000 = 6000 USDC
        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.PocketSet(address(pocket1), address(pocket2), 6000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        uint256 totalAssetsAfter = groveBasin.totalAssets();

        // Old pocket: zero USDC and zero USDS
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket1)), 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket1)), 0);
        // New pocket has the full balance (as USDC since PSM converted USDS→USDC)
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket2)), 6000e6);
        assertEq(totalAssetsAfter, totalAssetsBefore);
    }

}
