// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinPreviewWithdraw_FailureTests is GroveBasinTestBase {

    function test_previewWithdraw_invalidAsset() public {
        vm.expectRevert();
        groveBasin.previewWithdraw(makeAddr("other-token"), 1);
    }

}

contract GroveBasinPreviewWithdraw_ZeroTotalValueTests is Test {

    function test_previewWithdraw_zeroTotalValue() public {
        MockERC20 swapToken       = new MockERC20("swap",       "SWAP", 6);
        MockERC20 collateralToken = new MockERC20("collateral", "COL",  18);
        MockERC20 creditToken     = new MockERC20("credit",     "CRD",  18);

        MockRateProvider swapRP       = new MockRateProvider();
        MockRateProvider collateralRP = new MockRateProvider();
        MockRateProvider creditRP     = new MockRateProvider();

        swapRP.__setConversionRate(1e27);
        collateralRP.__setConversionRate(1e27);
        creditRP.__setConversionRate(1.25e27);

        GroveBasin freshBasin = new GroveBasin(
            address(this), address(this),
            address(swapToken), address(collateralToken), address(creditToken),
            address(swapRP), address(collateralRP), address(creditRP)
        );

        // totalShares == 0 and totalAssets == 0
        ( uint256 sharesToBurn, uint256 assetsWithdrawn ) = freshBasin.previewWithdraw(address(swapToken), 1e6);

        assertEq(sharesToBurn, 0);
        assertEq(assetsWithdrawn, 0);
    }

}

contract GroveBasinPreviewWithdraw_ZeroAssetsTests is GroveBasinTestBase {

    // Always returns zero because there is no balance of assets in the GroveBasin in this case
    function test_previewWithdraw_zeroTotalAssets() public {
        ( uint256 shares1, uint256 assets1 ) = groveBasin.previewWithdraw(address(collateralToken),  1e18);
        ( uint256 shares2, uint256 assets2 ) = groveBasin.previewWithdraw(address(swapToken),  1e6);
        ( uint256 shares3, uint256 assets3 ) = groveBasin.previewWithdraw(address(creditToken), 1e18);

        assertEq(shares1, 0);
        assertEq(assets1, 0);
        assertEq(shares2, 0);
        assertEq(assets2, 0);
        assertEq(shares3, 0);
        assertEq(assets3, 0);

        mockCreditTokenRateProvider.__setConversionRate(2e27);

        ( shares1, assets1 ) = groveBasin.previewWithdraw(address(collateralToken),  1e18);
        ( shares2, assets2 ) = groveBasin.previewWithdraw(address(swapToken),  1e6);
        ( shares3, assets3 ) = groveBasin.previewWithdraw(address(creditToken), 1e18);

        assertEq(shares1, 0);
        assertEq(assets1, 0);
        assertEq(shares2, 0);
        assertEq(assets2, 0);
        assertEq(shares3, 0);
        assertEq(assets3, 0);
    }

}

contract GroveBasinPreviewWithdraw_SuccessTests is GroveBasinTestBase {

    function setUp() public override {
        super.setUp();
        // Setup so that address(this) has the most shares, higher underlying balance than GroveBasin
        // balance of creditToken and USDC
        _deposit(address(collateralToken),  address(this),          100e18);
        _deposit(address(swapToken),  makeAddr("swapToken-user"),  10e6);
        _deposit(address(creditToken), makeAddr("creditToken-user"), 1e18);
    }

    function test_previewWithdraw_collateralToken_amountLtUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(collateralToken), 100e18 - 1);
        assertEq(shares, 100e18 - 1);
        assertEq(assets, 100e18 - 1);
    }

    function test_previewWithdraw_collateralToken_amountEqUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(collateralToken), 100e18);
        assertEq(shares, 100e18);
        assertEq(assets, 100e18);
    }

    function test_previewWithdraw_collateralToken_amountGtUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(collateralToken), 100e18 + 1);
        assertEq(shares, 100e18);
        assertEq(assets, 100e18);
    }

    function test_previewWithdraw_swapToken_amountLtUnderlyingBalanceAndLtGroveBasinBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(swapToken), 10e6 - 1);
        assertEq(shares, 10e18 - 1e12);
        assertEq(assets, 10e6 - 1);
    }

    function test_previewWithdraw_swapToken_amountLtUnderlyingBalanceAndEqGroveBasinBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(swapToken), 10e6);
        assertEq(shares, 10e18);
        assertEq(assets, 10e6);
    }

    function test_previewWithdraw_swapToken_amountLtUnderlyingBalanceAndGtGroveBasinBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(swapToken), 10e6 + 1);
        assertEq(shares, 10e18);
        assertEq(assets, 10e6);
    }

    function test_previewWithdraw_creditToken_amountLtUnderlyingBalanceAndLtGroveBasinBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(creditToken), 1e18 - 1);
        assertEq(shares, 1.25e18 - 1);
        assertEq(assets, 1e18 - 1);
    }

    function test_previewWithdraw_creditToken_amountLtUnderlyingBalanceAndEqGroveBasinBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(creditToken), 1e18);
        assertEq(shares, 1.25e18);
        assertEq(assets, 1e18);
    }

    function test_previewWithdraw_creditToken_amountLtUnderlyingBalanceAndGtGroveBasinBalance() public view {
        ( uint256 shares, uint256 assets ) = groveBasin.previewWithdraw(address(creditToken), 1e18 + 1);
        assertEq(shares, 1.25e18);
        assertEq(assets, 1e18);
    }

}

