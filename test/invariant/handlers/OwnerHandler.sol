// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

contract OwnerHandler is HandlerBase {

    MockERC20 public usdc;

    constructor(GroveBasin groveBasin_, MockERC20 usdc_) HandlerBase(groveBasin_) {
        usdc = usdc_;
    }

    function setPocket(string memory salt) public {
        address newPocket = makeAddr(salt);

        // Avoid "same pocket" error
        if (newPocket == groveBasin.pocket()) {
            newPocket = makeAddr(string(abi.encodePacked(salt, "salt")));
        }

        // Assumption is made that the pocket will always infinite approve the GroveBasin
        vm.prank(newPocket);
        usdc.approve(address(groveBasin), type(uint256).max);

        uint256 oldPocketBalance   = usdc.balanceOf(groveBasin.pocket());
        uint256 newPocketBalance   = usdc.balanceOf(newPocket);
        uint256 totalAssets        = groveBasin.totalAssets();
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);

        address oldPocket = groveBasin.pocket();

        groveBasin.setPocket(newPocket);

        // Old pocket should be cleared of USDC
        assertEq(
            usdc.balanceOf(oldPocket),
            0,
            "OwnerHandler/old-pocket-balance"
        );

        // New pocket should get full pocket balance
        assertEq(
            usdc.balanceOf(newPocket),
            newPocketBalance + oldPocketBalance,
            "OwnerHandler/new-pocket-balance"
        );

        // Total assets should be exactly the same
        assertEq(
            groveBasin.totalAssets(),
            totalAssets,
            "OwnerHandler/total-assets"
        );

        // Conversion rate should be exactly the same
        assertEq(
            groveBasin.convertToAssetValue(1e18),
            startingConversion,
            "OwnerHandler/starting-conversion"
        );
    }

}
