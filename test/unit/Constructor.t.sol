// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract PSMConstructorTests is GroveBasinTestBase {

    function test_constructor_invalidOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new GroveBasin(address(0), address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_invalidUsdc() public {
        vm.expectRevert("GroveBasin/invalid-usdc");
        new GroveBasin(owner, address(0), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_invalidUsds() public {
        vm.expectRevert("GroveBasin/invalid-usds");
        new GroveBasin(owner, address(usdc), address(0), address(susds), address(rateProvider));
    }

    function test_constructor_invalidSUsds() public {
        vm.expectRevert("GroveBasin/invalid-susds");
        new GroveBasin(owner, address(usdc), address(usds), address(0), address(rateProvider));
    }

    function test_constructor_invalidRateProvider() public {
        vm.expectRevert("GroveBasin/invalid-rateProvider");
        new GroveBasin(owner, address(usdc), address(usds), address(susds), address(0));
    }

    function test_constructor_usdcUsdsMatch() public {
        vm.expectRevert("GroveBasin/usdc-usds-same");
        new GroveBasin(owner, address(usdc), address(usdc), address(susds), address(rateProvider));
    }

    function test_constructor_usdcSUsdsMatch() public {
        vm.expectRevert("GroveBasin/usdc-susds-same");
        new GroveBasin(owner, address(usdc), address(usds), address(usdc), address(rateProvider));
    }

    function test_constructor_usdsSUsdsMatch() public {
        vm.expectRevert("GroveBasin/usds-susds-same");
        new GroveBasin(owner, address(usdc), address(usds), address(usds), address(rateProvider));
    }

    function test_constructor_rateProviderZero() public {
        MockRateProvider(address(rateProvider)).__setConversionRate(0);
        vm.expectRevert("GroveBasin/rate-provider-returns-zero");
        new GroveBasin(owner, address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_usdcDecimalsToHighBoundary() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 19);

        vm.expectRevert("GroveBasin/usdc-precision-too-high");
        new GroveBasin(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        usdc = new MockERC20("USDC", "USDC", 18);

        new GroveBasin(owner, address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_usdsDecimalsToHighBoundary() public {
        MockERC20 usds = new MockERC20("USDS", "USDS", 19);

        vm.expectRevert("GroveBasin/usds-precision-too-high");
        new GroveBasin(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        usds = new MockERC20("USDS", "USDS", 18);

        new GroveBasin(owner, address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor() public {
        // Deploy new GroveBasin to get test coverage
        groveBasin = new GroveBasin(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        assertEq(address(groveBasin.owner()),        address(owner));
        assertEq(address(groveBasin.usdc()),         address(usdc));
        assertEq(address(groveBasin.usds()),         address(usds));
        assertEq(address(groveBasin.susds()),        address(susds));
        assertEq(address(groveBasin.rateProvider()), address(rateProvider));
    }

}
