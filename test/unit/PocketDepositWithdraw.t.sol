// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { UsdsUsdcPocket }   from "src/pockets/UsdsUsdcPocket.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

contract PocketDepositWithdrawTestBase is Test {

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    GroveBasin     public groveBasin;
    UsdsUsdcPocket public pocket;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public psm;

    function setUp() public virtual {
        usds        = new MockERC20("USDS",   "USDS",   18);
        usdc        = new MockERC20("USDC",   "USDC",   6);
        creditToken = new MockERC20("CREDIT", "CREDIT", 18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        // swapToken = USDS (18 decimals), collateralToken = USDC (6 decimals)
        groveBasin = new GroveBasin(
            owner,
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

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        groveBasin.setPocket(address(pocket));
        vm.stopPrank();
    }

    function _grantLpRole(address user) internal {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, user);
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        _deposit(asset, user, user, amount);
    }

    function _deposit(address asset, address user, address receiver, uint256 amount) internal {
        _grantLpRole(user);

        vm.startPrank(user);
        MockERC20(asset).mint(user, amount);
        MockERC20(asset).approve(address(groveBasin), amount);
        groveBasin.deposit(asset, receiver, amount);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** Basin deposit through pocket tests                                                     ***/
/**********************************************************************************************/

contract BasinDepositThroughPocketTests is PocketDepositWithdrawTestBase {

    function test_deposit_usds_goesToPocket() public {
        _grantLpRole(user1);

        usds.mint(user1, 100e18);

        vm.startPrank(user1);
        usds.approve(address(groveBasin), 100e18);

        assertEq(usds.balanceOf(user1),           100e18);
        assertEq(usds.balanceOf(address(pocket)),  0);

        uint256 newShares = groveBasin.deposit(address(usds), user1, 100e18);
        vm.stopPrank();

        assertEq(newShares, 100e18);

        // USDS went to pocket, stays as USDS
        assertEq(usds.balanceOf(user1),           0);
        assertEq(usds.balanceOf(address(pocket)), 100e18);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);
        assertEq(groveBasin.totalAssets(), 100e18);
    }

    function test_deposit_usdc_staysInBasin() public {
        _grantLpRole(user1);

        usdc.mint(user1, 100e6);

        vm.startPrank(user1);
        usdc.approve(address(groveBasin), 100e6);

        assertEq(usdc.balanceOf(user1), 100e6);

        uint256 newShares = groveBasin.deposit(address(usdc), user1, 100e6);
        vm.stopPrank();

        assertEq(newShares, 100e18);

        // USDC stays in basin, not sent to pocket
        assertEq(usdc.balanceOf(user1),               0);
        assertEq(usdc.balanceOf(address(groveBasin)), 100e6);
        assertEq(usdc.balanceOf(address(pocket)),     0);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);
        assertEq(groveBasin.totalAssets(), 100e18);
    }

    function test_deposit_creditToken_goesToBasin() public {
        _grantLpRole(user1);

        creditToken.mint(user1, 100e18);

        vm.startPrank(user1);
        creditToken.approve(address(groveBasin), 100e18);

        uint256 newShares = groveBasin.deposit(address(creditToken), user1, 100e18);
        vm.stopPrank();

        assertEq(newShares, 125e18);

        // Credit token stays in basin, not pocket
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);
        assertEq(creditToken.balanceOf(address(pocket)),     0);

        assertEq(groveBasin.totalShares(), 125e18);
        assertEq(groveBasin.shares(user1), 125e18);
    }

    function test_deposit_multiAsset_totalAssetsCorrect() public {
        _deposit(address(usds),        user1, 100e18);
        _deposit(address(usdc),        user1, 50e6);
        _deposit(address(creditToken), user1, 80e18);

        // 100 USDS + 50 USDC + 80 creditToken * 1.25 = 250
        assertEq(groveBasin.totalAssets(), 250e18);
    }

}

/**********************************************************************************************/
/*** Basin withdraw through pocket tests                                                    ***/
/**********************************************************************************************/

