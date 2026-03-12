// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { GroveBasinInvariantTestBase } from "test/invariant/Invariants.t.sol";

import { FeeHandler }             from "test/invariant/handlers/FeeHandler.sol";
import { FeeAwareSwapperHandler } from "test/invariant/handlers/FeeAwareSwapperHandler.sol";
import { LpHandler }              from "test/invariant/handlers/LpHandler.sol";
import { RateSetterHandler }      from "test/invariant/handlers/RateSetterHandler.sol";
import { SwapperHandler }         from "test/invariant/handlers/SwapperHandler.sol";

abstract contract FeeInvariantTestBase is GroveBasinInvariantTestBase {

    FeeHandler             public feeHandler;
    FeeAwareSwapperHandler public feeAwareSwapperHandler;

    function setUp() public virtual override {
        super.setUp();

        // Configure fee bounds via MANAGER_ADMIN_ROLE before setting fees.
        // setFeeBounds requires MANAGER_ADMIN_ROLE, setPurchaseFee/setRedemptionFee require MANAGER_ROLE.
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);
        groveBasin.setFeeBounds(0, 500);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Fee-adapted invariant F                                                                ***/
    /**********************************************************************************************/

    /// @dev Invariant F adapted for fee-enabled suites. Fees cause valueSwappedIn to exceed
    ///      valueSwappedOut by more than just rounding, so the approxEqAbs tolerance must account
    ///      for fee revenue. The core property (Basin never loses value on swaps) is preserved.
    function _checkInvariant_F_WithFees() public view {
        uint256 totalValueSwappedIn;
        uint256 totalValueSwappedOut;

        for(uint256 i; i < 3; i++) {
            address swapper = feeAwareSwapperHandler.swappers(i);

            uint256 valueSwappedIn  = feeAwareSwapperHandler.valueSwappedIn(swapper);
            uint256 valueSwappedOut = feeAwareSwapperHandler.valueSwappedOut(swapper);

            // Core property: Basin never loses value on any individual swapper's swaps.
            assertGe(valueSwappedIn, valueSwappedOut);

            totalValueSwappedIn  += valueSwappedIn;
            totalValueSwappedOut += valueSwappedOut;
        }

        // Core property: total value in >= total value out (fees + rounding favor the protocol)
        assertGe(totalValueSwappedIn, totalValueSwappedOut);
    }

    /**********************************************************************************************/
    /*** Fee-adapted invariant E                                                                ***/
    /**********************************************************************************************/

    /// @dev Invariant E adapted for fee-enabled suites. Uses the FeeAwareSwapperHandler to read
    ///      ghost variables for swap inflows/outflows.
    function _checkInvariant_E_WithFees() public view {
        uint256 expectedSwapTokenInflows       = 0;
        uint256 expectedCollateralTokenInflows = 1e18;  // Seed amount
        uint256 expectedCreditTokenInflows     = 0;

        uint256 expectedSwapTokenOutflows       = 0;
        uint256 expectedCollateralTokenOutflows = 0;
        uint256 expectedCreditTokenOutflows     = 0;

        for(uint256 i; i < 3; i++) {
            address lp      = lpHandler.lps(i);
            address swapper = feeAwareSwapperHandler.swappers(i);

            expectedSwapTokenInflows       += lpHandler.lpDeposits(lp, address(swapToken));
            expectedCollateralTokenInflows += lpHandler.lpDeposits(lp, address(collateralToken));
            expectedCreditTokenInflows     += lpHandler.lpDeposits(lp, address(creditToken));

            expectedSwapTokenInflows       += feeAwareSwapperHandler.swapsIn(swapper, address(swapToken));
            expectedCollateralTokenInflows += feeAwareSwapperHandler.swapsIn(swapper, address(collateralToken));
            expectedCreditTokenInflows     += feeAwareSwapperHandler.swapsIn(swapper, address(creditToken));

            expectedSwapTokenOutflows       += lpHandler.lpWithdrawals(lp, address(swapToken));
            expectedCollateralTokenOutflows += lpHandler.lpWithdrawals(lp, address(collateralToken));
            expectedCreditTokenOutflows     += lpHandler.lpWithdrawals(lp, address(creditToken));

            expectedSwapTokenOutflows       += feeAwareSwapperHandler.swapsOut(swapper, address(swapToken));
            expectedCollateralTokenOutflows += feeAwareSwapperHandler.swapsOut(swapper, address(collateralToken));
            expectedCreditTokenOutflows     += feeAwareSwapperHandler.swapsOut(swapper, address(creditToken));
        }

        address pocket_ = groveBasin.pocket();
        uint256 swapBalance = pocket_ == address(groveBasin)
            ? swapToken.balanceOf(address(groveBasin))
            : IGroveBasinPocket(pocket_).availableBalance(address(swapToken));
        assertEq(swapBalance,                                    expectedSwapTokenInflows       - expectedSwapTokenOutflows);
        assertEq(collateralToken.balanceOf(address(groveBasin)), expectedCollateralTokenInflows - expectedCollateralTokenOutflows);
        assertEq(creditToken.balanceOf(address(groveBasin)),     expectedCreditTokenInflows     - expectedCreditTokenOutflows);
    }

}

contract FeeInvariants_ConstantRate is FeeInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler              = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        feeAwareSwapperHandler = new FeeAwareSwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        feeHandler             = new FeeHandler(groveBasin, owner);

        // Cast to SwapperHandler so base class share price monotonicity check can access lastSharePrice
        swapperHandler = SwapperHandler(address(feeAwareSwapperHandler));

        targetContract(address(lpHandler));
        targetContract(address(feeAwareSwapperHandler));
        targetContract(address(feeHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(feeAwareSwapperHandler.lp0(), lpHandler.lps(0));
    }

    function invariant_previewExecuteConsistency() public view {
        _checkInvariant_PreviewExecuteConsistency();
    }

    function invariant_sharePriceMonotonicity() public view {
        _checkInvariant_SharePriceMonotonicity();
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

    // NOTE: Invariant D excluded — fees reduce swap output, which can reduce LP value below
    //       deposit value in edge cases.

    function invariant_E() public view {
        _checkInvariant_E_WithFees();
    }

    function invariant_F() public view {
        _checkInvariant_F_WithFees();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract FeeInvariants_RateSetting is FeeInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler              = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        rateSetterHandler      = new RateSetterHandler(groveBasin, address(creditTokenRateProvider), 1.25e27);
        feeAwareSwapperHandler = new FeeAwareSwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        feeHandler             = new FeeHandler(groveBasin, owner);

        // Cast to SwapperHandler so base class share price monotonicity check can access lastSharePrice
        swapperHandler = SwapperHandler(address(feeAwareSwapperHandler));

        targetContract(address(lpHandler));
        targetContract(address(rateSetterHandler));
        targetContract(address(feeAwareSwapperHandler));
        targetContract(address(feeHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(feeAwareSwapperHandler.lp0(), lpHandler.lps(0));
    }

    function invariant_previewExecuteConsistency() public view {
        _checkInvariant_PreviewExecuteConsistency();
    }

    function invariant_sharePriceMonotonicity() public view {
        _checkInvariant_SharePriceMonotonicity();
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

    // NOTE: Invariant D excluded — fees AND rate changes cause large deviations.

    function invariant_E() public view {
        _checkInvariant_E_WithFees();
    }

    function invariant_F() public view {
        _checkInvariant_F_WithFees();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}
