// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPreviewDeposit_FailureTests is GroveBasinTestBase {

    function test_previewDeposit_invalidAsset() public {
        vm.expectRevert("GroveBasin/invalid-asset-for-value");
        groveBasin.previewDeposit(makeAddr("other-token"), 1);
    }

}

contract GroveBasinPreviewDeposit_SuccessTests is GroveBasinTestBase {

    address depositor = makeAddr("depositor");

    function test_previewDeposit_collateralToken_firstDeposit() public view {
        assertEq(groveBasin.previewDeposit(address(collateralToken), 1), 1);
        assertEq(groveBasin.previewDeposit(address(collateralToken), 2), 2);
        assertEq(groveBasin.previewDeposit(address(collateralToken), 3), 3);

        assertEq(groveBasin.previewDeposit(address(collateralToken), 1e18), 1e18);
        assertEq(groveBasin.previewDeposit(address(collateralToken), 2e18), 2e18);
        assertEq(groveBasin.previewDeposit(address(collateralToken), 3e18), 3e18);
    }

    function testFuzz_previewDeposit_collateralToken_firstDeposit(uint256 amount) public view {
        amount = _bound(amount, 0, COLLATERAL_TOKEN_MAX);
        assertEq(groveBasin.previewDeposit(address(collateralToken), amount), amount);
    }

    function test_previewDeposit_swapToken_firstDeposit() public view {
        assertEq(groveBasin.previewDeposit(address(swapToken), 1), 1e12);
        assertEq(groveBasin.previewDeposit(address(swapToken), 2), 2e12);
        assertEq(groveBasin.previewDeposit(address(swapToken), 3), 3e12);

        assertEq(groveBasin.previewDeposit(address(swapToken), 1e6), 1e18);
        assertEq(groveBasin.previewDeposit(address(swapToken), 2e6), 2e18);
        assertEq(groveBasin.previewDeposit(address(swapToken), 3e6), 3e18);
    }

    function testFuzz_previewDeposit_swapToken_firstDeposit(uint256 amount) public view {
        amount = _bound(amount, 0, SWAP_TOKEN_MAX);
        assertEq(groveBasin.previewDeposit(address(swapToken), amount), amount * 1e12);
    }

    function test_previewDeposit_creditToken_firstDeposit() public view {
        assertEq(groveBasin.previewDeposit(address(creditToken), 1), 1);
        assertEq(groveBasin.previewDeposit(address(creditToken), 2), 2);
        assertEq(groveBasin.previewDeposit(address(creditToken), 3), 3);
        assertEq(groveBasin.previewDeposit(address(creditToken), 4), 5);

        assertEq(groveBasin.previewDeposit(address(creditToken), 1e18), 1.25e18);
        assertEq(groveBasin.previewDeposit(address(creditToken), 2e18), 2.50e18);
        assertEq(groveBasin.previewDeposit(address(creditToken), 3e18), 3.75e18);
        assertEq(groveBasin.previewDeposit(address(creditToken), 4e18), 5.00e18);
    }

    function testFuzz_previewDeposit_creditToken_firstDeposit(uint256 amount) public view {
        amount = _bound(amount, 0, CREDIT_TOKEN_MAX);
        assertEq(groveBasin.previewDeposit(address(creditToken), amount), amount * 1.25e27 / 1e27);
    }

    function test_previewDeposit_afterDepositsAndExchangeRateIncrease() public {
        _assertOneToOne();

        _deposit(address(collateralToken), depositor, 1e18);
        _assertOneToOne();

        _deposit(address(swapToken), depositor, 1e6);
        _assertOneToOne();

        _deposit(address(creditToken), depositor, 0.8e18);
        _assertOneToOne();

        mockCreditTokenRateProvider.__setConversionRate(2e27);

        // $300 dollars of value deposited, 300 shares minted.
        // creditToken portion becomes worth $160, full pool worth $360, each share worth $1.20
        // 1 USDC = 1/1.20 = 0.833...
        assertEq(groveBasin.previewDeposit(address(collateralToken),  1e18), 0.833333333333333333e18);
        assertEq(groveBasin.previewDeposit(address(swapToken),  1e6),  0.833333333333333333e18);
        assertEq(groveBasin.previewDeposit(address(creditToken), 1e18), 1.666666666666666666e18);  // 1 creditToken = $2
    }

    function testFuzz_previewDeposit_afterDepositsAndExchangeRateIncrease(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        uint256 conversionRate,
        uint256 previewAmount
    ) public {
        amount1        = _bound(amount1,        1,       COLLATERAL_TOKEN_MAX);
        amount2        = _bound(amount2,        1,       SWAP_TOKEN_MAX);
        amount3        = _bound(amount3,        1,       CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 1.00e27, 1000e27);
        previewAmount  = _bound(previewAmount,  0,       COLLATERAL_TOKEN_MAX);

        _assertOneToOne();

        _deposit(address(collateralToken), depositor, amount1);
        _assertOneToOne();

        _deposit(address(swapToken), depositor, amount2);
        _assertOneToOne();

        _deposit(address(creditToken), depositor, amount3);
        _assertOneToOne();

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 totalSharesMinted = amount1 + amount2 * 1e12 + amount3 * 1.25e27 / 1e27;
        uint256 totalValue        = amount1 + amount2 * 1e12 + amount3 * conversionRate / 1e27;
        uint256 swapTokenPreviewAmount = previewAmount / 1e12;

        assertEq(groveBasin.previewDeposit(address(collateralToken),  previewAmount),     previewAmount                           * totalSharesMinted / totalValue);
        assertEq(groveBasin.previewDeposit(address(swapToken),  swapTokenPreviewAmount), swapTokenPreviewAmount * 1e12                * totalSharesMinted / totalValue);  // Divide then multiply to replicate rounding
        assertEq(groveBasin.previewDeposit(address(creditToken), previewAmount),     (previewAmount * conversionRate / 1e27) * totalSharesMinted / totalValue);
    }

    function _assertOneToOne() internal view {
        assertEq(groveBasin.previewDeposit(address(collateralToken),  1e18), 1e18);
        assertEq(groveBasin.previewDeposit(address(swapToken),  1e6),  1e18);
        assertEq(groveBasin.previewDeposit(address(creditToken), 1e18), 1.25e18);
    }

}
