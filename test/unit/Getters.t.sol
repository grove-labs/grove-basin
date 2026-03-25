// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { GroveBasinHarness } from "test/unit/harnesses/GroveBasinHarness.sol";

contract GroveBasinHarnessTests is GroveBasinTestBase {

    GroveBasinHarness groveBasinHarness;

    function setUp() public override {
        super.setUp();
        groveBasinHarness = new GroveBasinHarness(
            address(owner),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        groveBasinHarness.grantRole(groveBasinHarness.MANAGER_ADMIN_ROLE(), owner);
        groveBasinHarness.setPocket(address(groveBasin));
        vm.stopPrank();
    }

    function test_getCollateralTokenValue() public view {
        assertEq(groveBasinHarness.getCollateralTokenValue(1), 1);
        assertEq(groveBasinHarness.getCollateralTokenValue(2), 2);
        assertEq(groveBasinHarness.getCollateralTokenValue(3), 3);

        assertEq(groveBasinHarness.getCollateralTokenValue(100e18), 100e18);
        assertEq(groveBasinHarness.getCollateralTokenValue(200e18), 200e18);
        assertEq(groveBasinHarness.getCollateralTokenValue(300e18), 300e18);

        assertEq(groveBasinHarness.getCollateralTokenValue(100_000_000_000e18), 100_000_000_000e18);
        assertEq(groveBasinHarness.getCollateralTokenValue(200_000_000_000e18), 200_000_000_000e18);
        assertEq(groveBasinHarness.getCollateralTokenValue(300_000_000_000e18), 300_000_000_000e18);
    }

    function testFuzz_getCollateralTokenValue(uint256 amount) public view {
        amount = _bound(amount, 0, 1e45);

        assertEq(groveBasinHarness.getCollateralTokenValue(amount), amount);
    }

    function test_getSwapTokenValue() public view {
        assertEq(groveBasinHarness.getSwapTokenValue(1), 1e12);
        assertEq(groveBasinHarness.getSwapTokenValue(2), 2e12);
        assertEq(groveBasinHarness.getSwapTokenValue(3), 3e12);

        assertEq(groveBasinHarness.getSwapTokenValue(100e6), 100e18);
        assertEq(groveBasinHarness.getSwapTokenValue(200e6), 200e18);
        assertEq(groveBasinHarness.getSwapTokenValue(300e6), 300e18);

        assertEq(groveBasinHarness.getSwapTokenValue(100_000_000_000e6), 100_000_000_000e18);
        assertEq(groveBasinHarness.getSwapTokenValue(200_000_000_000e6), 200_000_000_000e18);
        assertEq(groveBasinHarness.getSwapTokenValue(300_000_000_000e6), 300_000_000_000e18);
    }

    function testFuzz_getSwapTokenValue(uint256 amount) public view {
        amount = _bound(amount, 0, 1e45);

        assertEq(groveBasinHarness.getSwapTokenValue(amount), amount * 1e12);
    }

    function test_getCreditTokenValue() public {
        assertEq(groveBasinHarness.getCreditTokenValue(1, false), 1);
        assertEq(groveBasinHarness.getCreditTokenValue(2, false), 2);
        assertEq(groveBasinHarness.getCreditTokenValue(3, false), 3);
        assertEq(groveBasinHarness.getCreditTokenValue(4, false), 5);

        // Rounding up
        assertEq(groveBasinHarness.getCreditTokenValue(1, true), 2);
        assertEq(groveBasinHarness.getCreditTokenValue(2, true), 3);
        assertEq(groveBasinHarness.getCreditTokenValue(3, true), 4);
        assertEq(groveBasinHarness.getCreditTokenValue(4, true), 5);

        assertEq(groveBasinHarness.getCreditTokenValue(1e18, false), 1.25e18);
        assertEq(groveBasinHarness.getCreditTokenValue(2e18, false), 2.5e18);
        assertEq(groveBasinHarness.getCreditTokenValue(3e18, false), 3.75e18);
        assertEq(groveBasinHarness.getCreditTokenValue(4e18, false), 5e18);

        // No rounding but shows why rounding occurred at lower values
        assertEq(groveBasinHarness.getCreditTokenValue(1e18, true), 1.25e18);
        assertEq(groveBasinHarness.getCreditTokenValue(2e18, true), 2.5e18);
        assertEq(groveBasinHarness.getCreditTokenValue(3e18, true), 3.75e18);
        assertEq(groveBasinHarness.getCreditTokenValue(4e18, true), 5e18);

        mockCreditTokenRateProvider.__setConversionRate(1.6e27);

        assertEq(groveBasinHarness.getCreditTokenValue(1, false), 1);
        assertEq(groveBasinHarness.getCreditTokenValue(2, false), 3);
        assertEq(groveBasinHarness.getCreditTokenValue(3, false), 4);
        assertEq(groveBasinHarness.getCreditTokenValue(4, false), 6);

        // Rounding up
        assertEq(groveBasinHarness.getCreditTokenValue(1, true), 2);
        assertEq(groveBasinHarness.getCreditTokenValue(2, true), 4);
        assertEq(groveBasinHarness.getCreditTokenValue(3, true), 5);
        assertEq(groveBasinHarness.getCreditTokenValue(4, true), 7);

        assertEq(groveBasinHarness.getCreditTokenValue(1e18, false), 1.6e18);
        assertEq(groveBasinHarness.getCreditTokenValue(2e18, false), 3.2e18);
        assertEq(groveBasinHarness.getCreditTokenValue(3e18, false), 4.8e18);
        assertEq(groveBasinHarness.getCreditTokenValue(4e18, false), 6.4e18);

        // No rounding but shows why rounding occurred at lower values
        assertEq(groveBasinHarness.getCreditTokenValue(1e18, true), 1.6e18);
        assertEq(groveBasinHarness.getCreditTokenValue(2e18, true), 3.2e18);
        assertEq(groveBasinHarness.getCreditTokenValue(3e18, true), 4.8e18);
        assertEq(groveBasinHarness.getCreditTokenValue(4e18, true), 6.4e18);

        mockCreditTokenRateProvider.__setConversionRate(0.8e27);

        assertEq(groveBasinHarness.getCreditTokenValue(1, false), 0);
        assertEq(groveBasinHarness.getCreditTokenValue(2, false), 1);
        assertEq(groveBasinHarness.getCreditTokenValue(3, false), 2);
        assertEq(groveBasinHarness.getCreditTokenValue(4, false), 3);

        // Rounding up
        assertEq(groveBasinHarness.getCreditTokenValue(1, true), 1);
        assertEq(groveBasinHarness.getCreditTokenValue(2, true), 2);
        assertEq(groveBasinHarness.getCreditTokenValue(3, true), 3);
        assertEq(groveBasinHarness.getCreditTokenValue(4, true), 4);

        assertEq(groveBasinHarness.getCreditTokenValue(1e18, false), 0.8e18);
        assertEq(groveBasinHarness.getCreditTokenValue(2e18, false), 1.6e18);
        assertEq(groveBasinHarness.getCreditTokenValue(3e18, false), 2.4e18);
        assertEq(groveBasinHarness.getCreditTokenValue(4e18, false), 3.2e18);

        // No rounding but shows why rounding occurred at lower values
        assertEq(groveBasinHarness.getCreditTokenValue(1e18, true), 0.8e18);
        assertEq(groveBasinHarness.getCreditTokenValue(2e18, true), 1.6e18);
        assertEq(groveBasinHarness.getCreditTokenValue(3e18, true), 2.4e18);
        assertEq(groveBasinHarness.getCreditTokenValue(4e18, true), 3.2e18);
    }

    function testFuzz_getCreditTokenValue_roundDown(uint256 conversionRate, uint256 amount) public {
        conversionRate = _bound(conversionRate, 0, 1000e27);
        amount         = _bound(amount,         0, CREDIT_TOKEN_MAX);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        assertEq(groveBasinHarness.getCreditTokenValue(amount, false), amount * conversionRate / 1e27);
    }

    function test_getAssetValue() public view {
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 1, false), groveBasinHarness.getSwapTokenValue(1));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 2, false), groveBasinHarness.getSwapTokenValue(2));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 3, false), groveBasinHarness.getSwapTokenValue(3));

        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 1, true), groveBasinHarness.getSwapTokenValue(1));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 2, true), groveBasinHarness.getSwapTokenValue(2));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 3, true), groveBasinHarness.getSwapTokenValue(3));

        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 1e6, false), groveBasinHarness.getSwapTokenValue(1e6));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 2e6, false), groveBasinHarness.getSwapTokenValue(2e6));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 3e6, false), groveBasinHarness.getSwapTokenValue(3e6));

        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 1e6, true), groveBasinHarness.getSwapTokenValue(1e6));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 2e6, true), groveBasinHarness.getSwapTokenValue(2e6));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken), 3e6, true), groveBasinHarness.getSwapTokenValue(3e6));

        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 1, false), groveBasinHarness.getCollateralTokenValue(1));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 2, false), groveBasinHarness.getCollateralTokenValue(2));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 3, false), groveBasinHarness.getCollateralTokenValue(3));

        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 1, true), groveBasinHarness.getCollateralTokenValue(1));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 2, true), groveBasinHarness.getCollateralTokenValue(2));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 3, true), groveBasinHarness.getCollateralTokenValue(3));

        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 1e18, false), groveBasinHarness.getCollateralTokenValue(1e18));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 2e18, false), groveBasinHarness.getCollateralTokenValue(2e18));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 3e18, false), groveBasinHarness.getCollateralTokenValue(3e18));

        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 1e18, true), groveBasinHarness.getCollateralTokenValue(1e18));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 2e18, true), groveBasinHarness.getCollateralTokenValue(2e18));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken), 3e18, true), groveBasinHarness.getCollateralTokenValue(3e18));

        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 1, false), groveBasinHarness.getCreditTokenValue(1, false));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 2, false), groveBasinHarness.getCreditTokenValue(2, false));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 3, false), groveBasinHarness.getCreditTokenValue(3, false));

        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 1e18, false), groveBasinHarness.getCreditTokenValue(1e18, false));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 2e18, false), groveBasinHarness.getCreditTokenValue(2e18, false));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 3e18, false), groveBasinHarness.getCreditTokenValue(3e18, false));

        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 1, true), groveBasinHarness.getCreditTokenValue(1, true));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 2, true), groveBasinHarness.getCreditTokenValue(2, true));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 3, true), groveBasinHarness.getCreditTokenValue(3, true));

        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 1e18, true), groveBasinHarness.getCreditTokenValue(1e18, true));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 2e18, true), groveBasinHarness.getCreditTokenValue(2e18, true));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), 3e18, true), groveBasinHarness.getCreditTokenValue(3e18, true));
    }

    function testFuzz_getAssetValue(uint256 amount) public view {
        amount = _bound(amount, 0, CREDIT_TOKEN_MAX);

        // `swapToken` and `collateralToken` return the same values whether `roundUp` is true or false
        assertEq(groveBasinHarness.getAssetValue(address(swapToken),  amount, true),  groveBasinHarness.getSwapTokenValue(amount));
        assertEq(groveBasinHarness.getAssetValue(address(swapToken),  amount, true),  groveBasinHarness.getSwapTokenValue(amount));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken),  amount, false), groveBasinHarness.getCollateralTokenValue(amount));
        assertEq(groveBasinHarness.getAssetValue(address(collateralToken),  amount, false), groveBasinHarness.getCollateralTokenValue(amount));

        // `creditToken` returns different values depending on the value of `roundUp`, but always same as underlying function
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), amount, false), groveBasinHarness.getCreditTokenValue(amount, false));
        assertEq(groveBasinHarness.getAssetValue(address(creditToken), amount, true),  groveBasinHarness.getCreditTokenValue(amount, true));
    }

    function test_getAssetValue_zeroAddress() public {
        vm.expectRevert("GB/invalid-asset");
        groveBasinHarness.getAssetValue(address(0), 1, false);
    }

    function test_getAssetCustodian() public view {
        assertEq(groveBasinHarness.getAssetCustodian(address(swapToken)),  address(groveBasin));
        assertEq(groveBasinHarness.getAssetCustodian(address(collateralToken)),  address(groveBasinHarness));
        assertEq(groveBasinHarness.getAssetCustodian(address(creditToken)), address(groveBasinHarness));
    }

}

