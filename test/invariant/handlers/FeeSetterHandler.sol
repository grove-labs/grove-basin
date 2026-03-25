// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

contract FeeSetterHandler is HandlerBase {

    address public owner;
    uint256 public maxFee;

    uint256 public setPurchaseFeeCount;
    uint256 public setRedemptionFeeCount;

    constructor(GroveBasin groveBasin_, uint256 maxFee_, address owner_) HandlerBase(groveBasin_) {
        maxFee = maxFee_;
        owner  = owner_;
    }

    function setPurchaseFee(uint256 fee) external {
        fee = _bound(fee, groveBasin.minFee(), maxFee);

        uint256 startingValue = groveBasin.totalAssets();

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        assertEq(groveBasin.purchaseFee(), fee, "FeeSetterHandler/setPurchaseFee/fee-not-set");

        assertEq(
            groveBasin.totalAssets(),
            startingValue,
            "FeeSetterHandler/setPurchaseFee/total-value-change"
        );

        setPurchaseFeeCount++;
    }

    function setRedemptionFee(uint256 fee) external {
        fee = _bound(fee, groveBasin.minFee(), maxFee);

        uint256 startingValue = groveBasin.totalAssets();

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        assertEq(groveBasin.redemptionFee(), fee, "FeeSetterHandler/setRedemptionFee/fee-not-set");

        assertEq(
            groveBasin.totalAssets(),
            startingValue,
            "FeeSetterHandler/setRedemptionFee/total-value-change"
        );

        setRedemptionFeeCount++;
    }

}
