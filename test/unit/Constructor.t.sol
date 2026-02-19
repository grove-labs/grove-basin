// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract GroveBasinConstructorTests is GroveBasinTestBase {

    function test_constructor_invalidOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new GroveBasin(address(0), address(usdc), address(collateralToken), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor_invalidUsdc() public {
        vm.expectRevert("GroveBasin/invalid-usdc");
        new GroveBasin(owner, address(0), address(collateralToken), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-collateralToken");
        new GroveBasin(owner, address(usdc), address(0), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-creditToken");
        new GroveBasin(owner, address(usdc), address(collateralToken), address(0), address(creditTokenRateProvider));
    }

    function test_constructor_invalidCreditTokenRateProvider() public {
        vm.expectRevert("GroveBasin/invalid-creditTokenRateProvider");
        new GroveBasin(owner, address(usdc), address(collateralToken), address(creditToken), address(0));
    }

    function test_constructor_usdcCollateralTokenMatch() public {
        vm.expectRevert("GroveBasin/usdc-collateralToken-same");
        new GroveBasin(owner, address(usdc), address(usdc), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor_usdcCreditTokenMatch() public {
        vm.expectRevert("GroveBasin/usdc-creditToken-same");
        new GroveBasin(owner, address(usdc), address(collateralToken), address(usdc), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenCreditTokenMatch() public {
        vm.expectRevert("GroveBasin/collateralToken-creditToken-same");
        new GroveBasin(owner, address(usdc), address(collateralToken), address(collateralToken), address(creditTokenRateProvider));
    }

    function test_constructor_creditTokenRateProviderZero() public {
        MockRateProvider(address(creditTokenRateProvider)).__setConversionRate(0);
        vm.expectRevert("GroveBasin/rate-provider-returns-zero");
        new GroveBasin(owner, address(usdc), address(collateralToken), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor_usdcDecimalsToHighBoundary() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 19);

        vm.expectRevert("GroveBasin/usdc-precision-too-high");
        new GroveBasin(owner, address(usdc), address(collateralToken), address(creditToken), address(creditTokenRateProvider));

        usdc = new MockERC20("USDC", "USDC", 18);

        new GroveBasin(owner, address(usdc), address(collateralToken), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor_collateralTokenDecimalsToHighBoundary() public {
        MockERC20 collateralToken_ = new MockERC20("collateralToken", "collateralToken", 19);

        vm.expectRevert("GroveBasin/collateralToken-precision-too-high");
        new GroveBasin(owner, address(usdc), address(collateralToken_), address(creditToken), address(creditTokenRateProvider));

        collateralToken_ = new MockERC20("collateralToken", "collateralToken", 18);

        new GroveBasin(owner, address(usdc), address(collateralToken_), address(creditToken), address(creditTokenRateProvider));
    }

    function test_constructor() public {
        // Deploy new GroveBasin to get test coverage
        groveBasin = new GroveBasin(owner, address(usdc), address(collateralToken), address(creditToken), address(creditTokenRateProvider));

        assertEq(address(groveBasin.owner()),                   address(owner));
        assertEq(address(groveBasin.usdc()),                    address(usdc));
        assertEq(address(groveBasin.collateralToken()),         address(collateralToken));
        assertEq(address(groveBasin.creditToken()),             address(creditToken));
        assertEq(address(groveBasin.creditTokenRateProvider()), address(creditTokenRateProvider));
    }

}