contract GroveBasinPreviewWithdraw_SuccessFuzzTests is GroveBasinTestBase {

    struct TestParams {
        uint256 amount1;
        uint256 amount2;
        uint256 amount3;
        uint256 previewAmount1;
        uint256 previewAmount2;
        uint256 previewAmount3;
        uint256 conversionRate;
    }

    function testFuzz_previewWithdraw(TestParams memory params) public {
        params.amount1 = _bound(params.amount1, 1, COLLATERAL_TOKEN_MAX);
        params.amount2 = _bound(params.amount2, 1, SWAP_TOKEN_MAX);
        params.amount3 = _bound(params.amount3, 1, CREDIT_TOKEN_MAX);

        // Only covering case of amount being below underlying to focus on value conversion
        // and avoid reimplementation of contract logic for dealing with capping amounts
        params.previewAmount1 = _bound(params.previewAmount1, 0, params.amount1);
        params.previewAmount2 = _bound(params.previewAmount2, 0, params.amount2);
        params.previewAmount3 = _bound(params.previewAmount3, 0, params.amount3);

        _deposit(address(collateralToken),  address(this), params.amount1);
        _deposit(address(swapToken),  address(this), params.amount2);
        _deposit(address(creditToken), address(this), params.amount3);

        ( uint256 shares1, uint256 assets1 ) = groveBasin.previewWithdraw(address(collateralToken), params.previewAmount1);
        ( uint256 shares2, uint256 assets2 ) = groveBasin.previewWithdraw(address(swapToken),       params.previewAmount2);
        ( uint256 shares3, uint256 assets3 ) = groveBasin.previewWithdraw(address(creditToken),     params.previewAmount3);

        uint256 totalSharesMinted = params.amount1 + params.amount2 * 1e12 + params.amount3 * 1.25e27 / 1e27;
        uint256 totalValue        = totalSharesMinted;

        // Assert shares are always rounded up, max of 1 wei difference except for creditToken
        assertLe(shares1 - (params.previewAmount1                  * totalSharesMinted / totalValue), 1);
        assertLe(shares2 - (params.previewAmount2 * 1e12           * totalSharesMinted / totalValue), 1);
        assertLe(shares3 - (params.previewAmount3 * 1.25e27 / 1e27 * totalSharesMinted / totalValue), 3);

        assertEq(assets1, params.previewAmount1);
        assertEq(assets2, params.previewAmount2);
        assertEq(assets3, params.previewAmount3);

        params.conversionRate = _bound(params.conversionRate, 0.001e27, 1000e27);
        mockCreditTokenRateProvider.__setConversionRate(params.conversionRate);

        // creditToken value accrual changes the value of shares in the GroveBasin
        totalValue = params.amount1 + params.amount2 * 1e12 + params.amount3 * params.conversionRate / 1e27;

        ( shares1, assets1 ) = groveBasin.previewWithdraw(address(collateralToken), params.previewAmount1);
        ( shares2, assets2 ) = groveBasin.previewWithdraw(address(swapToken),       params.previewAmount2);
        ( shares3, assets3 ) = groveBasin.previewWithdraw(address(creditToken),     params.previewAmount3);

        uint256 creditTokenConvertedAmount = params.previewAmount3 * params.conversionRate / 1e27;

        // Only check share rounding assertions when withdrawal doesn't trigger share-capping.
        // Extreme rate changes can cause previewWithdraw to cap at user's shares, making the
        // formula-based assertions invalid (contract returns capped shares, not formula result).
        uint256 expectedFloor1 = params.previewAmount1        * totalSharesMinted / totalValue;
        uint256 expectedFloor2 = params.previewAmount2 * 1e12 * totalSharesMinted / totalValue;
        uint256 expectedFloor3 = creditTokenConvertedAmount   * totalSharesMinted / totalValue;

        if (shares1 >= expectedFloor1) {
            assertLe(shares1 - expectedFloor1, 1);
        }
        if (shares2 >= expectedFloor2) {
            assertLe(shares2 - expectedFloor2, 1);
        }
        if (shares3 >= expectedFloor3) {
            assertLe(shares3 - expectedFloor3, 3 + totalSharesMinted / totalValue);
        }

        // When shares are not capped, assets should match preview amounts.
        // When shares are capped (due to extreme rate changes), assets will be less.
        assertLe(assets1, params.previewAmount1);
        assertLe(assets2, params.previewAmount2);
        assertLe(assets3, params.previewAmount3);

        // When not capped, assets should be approximately equal
        if (shares1 >= expectedFloor1) assertApproxEqAbs(assets1, params.previewAmount1, 1);
        if (shares2 >= expectedFloor2) assertApproxEqAbs(assets2, params.previewAmount2, 1);
        if (shares3 >= expectedFloor3) assertApproxEqAbs(assets3, params.previewAmount3, 1);
    }

}
