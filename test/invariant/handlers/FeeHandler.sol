// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

contract FeeHandler is HandlerBase {

    uint256 public constant MAX_FEE_BPS = 500;

    address public owner;

    uint256 public setPurchaseFeeCount;
    uint256 public setRedemptionFeeCount;

    constructor(GroveBasin groveBasin_, address owner_) HandlerBase(groveBasin_) {
        owner = owner_;
    }

    function setPurchaseFee(uint256 feeSeed) external {
        // 1. Setup and bounds
        uint256 newFee = _bound(feeSeed, 0, MAX_FEE_BPS);

        // 2. Cache starting state
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);
        uint256 startingValue      = groveBasin.totalAssets();

        // 3. Perform action against protocol
        vm.prank(owner);
        groveBasin.setPurchaseFee(newFee);

        // 4. Perform action-specific assertions

        // Setting fees does not change conversion rate or total value
        assertEq(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            "FeeHandler/setPurchaseFee/conversion-rate-change"
        );

        assertEq(
            groveBasin.totalAssets(),
            startingValue,
            "FeeHandler/setPurchaseFee/groveBasin-total-value-change"
        );

        assertEq(
            groveBasin.purchaseFee(),
            newFee,
            "FeeHandler/setPurchaseFee/fee-not-set"
        );

        // 5. Update metrics tracking state
        _updateSharePrice();
        setPurchaseFeeCount++;
    }

    function setRedemptionFee(uint256 feeSeed) external {
        // 1. Setup and bounds
        uint256 newFee = _bound(feeSeed, 0, MAX_FEE_BPS);

        // 2. Cache starting state
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);
        uint256 startingValue      = groveBasin.totalAssets();

        // 3. Perform action against protocol
        vm.prank(owner);
        groveBasin.setRedemptionFee(newFee);

        // 4. Perform action-specific assertions

        // Setting fees does not change conversion rate or total value
        assertEq(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            "FeeHandler/setRedemptionFee/conversion-rate-change"
        );

        assertEq(
            groveBasin.totalAssets(),
            startingValue,
            "FeeHandler/setRedemptionFee/groveBasin-total-value-change"
        );

        assertEq(
            groveBasin.redemptionFee(),
            newFee,
            "FeeHandler/setRedemptionFee/fee-not-set"
        );

        // 5. Update metrics tracking state
        _updateSharePrice();
        setRedemptionFeeCount++;
    }

}
