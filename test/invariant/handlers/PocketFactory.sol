// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { AaveV3UsdtPocket } from "src/pockets/AaveV3UsdtPocket.sol";
import { MorphoUsdtPocket } from "src/pockets/MorphoUsdtPocket.sol";
import { UsdsUsdcPocket }   from "src/pockets/UsdsUsdcPocket.sol";

import { MockAaveV3Pool }   from "test/mocks/MockAaveV3Pool.sol";
import { MockERC4626Vault } from "test/mocks/MockERC4626Vault.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

contract PocketFactory {

    function createAavePocket(
        address groveBasin,
        address swapToken
    ) external returns (address) {
        MockERC20 mockAToken = new MockERC20("aToken", "aToken", 6);
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

    function createUsdsUsdcPocket(
        address groveBasin,
        address swapToken,
        address usds,
        address psm
    ) external returns (address) {
        UsdsUsdcPocket pocket_ = new UsdsUsdcPocket(
            groveBasin,
            swapToken,
            usds,
            psm
        );

        return address(pocket_);
    }

}
