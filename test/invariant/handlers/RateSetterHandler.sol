// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract RateSetterHandler is HandlerBase {

    uint256 public rate;

    MockRateProvider public creditTokenRateProvider;

    uint256 public setRateCount;

    constructor(GroveBasin groveBasin_, address creditTokenRateProvider_, uint256 initialRate) HandlerBase(groveBasin_) {
        creditTokenRateProvider = MockRateProvider(creditTokenRateProvider_);
        rate                    = initialRate;
    }

    function setRate(uint256 rateIncrease) external {
        // 1. Setup and bounds

        // Increase the rate by up to 5%
        rate += _bound(rateIncrease, 0, 0.05e27);

        // 2. Cache starting state
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);
        uint256 startingValue      = groveBasin.totalAssets();

        // 3. Perform action against protocol
        creditTokenRateProvider.__setConversionRate(rate);

        // 4. Perform action-specific assertions
        assertGe(
            groveBasin.convertToAssetValue(1e18) + 1,
            startingConversion,
            "RateSetterHandler/setRate/conversion-rate-decrease"
        );

        assertGe(
            groveBasin.totalAssets() + 1,
            startingValue,
            "RateSetterHandler/setRate/groveBasin-total-value-decrease"
        );

        // 5. Update metrics tracking state
        setRateCount++;
    }

}
