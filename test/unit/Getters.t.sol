// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { GroveBasinHarness } from "test/unit/harnesses/GroveBasinHarness.sol";

contract PSMHarnessTests is GroveBasinTestBase {

    GroveBasinHarness psmHarness;

    function setUp() public override {
        super.setUp();
        psmHarness = new GroveBasinHarness(
            address(owner),
            address(usdc),
            address(usds),
            address(creditToken),
            address(creditTokenRateProvider)
        );

        vm.prank(owner);
        psmHarness.setPocket(pocket);
    }

    function test_getUsdsValue() public view {
        assertEq(psmHarness.getUsdsValue(1), 1);
        assertEq(psmHarness.getUsdsValue(2), 2);
        assertEq(psmHarness.getUsdsValue(3), 3);

        assertEq(psmHarness.getUsdsValue(100e18), 100e18);
        assertEq(psmHarness.getUsdsValue(200e18), 200e18);
        assertEq(psmHarness.getUsdsValue(300e18), 300e18);

        assertEq(psmHarness.getUsdsValue(100_000_000_000e18), 100_000_000_000e18);
        assertEq(psmHarness.getUsdsValue(200_000_000_000e18), 200_000_000_000e18);
        assertEq(psmHarness.getUsdsValue(300_000_000_000e18), 300_000_000_000e18);
    }

    function testFuzz_getUsdsValue(uint256 amount) public view {
        amount = _bound(amount, 0, 1e45);

        assertEq(psmHarness.getUsdsValue(amount), amount);
    }

    function test_getUsdcValue() public view {
        assertEq(psmHarness.getUsdcValue(1), 1e12);
        assertEq(psmHarness.getUsdcValue(2), 2e12);
        assertEq(psmHarness.getUsdcValue(3), 3e12);

        assertEq(psmHarness.getUsdcValue(100e6), 100e18);
        assertEq(psmHarness.getUsdcValue(200e6), 200e18);
        assertEq(psmHarness.getUsdcValue(300e6), 300e18);

        assertEq(psmHarness.getUsdcValue(100_000_000_000e6), 100_000_000_000e18);
        assertEq(psmHarness.getUsdcValue(200_000_000_000e6), 200_000_000_000e18);
        assertEq(psmHarness.getUsdcValue(300_000_000_000e6), 300_000_000_000e18);
    }

    function testFuzz_getUsdcValue(uint256 amount) public view {
        amount = _bound(amount, 0, 1e45);

        assertEq(psmHarness.getUsdcValue(amount), amount * 1e12);
    }

    function test_getCreditTokenValue() public {
        assertEq(psmHarness.getCreditTokenValue(1, false), 1);
        assertEq(psmHarness.getCreditTokenValue(2, false), 2);
        assertEq(psmHarness.getCreditTokenValue(3, false), 3);
        assertEq(psmHarness.getCreditTokenValue(4, false), 5);

        // Rounding up
        assertEq(psmHarness.getCreditTokenValue(1, true), 2);
        assertEq(psmHarness.getCreditTokenValue(2, true), 3);
        assertEq(psmHarness.getCreditTokenValue(3, true), 4);
        assertEq(psmHarness.getCreditTokenValue(4, true), 5);

        assertEq(psmHarness.getCreditTokenValue(1e18, false), 1.25e18);
        assertEq(psmHarness.getCreditTokenValue(2e18, false), 2.5e18);
        assertEq(psmHarness.getCreditTokenValue(3e18, false), 3.75e18);
        assertEq(psmHarness.getCreditTokenValue(4e18, false), 5e18);

        // No rounding but shows why rounding occurred at lower values
        assertEq(psmHarness.getCreditTokenValue(1e18, true), 1.25e18);
        assertEq(psmHarness.getCreditTokenValue(2e18, true), 2.5e18);
        assertEq(psmHarness.getCreditTokenValue(3e18, true), 3.75e18);
        assertEq(psmHarness.getCreditTokenValue(4e18, true), 5e18);

        mockCreditTokenRateProvider.__setConversionRate(1.6e27);

        assertEq(psmHarness.getCreditTokenValue(1, false), 1);
        assertEq(psmHarness.getCreditTokenValue(2, false), 3);
        assertEq(psmHarness.getCreditTokenValue(3, false), 4);
        assertEq(psmHarness.getCreditTokenValue(4, false), 6);

        // Rounding up
        assertEq(psmHarness.getCreditTokenValue(1, true), 2);
        assertEq(psmHarness.getCreditTokenValue(2, true), 4);
        assertEq(psmHarness.getCreditTokenValue(3, true), 5);
        assertEq(psmHarness.getCreditTokenValue(4, true), 7);

        assertEq(psmHarness.getCreditTokenValue(1e18, false), 1.6e18);
        assertEq(psmHarness.getCreditTokenValue(2e18, false), 3.2e18);
        assertEq(psmHarness.getCreditTokenValue(3e18, false), 4.8e18);
        assertEq(psmHarness.getCreditTokenValue(4e18, false), 6.4e18);

        // No rounding but shows why rounding occurred at lower values
        assertEq(psmHarness.getCreditTokenValue(1e18, true), 1.6e18);
        assertEq(psmHarness.getCreditTokenValue(2e18, true), 3.2e18);
        assertEq(psmHarness.getCreditTokenValue(3e18, true), 4.8e18);
        assertEq(psmHarness.getCreditTokenValue(4e18, true), 6.4e18);

        mockCreditTokenRateProvider.__setConversionRate(0.8e27);

        assertEq(psmHarness.getCreditTokenValue(1, false), 0);
        assertEq(psmHarness.getCreditTokenValue(2, false), 1);
        assertEq(psmHarness.getCreditTokenValue(3, false), 2);
        assertEq(psmHarness.getCreditTokenValue(4, false), 3);

        // Rounding up
        assertEq(psmHarness.getCreditTokenValue(1, true), 1);
        assertEq(psmHarness.getCreditTokenValue(2, true), 2);
        assertEq(psmHarness.getCreditTokenValue(3, true), 3);
        assertEq(psmHarness.getCreditTokenValue(4, true), 4);

        assertEq(psmHarness.getCreditTokenValue(1e18, false), 0.8e18);
        assertEq(psmHarness.getCreditTokenValue(2e18, false), 1.6e18);
        assertEq(psmHarness.getCreditTokenValue(3e18, false), 2.4e18);
        assertEq(psmHarness.getCreditTokenValue(4e18, false), 3.2e18);

        // No rounding but shows why rounding occurred at lower values
        assertEq(psmHarness.getCreditTokenValue(1e18, true), 0.8e18);
        assertEq(psmHarness.getCreditTokenValue(2e18, true), 1.6e18);
        assertEq(psmHarness.getCreditTokenValue(3e18, true), 2.4e18);
        assertEq(psmHarness.getCreditTokenValue(4e18, true), 3.2e18);
    }

    function testFuzz_getCreditTokenValue_roundDown(uint256 conversionRate, uint256 amount) public {
        conversionRate = _bound(conversionRate, 0, 1000e27);
        amount         = _bound(amount,         0, CREDIT_TOKEN_MAX);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        assertEq(psmHarness.getCreditTokenValue(amount, false), amount * conversionRate / 1e27);
    }

    function test_getAssetValue() public view {
        assertEq(psmHarness.getAssetValue(address(usdc), 1, false), psmHarness.getUsdcValue(1));
        assertEq(psmHarness.getAssetValue(address(usdc), 2, false), psmHarness.getUsdcValue(2));
        assertEq(psmHarness.getAssetValue(address(usdc), 3, false), psmHarness.getUsdcValue(3));

        assertEq(psmHarness.getAssetValue(address(usdc), 1, true), psmHarness.getUsdcValue(1));
        assertEq(psmHarness.getAssetValue(address(usdc), 2, true), psmHarness.getUsdcValue(2));
        assertEq(psmHarness.getAssetValue(address(usdc), 3, true), psmHarness.getUsdcValue(3));

        assertEq(psmHarness.getAssetValue(address(usdc), 1e6, false), psmHarness.getUsdcValue(1e6));
        assertEq(psmHarness.getAssetValue(address(usdc), 2e6, false), psmHarness.getUsdcValue(2e6));
        assertEq(psmHarness.getAssetValue(address(usdc), 3e6, false), psmHarness.getUsdcValue(3e6));

        assertEq(psmHarness.getAssetValue(address(usdc), 1e6, true), psmHarness.getUsdcValue(1e6));
        assertEq(psmHarness.getAssetValue(address(usdc), 2e6, true), psmHarness.getUsdcValue(2e6));
        assertEq(psmHarness.getAssetValue(address(usdc), 3e6, true), psmHarness.getUsdcValue(3e6));

        assertEq(psmHarness.getAssetValue(address(usds), 1, false), psmHarness.getUsdsValue(1));
        assertEq(psmHarness.getAssetValue(address(usds), 2, false), psmHarness.getUsdsValue(2));
        assertEq(psmHarness.getAssetValue(address(usds), 3, false), psmHarness.getUsdsValue(3));

        assertEq(psmHarness.getAssetValue(address(usds), 1, true), psmHarness.getUsdsValue(1));
        assertEq(psmHarness.getAssetValue(address(usds), 2, true), psmHarness.getUsdsValue(2));
        assertEq(psmHarness.getAssetValue(address(usds), 3, true), psmHarness.getUsdsValue(3));

        assertEq(psmHarness.getAssetValue(address(usds), 1e18, false), psmHarness.getUsdsValue(1e18));
        assertEq(psmHarness.getAssetValue(address(usds), 2e18, false), psmHarness.getUsdsValue(2e18));
        assertEq(psmHarness.getAssetValue(address(usds), 3e18, false), psmHarness.getUsdsValue(3e18));

        assertEq(psmHarness.getAssetValue(address(usds), 1e18, true), psmHarness.getUsdsValue(1e18));
        assertEq(psmHarness.getAssetValue(address(usds), 2e18, true), psmHarness.getUsdsValue(2e18));
        assertEq(psmHarness.getAssetValue(address(usds), 3e18, true), psmHarness.getUsdsValue(3e18));

        assertEq(psmHarness.getAssetValue(address(creditToken), 1, false), psmHarness.getCreditTokenValue(1, false));
        assertEq(psmHarness.getAssetValue(address(creditToken), 2, false), psmHarness.getCreditTokenValue(2, false));
        assertEq(psmHarness.getAssetValue(address(creditToken), 3, false), psmHarness.getCreditTokenValue(3, false));

        assertEq(psmHarness.getAssetValue(address(creditToken), 1e18, false), psmHarness.getCreditTokenValue(1e18, false));
        assertEq(psmHarness.getAssetValue(address(creditToken), 2e18, false), psmHarness.getCreditTokenValue(2e18, false));
        assertEq(psmHarness.getAssetValue(address(creditToken), 3e18, false), psmHarness.getCreditTokenValue(3e18, false));

        assertEq(psmHarness.getAssetValue(address(creditToken), 1, true), psmHarness.getCreditTokenValue(1, true));
        assertEq(psmHarness.getAssetValue(address(creditToken), 2, true), psmHarness.getCreditTokenValue(2, true));
        assertEq(psmHarness.getAssetValue(address(creditToken), 3, true), psmHarness.getCreditTokenValue(3, true));

        assertEq(psmHarness.getAssetValue(address(creditToken), 1e18, true), psmHarness.getCreditTokenValue(1e18, true));
        assertEq(psmHarness.getAssetValue(address(creditToken), 2e18, true), psmHarness.getCreditTokenValue(2e18, true));
        assertEq(psmHarness.getAssetValue(address(creditToken), 3e18, true), psmHarness.getCreditTokenValue(3e18, true));
    }

    function testFuzz_getAssetValue(uint256 amount) public view {
        amount = _bound(amount, 0, CREDIT_TOKEN_MAX);

        // `usdc` and `usds` return the same values whether `roundUp` is true or false
        assertEq(psmHarness.getAssetValue(address(usdc),  amount, true),  psmHarness.getUsdcValue(amount));
        assertEq(psmHarness.getAssetValue(address(usdc),  amount, true),  psmHarness.getUsdcValue(amount));
        assertEq(psmHarness.getAssetValue(address(usds),  amount, false), psmHarness.getUsdsValue(amount));
        assertEq(psmHarness.getAssetValue(address(usds),  amount, false), psmHarness.getUsdsValue(amount));

        // `creditToken` returns different values depending on the value of `roundUp`, but always same as underlying function
        assertEq(psmHarness.getAssetValue(address(creditToken), amount, false), psmHarness.getCreditTokenValue(amount, false));
        assertEq(psmHarness.getAssetValue(address(creditToken), amount, true),  psmHarness.getCreditTokenValue(amount, true));
    }

    function test_getAssetValue_zeroAddress() public {
        vm.expectRevert("GroveBasin/invalid-asset-for-value");
        psmHarness.getAssetValue(address(0), 1, false);
    }

    function test_getAssetCustodian() public view {
        assertEq(psmHarness.getAssetCustodian(address(usdc)),  address(pocket));
        assertEq(psmHarness.getAssetCustodian(address(usds)),  address(psmHarness));
        assertEq(psmHarness.getAssetCustodian(address(creditToken)), address(psmHarness));
    }

}

