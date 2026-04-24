// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }  from "src/GroveBasin.sol";
import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";
import { UsdsUsdcPocket }   from "src/pockets/UsdsUsdcPocket.sol";
import { AaveV3UsdtPocket } from "src/pockets/AaveV3UsdtPocket.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockPocket }         from "test/mocks/MockPocket.sol";
import { MockRateProvider }   from "test/mocks/MockRateProvider.sol";
import { MockPSM }            from "test/mocks/MockPSM.sol";
import { MockAaveV3Pool }     from "test/mocks/MockAaveV3Pool.sol";
import { MockAToken }         from "test/mocks/MockAToken.sol";

contract GroveBasinSetPocketFailureTests is GroveBasinTestBase {

    function test_setPocket_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        groveBasin.setPocket(address(1));
    }

    function test_setPocket_invalidPocket() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidPocket.selector);
        groveBasin.setPocket(address(0));
    }

    function test_setPocket_samePocket() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidPocket.selector);
        groveBasin.setPocket(pocket);
    }

    function test_setPocket_pocketBasinMismatch() public {
        GroveBasin otherBasin = new GroveBasin(
            owner,
            makeAddr("lp2"),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        MockPocket mismatchedPocket = new MockPocket(
            address(otherBasin),
            address(swapToken),
            address(usds),
            address(psm)
        );

        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidPocket.selector);
        groveBasin.setPocket(address(mismatchedPocket));
    }

    function test_setPocket_migrationTransfersSwapToken() public {
        MockPocket pocket1 = new MockPocket(address(groveBasin), address(swapToken), address(usds), address(psm));
        MockPocket pocket2 = new MockPocket(address(groveBasin), address(swapToken), address(usds), address(psm));

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(swapToken.balanceOf(address(pocket1)), 0);
        assertEq(swapToken.balanceOf(address(pocket2)), 1_000_000e6);
    }

}

contract GroveBasinSetPocketSuccessTests is GroveBasinTestBase {

    MockPocket pocket1;
    MockPocket pocket2;

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function setUp() public override {
        super.setUp();

        pocket1 = new MockPocket(address(groveBasin), address(swapToken), address(usds), address(psm));
        pocket2 = new MockPocket(address(groveBasin), address(swapToken), address(usds), address(psm));
    }

    function test_setPocket_pocketIsGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        deal(address(swapToken), address(groveBasin), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(groveBasin)), 1_000_000e6);
        assertEq(swapToken.balanceOf(address(pocket1)),    0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(groveBasin));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(groveBasin), address(pocket1), 1_000_000e6);
        groveBasin.setPocket(address(pocket1));

        assertEq(swapToken.balanceOf(address(groveBasin)), 0);
        assertEq(swapToken.balanceOf(address(pocket1)),    1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket1));
    }

    function test_setPocket_pocketIsNotGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(pocket1)), 1_000_000e6);
        assertEq(swapToken.balanceOf(address(pocket2)), 0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket1));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(pocket1), address(pocket2), 1_000_000e6);
        groveBasin.setPocket(address(pocket2));

        assertEq(swapToken.balanceOf(address(pocket1)), 0);
        assertEq(swapToken.balanceOf(address(pocket2)), 1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket2));
    }

    function test_setPocket_valueStaysConstant() public {
        _deposit(address(swapToken),       owner, 1_000_000e6);
        _deposit(address(collateralToken), owner, 1_000_000e18);
        _deposit(address(creditToken),     owner, 800_000e18);

        uint256 expectedAssets = 3_000_000e18;
        assertEq(groveBasin.totalAssets(), expectedAssets);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        assertEq(groveBasin.totalAssets(), expectedAssets);
    }

}

