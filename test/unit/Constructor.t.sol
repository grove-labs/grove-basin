// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract GroveBasinConstructorTests is GroveBasinTestBase {

    function test_constructor_invalidOwner() public {
        vm.expectRevert("GroveBasin/invalid-owner");
        new GroveBasin(address(0), address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidSwapToken() public {
        vm.expectRevert("GroveBasin/invalid-swapToken");
        new GroveBasin(owner, address(0), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-collateralToken");
        new GroveBasin(owner, address(swapToken), address(0), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-creditToken");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(0), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidSwapTokenRateProvider() public {
        vm.expectRevert("GroveBasin/invalid-swapTokenRateProvider");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(0), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCollateralTokenRateProvider() public {
        vm.expectRevert("GroveBasin/invalid-collateralTokenRateProvider");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(0), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCreditTokenRateProvider() public {
        vm.expectRevert("GroveBasin/invalid-creditTokenRateProvider");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(0));
    }

    function test_constructor_swapTokenCollateralTokenMatch() public {
        vm.expectRevert("GroveBasin/swapToken-collateralToken-same");
        new GroveBasin(owner, address(swapToken), address(swapToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_swapTokenCreditTokenMatch() public {
        vm.expectRevert("GroveBasin/swapToken-creditToken-same");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(swapToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenCreditTokenMatch() public {
        vm.expectRevert("GroveBasin/collateralToken-creditToken-same");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(collateralToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_swapTokenRateProviderZero() public {
        MockRateProvider(address(swapTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert("GroveBasin/swap-rate-provider-returns-zero");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenRateProviderZero() public {
        MockRateProvider(address(collateralTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert("GroveBasin/collateral-rate-provider-returns-zero");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_creditTokenRateProviderZero() public {
        MockRateProvider(address(creditTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert("GroveBasin/credit-rate-provider-returns-zero");
        new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_swapTokenDecimalsToHighBoundary() public {
        MockERC20 swapToken_ = new MockERC20("swapToken", "swapToken", 19);

        vm.expectRevert("GroveBasin/swapToken-precision-too-high");
        new GroveBasin(owner, address(swapToken_), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        swapToken_ = new MockERC20("swapToken", "swapToken", 18);

        new GroveBasin(owner, address(swapToken_), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenDecimalsToHighBoundary() public {
        MockERC20 collateralToken_ = new MockERC20("collateralToken", "collateralToken", 19);

        vm.expectRevert("GroveBasin/collateralToken-precision-too-high");
        new GroveBasin(owner, address(swapToken), address(collateralToken_), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        collateralToken_ = new MockERC20("collateralToken", "collateralToken", 18);

        new GroveBasin(owner, address(swapToken), address(collateralToken_), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));
    }

    function test_constructor() public {
        groveBasin = new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        assertTrue(groveBasin.hasRole(groveBasin.OWNER_ROLE(), owner));
        assertEq(groveBasin.OWNER_ROLE(), groveBasin.DEFAULT_ADMIN_ROLE());

        assertEq(address(groveBasin.swapToken()),              address(swapToken));
        assertEq(address(groveBasin.collateralToken()),             address(collateralToken));
        assertEq(address(groveBasin.creditToken()),                 address(creditToken));
        assertEq(address(groveBasin.swapTokenRateProvider()),  address(swapTokenRateProvider));
        assertEq(address(groveBasin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(groveBasin.creditTokenRateProvider()),     address(creditTokenRateProvider));
        assertEq(groveBasin.maxSwapSize(), 50_000_000e18);
    }

}
