// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasin }         from "src/GroveBasin.sol";
import { MockERC20 }          from "erc20-helpers/MockERC20.sol";
import { MockRateProvider }   from "test/mocks/MockRateProvider.sol";
import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinZeroRateTests is GroveBasinTestBase {

    address public user     = makeAddr("user");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Seed liquidity so swap/withdraw paths are exercisable
        _deposit(address(swapToken),       user, 1_000e6);
        _deposit(address(collateralToken), user, 1_000e18);
        _deposit(address(creditToken),     user, 1_000e18);
    }

    // ==================== totalAssets ====================

    function test_totalAssets_zeroSwapRate_reverts() public {
        mockSwapTokenRateProvider.__setConversionRate(0);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.totalAssets();
    }

    function test_totalAssets_zeroCollateralRate_reverts() public {
        mockCollateralTokenRateProvider.__setConversionRate(0);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.totalAssets();
    }

    function test_totalAssets_zeroCreditRate_reverts() public {
        mockCreditTokenRateProvider.__setConversionRate(0);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.totalAssets();
    }

    // ==================== swapExactIn ====================

    function test_swapExactIn_zeroSwapRate_reverts() public {
        mockSwapTokenRateProvider.__setConversionRate(0);

        vm.startPrank(user);
        swapToken.mint(user, 100e6);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
        vm.stopPrank();
    }

    function test_swapExactIn_zeroCreditRate_reverts() public {
        mockCreditTokenRateProvider.__setConversionRate(0);

        vm.startPrank(user);
        swapToken.mint(user, 100e6);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
        vm.stopPrank();
    }

    function test_swapExactIn_zeroCollateralRate_reverts() public {
        mockCollateralTokenRateProvider.__setConversionRate(0);

        vm.startPrank(user);
        collateralToken.mint(user, 100e18);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 100e18, 0, receiver, 0);
        vm.stopPrank();
    }

    // ==================== swapExactOut ====================

    function test_swapExactOut_zeroSwapRate_reverts() public {
        mockSwapTokenRateProvider.__setConversionRate(0);

        vm.startPrank(user);
        creditToken.mint(user, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.swapExactOut(address(creditToken), address(swapToken), 10e6, type(uint256).max, receiver, 0);
        vm.stopPrank();
    }

    function test_swapExactOut_zeroCreditRate_reverts() public {
        mockCreditTokenRateProvider.__setConversionRate(0);

        vm.startPrank(user);
        swapToken.mint(user, 100e6);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 10e18, type(uint256).max, receiver, 0);
        vm.stopPrank();
    }

    function test_swapExactOut_zeroCollateralRate_reverts() public {
        mockCollateralTokenRateProvider.__setConversionRate(0);

        vm.startPrank(user);
        creditToken.mint(user, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.swapExactOut(address(creditToken), address(collateralToken), 10e18, type(uint256).max, receiver, 0);
        vm.stopPrank();
    }

    // ==================== deposit ====================

    function test_deposit_zeroSwapRate_reverts() public {
        address depositor = makeAddr("depositor");
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(lpRole, depositor);

        swapToken.mint(depositor, 100e6);

        vm.startPrank(depositor);
        swapToken.approve(address(groveBasin), 100e6);
        vm.stopPrank();

        mockSwapTokenRateProvider.__setConversionRate(0);

        vm.startPrank(depositor);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.deposit(address(swapToken), depositor, 100e6);
        vm.stopPrank();
    }

    function test_deposit_zeroCollateralRate_reverts() public {
        address depositor = makeAddr("depositor");
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(lpRole, depositor);

        collateralToken.mint(depositor, 100e18);

        vm.startPrank(depositor);
        collateralToken.approve(address(groveBasin), 100e18);
        vm.stopPrank();

        mockCollateralTokenRateProvider.__setConversionRate(0);

        vm.startPrank(depositor);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.deposit(address(collateralToken), depositor, 100e18);
        vm.stopPrank();
    }

    function test_deposit_zeroCreditRate_reverts() public {
        address depositor = makeAddr("depositor");
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(lpRole, depositor);

        creditToken.mint(depositor, 100e18);

        vm.startPrank(depositor);
        creditToken.approve(address(groveBasin), 100e18);
        vm.stopPrank();

        mockCreditTokenRateProvider.__setConversionRate(0);

        vm.startPrank(depositor);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.deposit(address(creditToken), depositor, 100e18);
        vm.stopPrank();
    }

    // ==================== withdraw ====================

    function test_withdraw_zeroSwapRate_reverts() public {
        mockSwapTokenRateProvider.__setConversionRate(0);

        vm.prank(user);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.withdraw(address(swapToken), receiver, 100e6);
    }

    function test_withdraw_zeroCollateralRate_reverts() public {
        mockCollateralTokenRateProvider.__setConversionRate(0);

        vm.prank(user);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.withdraw(address(collateralToken), receiver, 100e18);
    }

    function test_withdraw_zeroCreditRate_reverts() public {
        mockCreditTokenRateProvider.__setConversionRate(0);

        vm.prank(user);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.withdraw(address(creditToken), receiver, 100e18);
    }

    // ==================== previewDeposit ====================

    function test_previewDeposit_zeroSwapRate_reverts() public {
        mockSwapTokenRateProvider.__setConversionRate(0);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.previewDeposit(address(swapToken), 100e6);
    }

    function test_previewDeposit_zeroCollateralRate_reverts() public {
        mockCollateralTokenRateProvider.__setConversionRate(0);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.previewDeposit(address(collateralToken), 100e18);
    }

    function test_previewDeposit_zeroCreditRate_reverts() public {
        mockCreditTokenRateProvider.__setConversionRate(0);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.previewDeposit(address(creditToken), 100e18);
    }

    // ==================== previewWithdraw ====================

    function test_previewWithdraw_zeroSwapRate_reverts() public {
        mockSwapTokenRateProvider.__setConversionRate(0);
        vm.prank(user);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.previewWithdraw(address(swapToken), 100e6);
    }

    function test_previewWithdraw_zeroCollateralRate_reverts() public {
        mockCollateralTokenRateProvider.__setConversionRate(0);
        vm.prank(user);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.previewWithdraw(address(collateralToken), 100e18);
    }

    function test_previewWithdraw_zeroCreditRate_reverts() public {
        mockCreditTokenRateProvider.__setConversionRate(0);
        vm.prank(user);
        vm.expectRevert("GroveBasin/zero-rate");
        groveBasin.previewWithdraw(address(creditToken), 100e18);
    }

    // ==================== constructor still validates ====================

    function test_constructor_zeroSwapRate_reverts() public {
        MockRateProvider zeroProvider = new MockRateProvider();
        zeroProvider.__setConversionRate(0);

        vm.expectRevert("GroveBasin/swap-rate-provider-returns-zero");
        new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(zeroProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );
    }

    function test_constructor_zeroCollateralRate_reverts() public {
        MockRateProvider zeroProvider = new MockRateProvider();
        zeroProvider.__setConversionRate(0);

        vm.expectRevert("GroveBasin/collateral-rate-provider-returns-zero");
        new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(zeroProvider),
            address(creditTokenRateProvider)
        );
    }

    function test_constructor_zeroCreditRate_reverts() public {
        MockRateProvider zeroProvider = new MockRateProvider();
        zeroProvider.__setConversionRate(0);

        vm.expectRevert("GroveBasin/credit-rate-provider-returns-zero");
        new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(zeroProvider)
        );
    }

}
