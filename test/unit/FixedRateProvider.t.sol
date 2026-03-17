// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { FixedRateProvider } from "src/oracles/FixedRateProvider.sol";

contract FixedRateProviderTests is Test {

    FixedRateProvider public rateProvider;

    function setUp() public {
        rateProvider = new FixedRateProvider(1e27);
    }

    function test_constructor() public view {
        assertEq(rateProvider.rate(), 1e27);
    }

    function test_constructor_revert_zeroRate() public {
        vm.expectRevert("FixedRateProvider/zero-rate");
        new FixedRateProvider(0);
    }

    function test_getConversionRate() public view {
        assertEq(rateProvider.getConversionRate(), 1e27);
    }

    function test_getConversionRateWithAge() public view {
        (uint256 rate, uint256 lastUpdated) = rateProvider.getConversionRateWithAge();
        assertEq(rate, 1e27);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_getConversionRateWithAge_changesWithTime() public {
        ( , uint256 ts1) = rateProvider.getConversionRateWithAge();

        vm.warp(block.timestamp + 1 hours);

        ( , uint256 ts2) = rateProvider.getConversionRateWithAge();
        assertEq(ts2, ts1 + 1 hours);
    }

    function test_getRatePrecision() public view {
        assertEq(rateProvider.getRatePrecision(), 1e27);
    }

    function testFuzz_getConversionRate(uint256 rate) public {
        rate = bound(rate, 1, type(uint256).max);
        FixedRateProvider provider = new FixedRateProvider(rate);
        assertEq(provider.getConversionRate(), rate);
    }

    function test_rateIsImmutable() public {
        FixedRateProvider provider1 = new FixedRateProvider(1.5e27);
        FixedRateProvider provider2 = new FixedRateProvider(0.5e27);

        assertEq(provider1.getConversionRate(), 1.5e27);
        assertEq(provider2.getConversionRate(), 0.5e27);

        vm.warp(block.timestamp + 365 days);

        assertEq(provider1.getConversionRate(), 1.5e27);
        assertEq(provider2.getConversionRate(), 0.5e27);
    }

}
