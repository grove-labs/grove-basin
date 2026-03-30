// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }  from "src/GroveBasin.sol";
import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract GroveBasinConstructorTests is GroveBasinTestBase {

    function test_constructor_invalidOwner() public {
        vm.expectRevert(IGroveBasin.InvalidOwner.selector);
        new GroveBasin(address(0), lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidLiquidityProvider() public {
        vm.expectRevert(IGroveBasin.InvalidLiquidityProvider.selector);
        new GroveBasin(owner, address(0), address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidSwapToken() public {
        vm.expectRevert(IGroveBasin.ZeroTokenAddress.selector);
        new GroveBasin(owner, lp, address(0), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCollateralToken() public {
        vm.expectRevert(IGroveBasin.ZeroTokenAddress.selector);
        new GroveBasin(owner, lp, address(swapToken), address(0), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCreditToken() public {
        vm.expectRevert(IGroveBasin.ZeroTokenAddress.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(0), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidSwapTokenRateProvider() public {
        vm.expectRevert(IGroveBasin.ZeroRateProviderAddress.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(0), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCollateralTokenRateProvider() public {
        vm.expectRevert(IGroveBasin.ZeroRateProviderAddress.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(0), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCreditTokenRateProvider() public {
        vm.expectRevert(IGroveBasin.ZeroRateProviderAddress.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(0));
    }

    function test_constructor_swapTokenCollateralTokenMatch() public {
        vm.expectRevert(IGroveBasin.DuplicateTokens.selector);
        new GroveBasin(owner, lp, address(swapToken), address(swapToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_swapTokenCreditTokenMatch() public {
        vm.expectRevert(IGroveBasin.DuplicateTokens.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(swapToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenCreditTokenMatch() public {
        vm.expectRevert(IGroveBasin.DuplicateTokens.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(collateralToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_swapTokenRateProviderZero() public {
        MockRateProvider(address(swapTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert(IGroveBasin.RateProviderReturnsZero.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenRateProviderZero() public {
        MockRateProvider(address(collateralTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert(IGroveBasin.RateProviderReturnsZero.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_creditTokenRateProviderZero() public {
        MockRateProvider(address(creditTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert(IGroveBasin.RateProviderReturnsZero.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_swapTokenDecimalsToHighBoundary() public {
        MockERC20 swapToken_ = new MockERC20("swapToken", "swapToken", 19);

        vm.expectRevert(IGroveBasin.PrecisionTooHigh.selector);
        new GroveBasin(owner, lp, address(swapToken_), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        swapToken_ = new MockERC20("swapToken", "swapToken", 18);

        new GroveBasin(owner, lp, address(swapToken_), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_creditTokenDecimalsToHighBoundary() public {
        MockERC20 creditToken_ = new MockERC20("creditToken", "creditToken", 19);

        vm.expectRevert(IGroveBasin.PrecisionTooHigh.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken_), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        creditToken_ = new MockERC20("creditToken", "creditToken", 18);

        new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken_), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenDecimalsToHighBoundary() public {
        MockERC20 collateralToken_ = new MockERC20("collateralToken", "collateralToken", 19);

        vm.expectRevert(IGroveBasin.PrecisionTooHigh.selector);
        new GroveBasin(owner, lp, address(swapToken), address(collateralToken_), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        collateralToken_ = new MockERC20("collateralToken", "collateralToken", 18);

        new GroveBasin(owner, lp, address(swapToken), address(collateralToken_), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor() public {
        groveBasin = new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        assertTrue(groveBasin.hasRole(groveBasin.OWNER_ROLE(), owner));
        assertEq(groveBasin.OWNER_ROLE(), groveBasin.DEFAULT_ADMIN_ROLE());

        assertEq(groveBasin.liquidityProvider(), lp);

        assertEq(groveBasin.swapToken(),                   address(swapToken));
        assertEq(groveBasin.collateralToken(),             address(collateralToken));
        assertEq(groveBasin.creditToken(),                 address(creditToken));
        assertEq(address(groveBasin.swapTokenRateProvider()),       address(swapTokenRateProvider));
        assertEq(address(groveBasin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(groveBasin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(groveBasin.maxSwapSize(),           50_000_000e18);
        assertEq(groveBasin.maxSwapSizeLowerBound(), 0);
        assertEq(groveBasin.maxSwapSizeUpperBound(), 1_000_000_000e18);
    }

}
