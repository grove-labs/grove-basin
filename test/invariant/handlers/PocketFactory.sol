// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { AaveV3UsdtPocket } from "src/pockets/AaveV3UsdtPocket.sol";
import { MorphoUsdtPocket } from "src/pockets/MorphoUsdtPocket.sol";

import { MockAToken }       from "test/mocks/MockAToken.sol";
import { MockAaveV3Pool }   from "test/mocks/MockAaveV3Pool.sol";
import { MockERC4626Vault } from "test/mocks/MockERC4626Vault.sol";

contract PocketFactory {

    function createAavePocket(
        address groveBasin,
        address swapToken
    ) external returns (address) {
        MockAToken mockAToken = new MockAToken("aToken", "aToken", 6, swapToken);
        MockAaveV3Pool pool  = new MockAaveV3Pool(address(mockAToken), swapToken);

        mockAToken.mint(address(pool), type(uint128).max);

        AaveV3UsdtPocket pocket_ = new AaveV3UsdtPocket(
            groveBasin,
            swapToken,
            address(mockAToken),
            address(pool)
        );

        return address(pocket_);
    }

    function createMorphoPocket(
        address groveBasin,
        address swapToken
    ) external returns (address) {
        MockERC4626Vault vault = new MockERC4626Vault(swapToken);

        MorphoUsdtPocket pocket_ = new MorphoUsdtPocket(
            groveBasin,
            swapToken,
            address(vault)
        );

        return address(pocket_);
    }

}