contract GroveBasinSetPocketYieldDeployedTests is Test {

    address public owner      = makeAddr("owner");
    address public lp         = makeAddr("liquidityProvider");
    address public groveProxy = makeAddr("groveProxy");

    GroveBasin       public groveBasin;
    UsdsUsdcPocket   public pocket1;
    UsdsUsdcPocket   public pocket2;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public usdt;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public psm;

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function setUp() public {
        usds        = new MockERC20("USDS",   "USDS",   18);
        usdc        = new MockERC20("USDC",   "USDC",   6);
        usdt        = new MockERC20("USDT",   "USDT",   6);
        creditToken = new MockERC20("CREDIT", "CREDIT", 18);

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

        usds.mint(address(psm), 1_000_000_000e18);
        usdc.mint(address(psm), 1_000_000_000e6);

        pocket1 = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm),
            groveProxy
        );

        pocket2 = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm),
            groveProxy
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        groveBasin.setPocket(address(pocket1));
        vm.stopPrank();
    }

    function test_setPocket_swapTokenFullyDeployedToYield() public {
        uint256 depositAmount = 1_000_000e18;

        usds.mint(lp, depositAmount);
        vm.startPrank(lp);
        usds.approve(address(groveBasin), depositAmount);
        groveBasin.deposit(address(usds), lp, depositAmount);
        vm.stopPrank();

        // Verify USDS (swapToken) is in pocket
        assertGt(usds.balanceOf(address(pocket1)), 0);

        // setPocket draws liquidity then transfers
        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        // pocket1 should be empty
        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket1)), 0);

        // pocket2 should have the USDS (converted from USDS via PSM to USDC then back)
        assertGt(usds.balanceOf(address(pocket2)) + usdc.balanceOf(address(pocket2)), 0);
    }

    function test_setPocket_withdrawsUsds() public {
        usds.mint(address(pocket1), 1000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usds.balanceOf(address(pocket1)), 0);

        // USDS transferred to pocket2
        assertEq(usds.balanceOf(address(pocket2)), 1000e18);
    }

    function test_setPocket_withdrawsNoBalance() public {
        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usds.balanceOf(address(pocket2)), 0);
    }

}

contract GroveBasinSetPocketUsdtWithdrawalTests is Test {

    address public owner = makeAddr("owner");
    address public lp    = makeAddr("liquidityProvider");
    address public admin = makeAddr("admin");

    GroveBasin       public groveBasin;
    AaveV3UsdtPocket public pocket1;
    AaveV3UsdtPocket public pocket2;

    MockERC20  public usdt;
    MockAToken public aUsdt;
    MockERC20  public collateralToken;
    MockERC20  public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockAaveV3Pool public aaveV3Pool;

    function setUp() public {
        usdt            = new MockERC20("USDT",       "USDT",   6);
        aUsdt           = new MockAToken("aUSDT",     "aUSDT",  6, address(usdt));
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

        pocket1 = new AaveV3UsdtPocket(address(groveBasin), address(usdt), address(aUsdt), address(aaveV3Pool));
        pocket2 = new AaveV3UsdtPocket(address(groveBasin), address(usdt), address(aUsdt), address(aaveV3Pool));

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);
        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket1));
        vm.stopPrank();
    }

    function test_setPocket_withdrawsAUsdtAndUsdt() public {
        usdt.mint(address(pocket1), 500e6);
        aUsdt.mint(address(pocket1), 1000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usdt.balanceOf(address(pocket1)),  0);
        assertEq(aUsdt.balanceOf(address(pocket1)), 0);

        // aUSDT withdrawn from Aave to USDT, total = 500 + 1000 = 1500 USDT
        assertEq(usdt.balanceOf(address(pocket2)), 1500e6);
    }

    function test_setPocket_withdrawsOnlyAUsdt() public {
        aUsdt.mint(address(pocket1), 1000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usdt.balanceOf(address(pocket1)),  0);
        assertEq(aUsdt.balanceOf(address(pocket1)), 0);

        assertEq(usdt.balanceOf(address(pocket2)), 1000e6);
    }

    function test_setPocket_withdrawsOnlyUsdt() public {
        usdt.mint(address(pocket1), 500e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usdt.balanceOf(address(pocket1)),  0);
        assertEq(aUsdt.balanceOf(address(pocket1)), 0);

        assertEq(usdt.balanceOf(address(pocket2)), 500e6);
    }

    function test_setPocket_withdrawsNoBalance() public {
        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usdt.balanceOf(address(pocket1)),  0);
        assertEq(aUsdt.balanceOf(address(pocket1)), 0);
        assertEq(usdt.balanceOf(address(pocket2)),  0);
    }

}
