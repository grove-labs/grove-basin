// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { UsdsUsdcPocket }   from "src/UsdsUsdcPocket.sol";
import { UsdtPocket }       from "src/UsdtPocket.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockRateProvider }   from "test/mocks/MockRateProvider.sol";
import { MockPSM }            from "test/mocks/MockPSM.sol";
import { MockAaveV3Pool }     from "test/mocks/MockAaveV3Pool.sol";

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
        vm.expectRevert("GroveBasin/invalid-pocket");
        groveBasin.setPocket(address(0));
    }

    function test_setPocket_samePocket() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/same-pocket");
        groveBasin.setPocket(pocket);
    }

    function test_setPocket_migrationTransfersSwapToken() public {
        MockERC20 usds = new MockERC20("USDS", "USDS", 18);
        MockPSM   psm  = new MockPSM(address(usds), address(swapToken));

        usds.mint(address(psm), 1_000_000_000e18);
        swapToken.mint(address(psm), 1_000_000_000e6);

        UsdsUsdcPocket pocket1 = new UsdsUsdcPocket(address(groveBasin), address(swapToken), address(usds), address(psm));
        UsdsUsdcPocket pocket2 = new UsdsUsdcPocket(address(groveBasin), address(swapToken), address(usds), address(psm));

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

    UsdsUsdcPocket pocket1;
    UsdsUsdcPocket pocket2;

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function setUp() public override {
        super.setUp();

        pocket1 = new UsdsUsdcPocket(address(groveBasin), address(swapToken), address(usds), address(psm));
        pocket2 = new UsdsUsdcPocket(address(groveBasin), address(swapToken), address(usds), address(psm));
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
        _deposit(address(swapToken),   owner, 1_000_000e6);
        _deposit(address(collateralToken),  owner, 1_000_000e18);
        _deposit(address(creditToken), owner, 800_000e18);

        assertEq(groveBasin.totalAssets(), 3_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        assertEq(groveBasin.totalAssets(), 3_000_000e18);
    }

}

contract GroveBasinSetPocketYieldDeployedTests is Test {

    address public owner = makeAddr("owner");

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
            address(usdc),
            address(usdt),
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
            address(psm)
        );

        pocket2 = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket1));
        vm.stopPrank();
    }

    function test_setPocket_swapTokenFullyDeployedToYield() public {
        uint256 depositAmount = 1_000_000e6;

        usdc.mint(owner, depositAmount);
        vm.startPrank(owner);
        usdc.approve(address(groveBasin), depositAmount);
        groveBasin.deposit(address(usdc), owner, depositAmount);
        vm.stopPrank();

        // Verify USDC is fully deployed: pocket holds USDS, not USDC
        assertEq(usdc.balanceOf(address(pocket1)), 0);
        assertGt(usds.balanceOf(address(pocket1)), 0);

        // setPocket draws liquidity converting USDS back to USDC, then transfers
        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        // pocket1 should be empty
        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket1)), 0);

        // pocket2 should have all assets as USDC (converted from USDS via PSM)
        assertEq(usdc.balanceOf(address(pocket2)), depositAmount);
    }

    function test_setPocket_withdrawsUsdsAndUsdc() public {
        usds.mint(address(pocket1), 1000e18);
        usdc.mint(address(pocket1), 500e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket1)), 0);

        // USDS converted to USDC via PSM, total = 500 + 1000 = 1500 USDC
        assertEq(usdc.balanceOf(address(pocket2)), 1500e6);
    }

    function test_setPocket_withdrawsOnlyUsds() public {
        usds.mint(address(pocket1), 1000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket1)), 0);

        assertEq(usdc.balanceOf(address(pocket2)), 1000e6);
    }

    function test_setPocket_withdrawsOnlyUsdc() public {
        usdc.mint(address(pocket1), 500e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket1)), 0);

        assertEq(usdc.balanceOf(address(pocket2)), 500e6);
    }

    function test_setPocket_withdrawsNoBalance() public {
        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));

        assertEq(usds.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket1)), 0);
        assertEq(usdc.balanceOf(address(pocket2)), 0);
    }

}

contract GroveBasinSetPocketUsdtWithdrawalTests is Test {

    address public owner = makeAddr("owner");

    GroveBasin     public groveBasin;
    UsdtPocket     public pocket1;
    UsdtPocket     public pocket2;

    MockERC20 public usdt;
    MockERC20 public aUsdt;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockAaveV3Pool public aaveV3Pool;

    function setUp() public {
        usdt            = new MockERC20("USDT",       "USDT",       6);
        aUsdt           = new MockERC20("aUSDT",      "aUSDT",      6);
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

        address manager = makeAddr("manager");

        pocket1 = new UsdtPocket(address(groveBasin), manager, address(usdt), address(aUsdt), address(aaveV3Pool));
        pocket2 = new UsdtPocket(address(groveBasin), manager, address(usdt), address(aUsdt), address(aaveV3Pool));

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
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
