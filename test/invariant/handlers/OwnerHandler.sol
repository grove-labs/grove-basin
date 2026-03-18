// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { MockPSM } from "test/mocks/MockPSM.sol";

import { HandlerBase, GroveBasin }  from "test/invariant/handlers/HandlerBase.sol";
import { PocketFactory }            from "test/invariant/handlers/PocketFactory.sol";
import { UsdsUsdcPocketFactory }    from "test/invariant/handlers/UsdsUsdcPocketFactory.sol";

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
    MockERC20 public usds;

    MockPSM public psm;

    address public groveProxy;

    PocketFactory          public pocketFactory;
    UsdsUsdcPocketFactory  public usdsUsdcPocketFactory;

    uint256 public pocketNonce;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(
        GroveBasin            groveBasin_,
        MockERC20             swapToken_,
        MockERC20             usds_,
        MockPSM               psm_,
        address               groveProxy_,
        PocketFactory         pocketFactory_,
        UsdsUsdcPocketFactory usdsUsdcPocketFactory_
    ) HandlerBase(groveBasin_) {
        swapToken             = swapToken_;
        usds                  = usds_;
        psm                   = psm_;
        groveProxy            = groveProxy_;
        pocketFactory         = pocketFactory_;
        usdsUsdcPocketFactory = usdsUsdcPocketFactory_;
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
        return pocketFactory.createAavePocket(address(groveBasin), address(swapToken));
    }

    function _createMorphoPocket() internal returns (address) {
        return pocketFactory.createMorphoPocket(address(groveBasin), address(swapToken));
    }

    function _createUsdsUsdcPocket() internal returns (address) {
        return usdsUsdcPocketFactory.createUsdsUsdcPocket(
            address(groveBasin),
            address(swapToken),
            address(usds),
            address(psm),
            groveProxy
        );
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