contract GetPsmTotalValueTests is GroveBasinTestBase {

    function test_totalAssets_balanceChanges() public {
        usds.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 1e18);

        usdc.mint(address(pocket), 1e6);

        assertEq(groveBasin.totalAssets(), 2e18);

        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 3.25e18);

        usds.burn(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 2.25e18);

        usdc.burn(address(pocket), 1e6);

        assertEq(groveBasin.totalAssets(), 1.25e18);

        creditToken.burn(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 0);
    }

    function test_totalAssets_conversionRateChanges() public {
        assertEq(groveBasin.totalAssets(), 0);

        usds.mint(address(groveBasin), 1e18);
        usdc.mint(address(pocket), 1e6);
        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 3.25e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.totalAssets(), 3.5e18);

        mockCreditTokenRateProvider.__setConversionRate(0.8e27);

        assertEq(groveBasin.totalAssets(), 2.8e18);
    }

    function test_totalAssets_bothChange() public {
        assertEq(groveBasin.totalAssets(), 0);

        usds.mint(address(groveBasin), 1e18);
        usdc.mint(address(pocket), 1e6);
        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 3.25e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        assertEq(groveBasin.totalAssets(), 3.5e18);

        creditToken.mint(address(groveBasin), 1e18);

        assertEq(groveBasin.totalAssets(), 5e18);
    }

    function testFuzz_totalAssets(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        usdsAmount     = _bound(usdsAmount,     0,         USDS_TOKEN_MAX);
        usdcAmount     = _bound(usdcAmount,     0,         USDC_TOKEN_MAX);
        creditTokenAmount    = _bound(creditTokenAmount,    0,         CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);

        usds.mint(address(groveBasin), usdsAmount);
        usdc.mint(address(pocket), usdcAmount);
        creditToken.mint(address(groveBasin), creditTokenAmount);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        assertEq(
            groveBasin.totalAssets(),
            usdsAmount + (usdcAmount * 1e12) + (creditTokenAmount * conversionRate / 1e27)
        );
    }

}