contract GetGroveBasinTotalValueTests is GroveBasinTestBase {

    function test_totalAssets_balanceChanges() public {
        collateralToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 1e18);

        swapToken.mint(address(pocket), 1e6);

        assertEq(groveBasin.totalAssets(), 2e18);

        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 3.25e18);

        collateralToken.burn(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 2.25e18);

        swapToken.burn(address(pocket), 1e6);

        assertEq(groveBasin.totalAssets(), 1.25e18);

        creditToken.burn(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 0);
    }

    function test_totalAssets_conversionRateChanges() public {
        assertEq(groveBasin.totalAssets(), 0);

        collateralToken.mint(address(groveBasin), 1e18);
        swapToken.mint(address(pocket), 1e6);
        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 3.25e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.totalAssets(), 3.5e18);

        mockCreditTokenRateProvider.__setConversionRate(0.8e27);

        assertEq(groveBasin.totalAssets(), 2.8e18);
    }

    function test_totalAssets_bothChange() public {
        assertEq(groveBasin.totalAssets(), 0);

        collateralToken.mint(address(groveBasin), 1e18);
        swapToken.mint(address(pocket), 1e6);
        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 3.25e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.totalAssets(), 3.5e18);

        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 5e18);
    }

    function testFuzz_totalAssets(
        uint256 collateralTokenAmount,
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        collateralTokenAmount = _bound(collateralTokenAmount, 0,         COLLATERAL_TOKEN_MAX);
        swapTokenAmount       = _bound(swapTokenAmount,       0,         SWAP_TOKEN_MAX);
        creditTokenAmount     = _bound(creditTokenAmount,     0,         CREDIT_TOKEN_MAX);
        conversionRate        = _bound(conversionRate,        0.0001e27, 1000e27);

        collateralToken.mint(address(groveBasin), collateralTokenAmount);
        swapToken.mint(address(pocket), swapTokenAmount);
        creditToken.mint(address(groveBasin), creditTokenAmount);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        assertEq(
            groveBasin.totalAssets(),
            collateralTokenAmount + (swapTokenAmount * 1e12) + (creditTokenAmount * conversionRate / 1e27)
        );
    }

}
