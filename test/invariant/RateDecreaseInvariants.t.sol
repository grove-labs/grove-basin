// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinInvariantTestBase } from "test/invariant/Invariants.t.sol";

import { LpHandler }            from "test/invariant/handlers/LpHandler.sol";
import { RateDecreaseHandler }  from "test/invariant/handlers/RateDecreaseHandler.sol";
import { RateSetterHandler }    from "test/invariant/handlers/RateSetterHandler.sol";
import { SwapperHandler }       from "test/invariant/handlers/SwapperHandler.sol";

contract GroveBasinInvariants_RateDecrease_NoTransfer is GroveBasinInvariantTestBase {

    RateDecreaseHandler public rateDecreaseHandler;

    function setUp() public override {
        super.setUp();

        lpHandler            = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        rateSetterHandler    = new RateSetterHandler(groveBasin, address(creditTokenRateProvider), 1.25e27);
        rateDecreaseHandler  = new RateDecreaseHandler(groveBasin, address(creditTokenRateProvider), 1.25e27);
        swapperHandler       = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);

        targetContract(address(lpHandler));
        targetContract(address(rateSetterHandler));
        targetContract(address(rateDecreaseHandler));
        targetContract(address(swapperHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
    }

    // NOTE: Share price monotonicity is NOT checked — rate decreases reduce share price.

    function invariant_previewExecuteConsistency() public view {
        _checkInvariant_PreviewExecuteConsistency();
    }

    function invariant_A() public view {
        _checkInvariant_A();
    }

    function invariant_B() public view {
        _checkInvariant_B();
    }

    function invariant_C() public view {
        _checkInvariant_C();
    }

    // NOTE: Invariant D is excluded — rate decreases directly reduce LP value below deposits.

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}
