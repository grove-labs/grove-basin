// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { GroveBasin } from "src/GroveBasin.sol";

contract TransferHandler is HandlerBase {

    MockERC20[3] public assets;

    uint256 public transferCount;

    mapping(address asset => uint256) public transfersIn;

    constructor(
        GroveBasin groveBasin_,
        MockERC20  usdc,
        MockERC20  collateralToken,
        MockERC20  creditToken
    ) HandlerBase(groveBasin_) {
        assets[0] = usdc;
        assets[1] = collateralToken;
        assets[2] = creditToken;
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function transfer(uint256 assetSeed, string memory senderSeed, uint256 amount) external {
        // 1. Setup and bounds
        MockERC20 asset = _getAsset(assetSeed);
        address   sender = makeAddr(senderSeed);

        // 2. Cache starting state
        uint256 startingConversion = groveBasin.convertToAssetValue(1e18);
        uint256 startingValue      = groveBasin.totalAssets();

        // Bounding to 10 million here because 1 trillion introduces unrealistic conditions with
        // large rounding errors. Would rather keep tolerances smaller with a lower upper bound
        // on transfer amounts.
        amount = _bound(amount, 1, 10_000_000 * 10 ** asset.decimals());

        address custodian = address(asset) == address(assets[0]) ? groveBasin.pocket() : address(groveBasin);

        // 3. Perform action against protocol
        asset.mint(sender, amount);
        vm.prank(sender);
        asset.transfer(custodian, amount);

        // 4. Update ghost variable(s)
        transfersIn[address(asset)] += amount;

        // 5. Perform action-specific assertions
        assertGe(
            groveBasin.convertToAssetValue(1e18) + 1,
            startingConversion,
            "TransferHandler/transfer/conversion-rate-decrease"
        );

        assertGe(
            groveBasin.totalAssets() + 1,
            startingValue,
            "TransferHandler/transfer/groveBasin-total-value-decrease"
        );

        // 6. Update metrics tracking state
        transferCount += 1;
    }

}
