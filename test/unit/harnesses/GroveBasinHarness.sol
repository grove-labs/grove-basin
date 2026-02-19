// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { GroveBasin } from "src/GroveBasin.sol";

contract GroveBasinHarness is GroveBasin {

    constructor(
        address owner_,
        address usdc_,
        address collateralToken_,
        address creditToken_,
        address creditTokenRateProvider_
    )
        GroveBasin(owner_, usdc_, collateralToken_, creditToken_, creditTokenRateProvider_) {}

    function getAssetValue(address asset, uint256 amount, bool roundUp)
        external view returns (uint256)
    {
        return _getAssetValue(asset, amount, roundUp);
    }

    function getUsdcValue(uint256 amount) external view returns (uint256) {
        return _getUsdcValue(amount);
    }

    function getCollateralTokenValue(uint256 amount) external view returns (uint256) {
        return _getCollateralTokenValue(amount);
    }

    function getCreditTokenValue(uint256 amount, bool roundUp) external view returns (uint256) {
        return _getCreditTokenValue(amount, roundUp);
    }

    function getAssetCustodian(address asset) external view returns (address) {
        return _getAssetCustodian(asset);
    }

}
