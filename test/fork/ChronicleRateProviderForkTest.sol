// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { ChronicleRateProvider } from "src/rate-providers/ChronicleRateProvider.sol";

interface IChronicleAuthLike {
    function kiss(address who) external;
    function tolled(address who) external view returns (bool);
    function read() external view returns (uint256);
    function readWithAge() external view returns (uint256 val, uint256 age);
    function tryRead() external view returns (bool ok, uint256 val);
    function tryReadWithAge() external view returns (bool ok, uint256 val, uint256 age);
}

abstract contract ChronicleRateProviderForkTestBase is Test {

    address public constant BUIDL_ORACLE = 0x2d6db2116aD7a6e203E72C8DCCfFf23f5315b0Dd;
    address public constant JTRSY_ORACLE = 0x59ef4BE3eDDF0270c4878b7B945bbeE13fb33d0D;

    function _kissOnChronicle(address oracle, address who) internal {
        // Chronicle Auth pattern: wards mapping is at storage slot 0.
        vm.store(
            oracle,
            keccak256(abi.encode(address(this), uint256(0))),
            bytes32(uint256(1))
        );
        IChronicleAuthLike(oracle).kiss(who);
    }

    function _getBlock() internal pure virtual returns (uint256) {
        return 24_522_338;
    }

}

/**********************************************************************************************/
/*** BUIDL Chronicle Oracle fork tests                                                      ***/
/**********************************************************************************************/

contract ChronicleRateProviderForkTest_BUIDL is ChronicleRateProviderForkTestBase {

    ChronicleRateProvider public rateProvider;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        rateProvider = new ChronicleRateProvider(BUIDL_ORACLE);
        _kissOnChronicle(BUIDL_ORACLE, address(rateProvider));
    }

    function test_oracle() public view {
        assertEq(rateProvider.oracle(), BUIDL_ORACLE);
    }

    function test_tolled() public view {
        assertTrue(IChronicleAuthLike(BUIDL_ORACLE).tolled(address(rateProvider)));
    }

    function test_getConversionRate() public view {
        uint256 rate = rateProvider.getConversionRate();
        assertGt(rate, 0);
    }

    function test_getConversionRate_reasonable() public view {
        uint256 rate = rateProvider.getConversionRate();
        // BUIDL is a tokenized money-market fund, expect rate near 1e27 (within 10%)
        assertGe(rate, 0.9e27);
        assertLe(rate, 1.1e27);
    }

    function test_getConversionRateWithAge() public view {
        (uint256 rate, uint256 age) = rateProvider.getConversionRateWithAge();
        assertGt(rate, 0);
        assertGt(age,  0);
    }

    function test_getConversionRateWithAge_ageIsRecent() public view {
        (, uint256 age) = rateProvider.getConversionRateWithAge();
        // Age should be within the last 7 days of the fork block
        assertGt(age, block.timestamp - 7 days);
        assertLe(age, block.timestamp);
    }

    function test_getRatePrecision() public view {
        assertEq(rateProvider.getRatePrecision(), 1e27);
    }

    function test_revert_whenNotTolled() public {
        ChronicleRateProvider untolled = new ChronicleRateProvider(BUIDL_ORACLE);
        vm.expectRevert();
        untolled.getConversionRate();
    }

}

/**********************************************************************************************/
/*** JTRSY Chronicle Oracle fork tests                                                      ***/
/**********************************************************************************************/

contract ChronicleRateProviderForkTest_JTRSY is ChronicleRateProviderForkTestBase {

    ChronicleRateProvider public rateProvider;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        rateProvider = new ChronicleRateProvider(JTRSY_ORACLE);
        _kissOnChronicle(JTRSY_ORACLE, address(rateProvider));
    }

    function test_oracle() public view {
        assertEq(rateProvider.oracle(), JTRSY_ORACLE);
    }

    function test_tolled() public view {
        assertTrue(IChronicleAuthLike(JTRSY_ORACLE).tolled(address(rateProvider)));
    }

    function test_getConversionRate() public view {
        uint256 rate = rateProvider.getConversionRate();
        assertGt(rate, 0);
    }

    function test_getConversionRate_reasonable() public view {
        uint256 rate = rateProvider.getConversionRate();
        // JTRSY is a Centrifuge treasury token, expect rate roughly 1.0-1.2
        assertGe(rate, 0.9e27);
        assertLe(rate, 1.5e27);
    }

    function test_getConversionRateWithAge() public view {
        (uint256 rate, uint256 age) = rateProvider.getConversionRateWithAge();
        assertGt(rate, 0);
        assertGt(age,  0);
    }

    function test_getConversionRateWithAge_ageIsRecent() public view {
        (, uint256 age) = rateProvider.getConversionRateWithAge();
        assertGt(age, block.timestamp - 7 days);
        assertLe(age, block.timestamp);
    }

    function test_getRatePrecision() public view {
        assertEq(rateProvider.getRatePrecision(), 1e27);
    }

    function test_revert_whenNotTolled() public {
        ChronicleRateProvider untolled = new ChronicleRateProvider(JTRSY_ORACLE);
        vm.expectRevert();
        untolled.getConversionRate();
    }

}
