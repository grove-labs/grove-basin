// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { AaveV3UsdtPocket } from "src/AaveV3UsdtPocket.sol";
import { MorphoUsdtPocket } from "src/MorphoUsdtPocket.sol";
import { UsdsUsdcPocket }   from "src/UsdsUsdcPocket.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { MockAaveV3Pool }   from "test/mocks/MockAaveV3Pool.sol";
import { MockERC4626Vault } from "test/mocks/MockERC4626Vault.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

import { HandlerBase, GroveBasin } from "test/invariant/handlers/HandlerBase.sol";

contract OwnerHandler is HandlerBase {

    /**********************************************************************************************/
    /*** Structs to avoid stack-too-deep                                                        ***/
    /**********************************************************************************************/

    struct SetPocketSnapshot {
        address oldPocket;
        uint256 totalAssets;
        uint256 startingConversion;
    }

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    MockERC20 public swapToken;
    MockERC20 public aToken;
    MockERC20 public usds;

    MockPSM public psm;

    uint256 public pocketNonce;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(
        GroveBasin groveBasin_,
        MockERC20  swapToken_,
        MockERC20  aToken_,
        MockERC20  usds_,
        MockPSM    psm_
    ) HandlerBase(groveBasin_) {
        swapToken = swapToken_;
        aToken    = aToken_;
        usds      = usds_;
        psm       = psm_;
    }

    /**********************************************************************************************/
    /*** Handler functions                                                                      ***/
    /**********************************************************************************************/

    function setPocket(uint256 pocketTypeSeed) public {
        // Use modular arithmetic to pick pocket type: 0 = Aave, 1 = Morpho, 2 = UsdsUsdc
        uint256 pocketType = pocketTypeSeed % 3;
        pocketNonce++;

        SetPocketSnapshot memory snap;
        snap.oldPocket          = groveBasin.pocket();
        snap.totalAssets        = groveBasin.totalAssets();
        snap.startingConversion = groveBasin.convertToAssetValue(1e18);

        address newPocket;

        if (pocketType == 0) {
            newPocket = _createAavePocket();
        } else if (pocketType == 1) {
            newPocket = _createMorphoPocket();
        } else {
            newPocket = _createUsdsUsdcPocket();
        }

        // Avoid "same pocket" error
        if (newPocket == snap.oldPocket) return;

        groveBasin.setPocket(newPocket);

        // --- No-dust invariant: old pocket must have exactly zero balance in all tokens ---
        _assertOldPocketZeroBalance(snap.oldPocket);

        // --- totalAssets conservation ---
        assertEq(
            groveBasin.totalAssets(),
            snap.totalAssets,
            "OwnerHandler/total-assets"
        );

        // --- Conversion rate conservation ---
        assertEq(
            groveBasin.convertToAssetValue(1e18),
            snap.startingConversion,
            "OwnerHandler/starting-conversion"
        );
    }

    /**********************************************************************************************/
    /*** Internal: pocket factory functions                                                     ***/
    /**********************************************************************************************/

    function _createAavePocket() internal returns (address) {
        // Create mock aToken and pool for each new pocket
        MockERC20 mockAToken = new MockERC20("aToken", "aToken", 6);
        MockAaveV3Pool pool  = new MockAaveV3Pool(address(mockAToken), address(swapToken));

        // Fund the pool with aTokens so supply() can transfer them
        mockAToken.mint(address(pool), type(uint128).max);

        AaveV3UsdtPocket pocket_ = new AaveV3UsdtPocket(
            address(groveBasin),
            address(this),           // admin
            address(swapToken),
            address(mockAToken),
            address(pool)
        );

        return address(pocket_);
    }

    function _createMorphoPocket() internal returns (address) {
        MockERC4626Vault vault = new MockERC4626Vault(address(swapToken));

        MorphoUsdtPocket pocket_ = new MorphoUsdtPocket(
            address(groveBasin),
            address(this),           // admin
            address(swapToken),
            address(vault)
        );

        return address(pocket_);
    }

    function _createUsdsUsdcPocket() internal returns (address) {
        UsdsUsdcPocket pocket_ = new UsdsUsdcPocket(
            address(groveBasin),
            address(this),           // admin
            address(swapToken),
            address(usds),
            address(psm)
        );

        return address(pocket_);
    }

    /**********************************************************************************************/
    /*** Internal: no-dust assertion                                                            ***/
    /**********************************************************************************************/

    function _assertOldPocketZeroBalance(address oldPocket) internal view {
        // swapToken balance must be zero (applies to all pocket types)
        assertEq(
            swapToken.balanceOf(oldPocket),
            0,
            "OwnerHandler/old-pocket-swap-balance"
        );

        // Check if old pocket is a real pocket (not the basin itself)
        if (oldPocket == address(groveBasin)) return;

        // Check availableBalance is zero for the pocket
        assertEq(
            IGroveBasinPocket(oldPocket).availableBalance(address(swapToken)),
            0,
            "OwnerHandler/old-pocket-available-balance"
        );
    }

}
