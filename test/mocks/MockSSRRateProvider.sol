// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { SSRAuthOracle } from "lib/xchain-ssr-oracle/src/SSRAuthOracle.sol";

import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

contract MockSSRRateProvider is IRateProviderLike {

    uint256 public constant RATE_PRECISION = 1e27;

    SSRAuthOracle public immutable ssrOracle;

    constructor(SSRAuthOracle ssrOracle_) {
        ssrOracle = ssrOracle_;
    }

    function getConversionRate() external view override returns (uint256) {
        return ssrOracle.getConversionRate();
    }

    function getConversionRateWithAge() external view override returns (uint256, uint256) {
        return (ssrOracle.getConversionRate(), ssrOracle.getRho());
    }

    function getRatePrecision() external pure override returns (uint256) {
        return RATE_PRECISION;
    }

}
