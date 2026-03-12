// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract RateDecreaseHandler is HandlerBase {

    uint256 public rate;

    MockRateProvider public creditTokenRateProvider;

    uint256 public decreaseRateCount;

    constructor(GroveBasin groveBasin_, address creditTokenRateProvider_, uint256 initialRate) HandlerBase(groveBasin_) {
        creditTokenRateProvider = MockRateProvider(creditTokenRateProvider_);
        rate                    = initialRate;
    }

    function decreaseRate(uint256 rateDecrease) external {
        // 1. Setup and bounds

        // Decrease the rate by up to 10% of the current rate
        uint256 maxDecrease = rate / 10;
        uint256 boundedDecrease = _bound(rateDecrease, 0, maxDecrease);

        rate -= boundedDecrease;

        // 2. Perform action against protocol
        creditTokenRateProvider.__setConversionRate(rate);

        // 3. Perform action-specific assertions
        // NOTE: After a rate decrease, conversion rate and total value CAN decrease.
        //       No assertGe on conversion or total value — this is expected behavior.

        // 4. Update metrics tracking state
        _updateSharePrice();
        decreaseRateCount++;
    }

}