contract BasinWithdrawThroughPocketTests is PocketDepositWithdrawTestBase {

    function test_withdraw_usds_drawsFromPocket() public {
        _deposit(address(usds), user1, 100e18);

        assertEq(usds.balanceOf(address(pocket)), 100e18);
        assertEq(usds.balanceOf(user1),           0);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usds), user1, 100e18);

        assertEq(amount, 100e18);
        assertEq(usds.balanceOf(user1),           100e18);
        assertEq(usds.balanceOf(address(pocket)), 0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
    }

    function test_withdraw_usdc_fromBasin() public {
        // Deposit USDC → stays in basin
        _deposit(address(usdc), user1, 100e6);

        assertEq(usdc.balanceOf(address(groveBasin)), 100e6);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usdc), user1, 100e6);

        assertEq(amount, 100e6);
        assertEq(usdc.balanceOf(user1), 100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
    }

    function test_withdraw_creditToken_fromBasin() public {
        _deposit(address(creditToken), user1, 80e18);

        assertEq(creditToken.balanceOf(address(groveBasin)), 80e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(creditToken), user1, 80e18);

        assertEq(amount, 80e18);
        assertEq(creditToken.balanceOf(user1),               80e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
    }

    function test_withdraw_usds_partialWithdraw() public {
        _deposit(address(usds), user1, 100e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usds), user1, 50e18);

        assertEq(amount, 50e18);
        assertEq(usds.balanceOf(user1),           50e18);
        assertEq(usds.balanceOf(address(pocket)), 50e18);

        assertEq(groveBasin.totalShares(), 50e18);
        assertEq(groveBasin.shares(user1), 50e18);
    }

    function test_withdraw_usdc_amountHigherThanAvailable() public {
        _deposit(address(usdc), user1, 100e6);
        _deposit(address(creditToken), user2, 100e18);

        // User1 has 100e18 shares, user2 has 125e18 shares
        // User1 tries to withdraw more USDC than available
        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usdc), user1, 200e6);

        // Should be capped at available (100e6 worth of USDS in pocket)
        assertEq(amount, 100e6);
        assertEq(usdc.balanceOf(user1), 100e6);
    }

    function test_withdraw_depositUsdsThenWithdrawUsdc() public {
        // Deposit USDS (swapToken → pocket) and USDC (collateral → basin)
        _deposit(address(usds), user1, 100e18);
        _deposit(address(usdc), user1, 100e6);

        // Withdraw USDC from basin
        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usdc), user1, 100e6);

        assertEq(amount, 100e6);
        assertEq(usdc.balanceOf(user1), 100e6);
    }

    function test_withdraw_multiUser_depositAndWithdrawDifferentAssets() public {
        _deposit(address(usds), user1, 200e18);
        _deposit(address(usdc), user2, 100e6);

        // Pocket holds 200 USDS (swapToken), basin holds 100 USDC (collateral)
        assertEq(usds.balanceOf(address(pocket)),     200e18);
        assertEq(usdc.balanceOf(address(groveBasin)), 100e6);
        assertEq(groveBasin.totalShares(),            300e18);

        // User1 withdraws USDS from pocket
        vm.prank(user1);
        uint256 amount1 = groveBasin.withdraw(address(usds), user1, 200e18);

        assertEq(amount1, 200e18);
        assertEq(usds.balanceOf(user1), 200e18);
        assertEq(usds.balanceOf(address(pocket)), 0);

        // User2 withdraws USDC from basin
        vm.prank(user2);
        uint256 amount2 = groveBasin.withdraw(address(usdc), user2, 100e6);

        assertEq(amount2, 100e6);
        assertEq(usdc.balanceOf(user2), 100e6);

        assertEq(groveBasin.totalShares(), 0);
    }

}

/**********************************************************************************************/
/*** Basin deposit through pocket with USDT collateral tests                                ***/
/**********************************************************************************************/

contract BasinUsdtCollateralPocketTests is Test {

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");

    GroveBasin     public groveBasin;
    UsdsUsdcPocket public pocket;

    MockERC20 public usds;
    MockERC20 public usdc;
    MockERC20 public usdt;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public psm;

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

        // swapToken = USDC, collateralToken = USDT
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

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            address(usdc),
            address(usds),
            address(psm)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        groveBasin.setPocket(address(pocket));
        vm.stopPrank();
    }

    function _grantLpRole(address user) internal {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, user);
    }

    function test_deposit_usdt_staysInBasin() public {
        _grantLpRole(user1);

        usdt.mint(user1, 100e6);

        vm.startPrank(user1);
        usdt.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(usdt), user1, 100e6);
        vm.stopPrank();

        assertEq(newShares, 100e18);

        // USDT (collateral) stays in basin, not sent to pocket
        assertEq(usdt.balanceOf(user1),               0);
        assertEq(usdt.balanceOf(address(groveBasin)),  100e6);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);
        assertEq(groveBasin.totalAssets(), 100e18);
    }

    function test_withdraw_usdt_fromBasin() public {
        _grantLpRole(user1);

        usdt.mint(user1, 100e6);

        vm.startPrank(user1);
        usdt.approve(address(groveBasin), 100e6);
        groveBasin.deposit(address(usdt), user1, 100e6);
        vm.stopPrank();

        // USDT stays in basin
        assertEq(usdt.balanceOf(address(groveBasin)), 100e6);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usdt), user1, 100e6);

        assertEq(amount, 100e6);
        assertEq(usdt.balanceOf(user1), 100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
    }

    function test_deposit_usdc_thenWithdraw_usdc() public {
        _grantLpRole(user1);

        usdc.mint(user1, 100e6);

        vm.startPrank(user1);
        usdc.approve(address(groveBasin), 100e6);
        groveBasin.deposit(address(usdc), user1, 100e6);
        vm.stopPrank();

        // USDC went to pocket → converted to USDS via PSM
        assertEq(usds.balanceOf(address(pocket)), 100e18);
        assertEq(usdc.balanceOf(address(pocket)), 0);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(usdc), user1, 100e6);

        assertEq(amount, 100e6);
        assertEq(usdc.balanceOf(user1), 100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
    }

}
