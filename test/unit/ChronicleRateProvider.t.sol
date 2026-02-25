// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "forge-std/Test.sol";

import { ChronicleRateProvider } from "src/oracles/ChronicleRateProvider.sol";
import { MockChronicleOracle }   from "test/mocks/MockChronicleOracle.sol";

contract ChronicleRateProviderTests is Test {

    ChronicleRateProvider public rateProvider;
    MockChronicleOracle   public oracle;

    function setUp() public {
        oracle       = new MockChronicleOracle();
        rateProvider = new ChronicleRateProvider(address(oracle));

        oracle.__setVal(1e18);
    }

    function test_constructor() public view {
        assertEq(rateProvider.oracle(), address(oracle));
    }

    function test_constructor_revert_zeroOracle() public {
        vm.expectRevert("ChronicleRateProvider/zero-oracle");
        new ChronicleRateProvider(address(0));
    }

    function test_getConversionRate_atParity() public view {
        assertEq(rateProvider.getConversionRate(), 1e27);
    }

    function test_getConversionRate_above() public {
        oracle.__setVal(1.5e18);
        assertEq(rateProvider.getConversionRate(), 1.5e27);
    }

    function test_getConversionRate_below() public {
        oracle.__setVal(0.5e18);
        assertEq(rateProvider.getConversionRate(), 0.5e27);
    }

    function test_getConversionRate_revertsWhenNotPoked() public {
        MockChronicleOracle freshOracle = new MockChronicleOracle();
        ChronicleRateProvider freshProvider = new ChronicleRateProvider(address(freshOracle));

        vm.expectRevert("MockChronicleOracle/not-poked");
        freshProvider.getConversionRate();
    }

    function test_getConversionRateWithAge() public view {
        (uint256 rate, uint256 lastUpdated) = rateProvider.getConversionRateWithAge();
        assertEq(rate, 1e27);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_getConversionRateWithAge_updatesWithOracle() public {
        vm.warp(block.timestamp + 1 hours);
        oracle.__setVal(1.01e18);

        (uint256 rate, uint256 lastUpdated) = rateProvider.getConversionRateWithAge();
        assertEq(rate, 1.01e27);
        assertEq(lastUpdated, block.timestamp);
    }

    function test_getConversionRateWithAge_returnsOracleAge() public {
        uint256 specificAge = 1700000000;
        oracle.__setAge(specificAge);

        ( , uint256 lastUpdated) = rateProvider.getConversionRateWithAge();
        assertEq(lastUpdated, specificAge);
    }

    function test_getConversionRateWithAge_revertsWhenNotPoked() public {
        MockChronicleOracle freshOracle = new MockChronicleOracle();
        ChronicleRateProvider freshProvider = new ChronicleRateProvider(address(freshOracle));

        vm.expectRevert("MockChronicleOracle/not-poked");
        freshProvider.getConversionRateWithAge();
    }

    function test_getRatePrecision() public view {
        assertEq(rateProvider.getRatePrecision(), 1e27);
    }

    function testFuzz_getConversionRate(uint256 chronicleVal) public {
        chronicleVal = bound(chronicleVal, 1, type(uint128).max);
        oracle.__setVal(chronicleVal);

        uint256 expectedRate = chronicleVal * 1e27 / 1e18;
        assertEq(rateProvider.getConversionRate(), expectedRate);
    }

    function test_getConversionRate_updatesWithOracle() public {
        assertEq(rateProvider.getConversionRate(), 1e27);

        oracle.__setVal(2e18);
        assertEq(rateProvider.getConversionRate(), 2e27);

        oracle.__setVal(0.99e18);
        assertEq(rateProvider.getConversionRate(), 0.99e27);
    }

}
