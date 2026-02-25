// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasin } from "src/GroveBasin.sol";

contract GroveBasinHarness is GroveBasin {

    constructor(
        address owner_,
        address swapToken_,
        address collateralToken_,
        address creditToken_,
        address swapTokenRateProvider_,
        address collateralTokenRateProvider_,
        address creditTokenRateProvider_
    )
        GroveBasin(owner_, swapToken_, collateralToken_, creditToken_, swapTokenRateProvider_, collateralTokenRateProvider_, creditTokenRateProvider_) {}

    function getAssetValue(address asset, uint256 amount, bool roundUp)
        external view returns (uint256)
    {
        return _getAssetValue(asset, amount, roundUp);
    }

    function getSwapTokenValue(uint256 amount) external view returns (uint256) {
        return _getSwapTokenValue(amount);
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

    function getConversionRate(address rateProvider) external view returns (uint256) {
        return _getConversionRate(rateProvider);
    }

}
