// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { SSRAuthOracle } from "lib/xchain-ssr-oracle/src/SSRAuthOracle.sol";
import { ISSROracle }    from "lib/xchain-ssr-oracle/src/interfaces/ISSROracle.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";
import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { FeeSetterHandler }     from "test/invariant/handlers/FeeSetterHandler.sol";
import { LpHandler }            from "test/invariant/handlers/LpHandler.sol";
import { RateSetterHandler }    from "test/invariant/handlers/RateSetterHandler.sol";
import { SwapperHandler }       from "test/invariant/handlers/SwapperHandler.sol";
import { TimeBasedRateHandler } from "test/invariant/handlers/TimeBasedRateHandler.sol";
import { TransferHandler }      from "test/invariant/handlers/TransferHandler.sol";
import { OwnerHandler }         from "test/invariant/handlers/OwnerHandler.sol";
import { PocketFactory }         from "test/invariant/handlers/PocketFactory.sol";
import { UsdsUsdcPocketFactory } from "test/invariant/handlers/UsdsUsdcPocketFactory.sol";
import { MockSSRRateProvider }  from "test/mocks/MockSSRRateProvider.sol";

abstract contract GroveBasinInvariantTestBase is GroveBasinTestBase {

    FeeSetterHandler     public feeSetterHandler;
    LpHandler            public lpHandler;
    RateSetterHandler    public rateSetterHandler;
    SwapperHandler       public swapperHandler;
    TransferHandler      public transferHandler;
    TimeBasedRateHandler public timeBasedRateHandler;

    address BURN_ADDRESS = address(0);
    address FEE_CLAIMER  = makeAddr("feeClaimer");

    // Seed deposit tracking for invariant assertions.
    // These are set in setUp and can be overridden by subclasses that redeploy groveBasin.
    uint256 public seedSwapTokenInflow;
    uint256 public seedCollateralTokenInflow;
    uint256 public seedDepositValue;

    function setUp() public virtual override {
        super.setUp();

        // Set up fee claimer for invariant testing
        vm.prank(owner);
        groveBasin.setFeeClaimer(FEE_CLAIMER);

        // Set fee bounds to allow fees to be enabled
        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);  // 0-5% fees

        // Initial LP deposit to provide baseline liquidity for invariant testing.
        _deposit(address(swapToken), BURN_ADDRESS, 1e6);
        _deposit(address(collateralToken), BURN_ADDRESS, 1e18);

        seedSwapTokenInflow       = 1e6;
        seedCollateralTokenInflow = 1e18;
        seedDepositValue          = 2e18;
    }

    /**********************************************************************************************/
    /*** Invariant assertion functions                                                          ***/
    /**********************************************************************************************/

    function _checkInvariant_A() public view {
        uint256 lpShares = groveBasin.shares(BURN_ADDRESS);  // Seed shares

        for (uint256 i = 0; i < 3; i++) {
            lpShares += groveBasin.shares(lpHandler.lps(i));
        }

        // Add fee claimer shares
        lpShares += groveBasin.shares(FEE_CLAIMER);

        assertEq(lpShares, groveBasin.totalShares());
    }

    function _checkInvariant_B() public view {
        assertApproxEqAbs(
            groveBasin.totalAssets(),
            groveBasin.convertToAssetValue(groveBasin.totalShares()),
            4
        );
    }

    function _checkInvariant_C() public view {
        uint256 lpAssetValue = groveBasin.convertToAssetValue(groveBasin.shares(BURN_ADDRESS));  // Seed amount

        for (uint256 i = 0; i < 3; i++) {
            lpAssetValue += groveBasin.convertToAssetValue(groveBasin.shares(lpHandler.lps(i)));
        }

        // Add fee claimer value
        lpAssetValue += groveBasin.convertToAssetValue(groveBasin.shares(FEE_CLAIMER));

        assertApproxEqAbs(lpAssetValue, groveBasin.totalAssets(), 4);
    }

    // This might be failing because of swap rounding errors.
    function _checkInvariant_D() public view {
        // Seed amounts
        uint256 lpDeposits   = seedDepositValue;
        uint256 lpAssetValue = groveBasin.convertToAssetValue(groveBasin.shares(BURN_ADDRESS));

        for (uint256 i = 0; i < 3; i++) {
            address lp = lpHandler.lps(i);

            lpDeposits   += _getLpDepositsValue(lp);
            lpAssetValue += groveBasin.convertToAssetValue(groveBasin.shares(lp));
        }

        // LPs position value can increase from transfers into the GroveBasin and from swapping rounding
        // errors increasing the value of the GroveBasin slightly.
        // Allow a 2e12 tolerance for negative rounding on conversion calculations.
        assertGe(lpAssetValue + 2e12, lpDeposits);

        // Include seed deposit, allow for 2e12 negative tolerance.
        assertGe(groveBasin.totalAssets() + 2e12, lpDeposits);
    }

    function _checkInvariant_E() public view {
        uint256 expectedSwapTokenInflows       = seedSwapTokenInflow;
        uint256 expectedCollateralTokenInflows = seedCollateralTokenInflow;
        uint256 expectedCreditTokenInflows     = 0;

        uint256 expectedSwapTokenOutflows       = 0;
        uint256 expectedCollateralTokenOutflows = 0;
        uint256 expectedCreditTokenOutflows     = 0;

        for(uint256 i; i < 3; i++) {
            address lp      = lpHandler.lps(i);
            address swapper = swapperHandler.swappers(i);

            expectedSwapTokenInflows       += lpHandler.lpDeposits(lp, address(swapToken));
            expectedCollateralTokenInflows += lpHandler.lpDeposits(lp, address(collateralToken));
            expectedCreditTokenInflows     += lpHandler.lpDeposits(lp, address(creditToken));

            expectedSwapTokenInflows       += swapperHandler.swapsIn(swapper, address(swapToken));
            expectedCollateralTokenInflows += swapperHandler.swapsIn(swapper, address(collateralToken));
            expectedCreditTokenInflows     += swapperHandler.swapsIn(swapper, address(creditToken));

            expectedSwapTokenOutflows       += lpHandler.lpWithdrawals(lp, address(swapToken));
            expectedCollateralTokenOutflows += lpHandler.lpWithdrawals(lp, address(collateralToken));
            expectedCreditTokenOutflows     += lpHandler.lpWithdrawals(lp, address(creditToken));

            expectedSwapTokenOutflows       += swapperHandler.swapsOut(swapper, address(swapToken));
            expectedCollateralTokenOutflows += swapperHandler.swapsOut(swapper, address(collateralToken));
            expectedCreditTokenOutflows     += swapperHandler.swapsOut(swapper, address(creditToken));
        }

        if (address(transferHandler) != address(0)) {
            expectedSwapTokenInflows       += transferHandler.transfersIn(address(swapToken));
            expectedCollateralTokenInflows += transferHandler.transfersIn(address(collateralToken));
            expectedCreditTokenInflows     += transferHandler.transfersIn(address(creditToken));
        }

        address pocket_ = groveBasin.pocket();
        uint256 swapBalance = pocket_ == address(groveBasin)
            ? swapToken.balanceOf(address(groveBasin))
            : IGroveBasinPocket(pocket_).availableBalance(address(swapToken));

        assertEq(swapBalance,                                    expectedSwapTokenInflows       - expectedSwapTokenOutflows);
        assertEq(collateralToken.balanceOf(address(groveBasin)), expectedCollateralTokenInflows - expectedCollateralTokenOutflows);
        assertEq(creditToken.balanceOf(address(groveBasin)),     expectedCreditTokenInflows     - expectedCreditTokenOutflows);
    }

    function _checkInvariant_F() public view {
        uint256 totalValueSwappedIn;
        uint256 totalValueSwappedOut;

        for(uint256 i; i < 3; i++) {
            address swapper = swapperHandler.swappers(i);

            uint256 valueSwappedIn  = swapperHandler.valueSwappedIn(swapper);
            uint256 valueSwappedOut = swapperHandler.valueSwappedOut(swapper);

            // TODO: Paramaterize the TimeBasedHandler and make this function take parameters.
            //       At really high rates the rounding errors can be quite large.
            // Fee value extracted from swapper is included in the tolerance.
            assertApproxEqAbs(
                valueSwappedIn,
                valueSwappedOut,
                swapperHandler.swapperSwapCount(swapper) * 3e12
                    + swapperHandler.feeValueExtracted(swapper)
            );
            assertGe(valueSwappedIn, valueSwappedOut);

            totalValueSwappedIn  += valueSwappedIn;
            totalValueSwappedOut += valueSwappedOut;
        }

        // Rounding error of up to 3e12 per swap, always rounding in favour of the GroveBasin.
        // Fee value is also extracted from swappers and needs to be in tolerance.
        assertApproxEqAbs(
            totalValueSwappedIn,
            totalValueSwappedOut,
            swapperHandler.swapCount() * 3e12 + swapperHandler.totalFeeValueExtracted()
        );
        assertGe(totalValueSwappedIn, totalValueSwappedOut);
    }

    function _checkInvariant_G_FeeIncreasesPoolValue() public view {
        // Swaps with fees always increase pool value (asserted per-swap in SwapperHandler).
        // Verify fee claimer shares are non-negative and that total pool value
        // was never decreased by a swap (this is checked per-swap in the handler).
        uint256 feeClaimerShares_ = groveBasin.shares(FEE_CLAIMER);
        uint256 feeClaimerValue   = groveBasin.convertToAssetValue(feeClaimerShares_);

        // Fee claimer value should be consistent with their shares
        if (feeClaimerShares_ > 0) {
            assertGt(
                feeClaimerValue,
                0,
                "Invariant G: Fee claimer shares should have positive value"
            );
        }
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _logHandlerCallCounts() public view {
        console.log("depositCount    ", lpHandler.depositCount());
        console.log("withdrawCount   ", lpHandler.withdrawCount());
        console.log("swapCount       ", swapperHandler.swapCount());
        console.log("zeroBalanceCount", swapperHandler.zeroBalanceCount());
        console.log("setRateCount    ", rateSetterHandler.setRateCount());
        console.log(
            "sum             ",
            lpHandler.depositCount() +
            lpHandler.withdrawCount() +
            swapperHandler.swapCount() +
            swapperHandler.zeroBalanceCount() +
            rateSetterHandler.setRateCount()
        );
    }

    function _getLpTokenValue(address lp) internal view returns (uint256) {
        uint256 collateralTokenValue = collateralToken.balanceOf(lp) * collateralTokenRateProvider.getConversionRate() / 1e27; // 1e9 + 1e18
        uint256 swapTokenValue       = swapToken.balanceOf(lp) * swapTokenRateProvider.getConversionRate() / 1e15; // 1e9 + 1e6
        uint256 creditTokenValue     = creditToken.balanceOf(lp) * creditTokenRateProvider.getConversionRate() / 1e27; // 1e9 + 1e18

        return collateralTokenValue + swapTokenValue + creditTokenValue;
    }

    function _getLpDepositsValue(address lp) internal view returns (uint256) {
        uint256 depositValue =
            lpHandler.lpDeposits(lp, address(collateralToken)) * collateralTokenRateProvider.getConversionRate() / 1e27 + // 1e9 + 1e18
            lpHandler.lpDeposits(lp, address(swapToken))       * swapTokenRateProvider.getConversionRate()       / 1e15 + // 1e9 + 1e6
            lpHandler.lpDeposits(lp, address(creditToken))     * creditTokenRateProvider.getConversionRate()     / 1e27; // 1e9 + 1e18

        uint256 withdrawValue =
            lpHandler.lpWithdrawals(lp, address(collateralToken)) * collateralTokenRateProvider.getConversionRate() / 1e27 + // 1e9 + 1e18
            lpHandler.lpWithdrawals(lp, address(swapToken))       * swapTokenRateProvider.getConversionRate()       / 1e15 + // 1e9 + 1e6
            lpHandler.lpWithdrawals(lp, address(creditToken))     * creditTokenRateProvider.getConversionRate()     / 1e27; // 1e9 + 1e18

        return withdrawValue > depositValue ? 0 : depositValue - withdrawValue;
    }

    function _getLpAPR(address lp, uint256 initialValue, uint256 warpTime)
        internal view returns (uint256)
    {
        uint256 lpValue = groveBasin.convertToAssetValue(groveBasin.shares(lp));
        return (lpValue - initialValue) * 1e18 * 365 days / initialValue / warpTime;
    }

    /**********************************************************************************************/
    /*** After invariant hook functions                                                         ***/
    /**********************************************************************************************/

    function _withdrawAllPositions() public {
        address lp0 = lpHandler.lps(0);
        address lp1 = lpHandler.lps(1);
        address lp2 = lpHandler.lps(2);

        uint256 groveBasinTotalValue = groveBasin.totalAssets();
        uint256 startingSeedValue = groveBasin.convertToAssetValue(groveBasin.shares(BURN_ADDRESS));

        // Store before values for individual LPs
        uint256[3] memory depositsValues = [
            groveBasin.convertToAssetValue(groveBasin.shares(lp0)),
            groveBasin.convertToAssetValue(groveBasin.shares(lp1)),
            groveBasin.convertToAssetValue(groveBasin.shares(lp2))
        ];
        uint256[3] memory withdrawsValues = [
            _getLpTokenValue(lp0),
            _getLpTokenValue(lp1),
            _getLpTokenValue(lp2)
        ];

        // Liquidity is unknown so withdraw all assets for all users to empty GroveBasin.
        _withdraw(address(collateralToken), lp0, type(uint256).max);
        _withdraw(address(swapToken),       lp0, type(uint256).max);
        _withdraw(address(creditToken),     lp0, type(uint256).max);

        _withdraw(address(collateralToken), lp1, type(uint256).max);
        _withdraw(address(swapToken),       lp1, type(uint256).max);
        _withdraw(address(creditToken),     lp1, type(uint256).max);

        _withdraw(address(collateralToken), lp2, type(uint256).max);
        _withdraw(address(swapToken),       lp2, type(uint256).max);
        _withdraw(address(creditToken),     lp2, type(uint256).max);

        // All funds are completely withdrawn.
        assertEq(groveBasin.shares(lp0), 0);
        assertEq(groveBasin.shares(lp1), 0);
        assertEq(groveBasin.shares(lp2), 0);

        uint256 seedValue = groveBasin.convertToAssetValue(groveBasin.shares(BURN_ADDRESS));
        uint256 feeClaimerShares = groveBasin.shares(FEE_CLAIMER);
        uint256 feeClaimerValue  = groveBasin.convertToAssetValue(feeClaimerShares);

        // GroveBasin is empty (besides seed amount and fee claimer shares).
        assertEq(groveBasin.totalShares(), groveBasin.shares(BURN_ADDRESS) + feeClaimerShares);
        // convertToAssetValue rounds down, so totalAssets can exceed the sum by up to 1
        assertApproxEqAbs(
            groveBasin.totalAssets(),
            seedValue + feeClaimerValue,
            1
        );

        // Check individual LP values with rounding tolerance.
        // Fee share dilution can reduce LP values, so add fee claimer value as tolerance.
        assertApproxEqAbs(_getLpTokenValue(lp0), depositsValues[0] + withdrawsValues[0], 2e12 + feeClaimerValue);
        assertApproxEqAbs(_getLpTokenValue(lp1), depositsValues[1] + withdrawsValues[1], 2e12 + feeClaimerValue);
        assertApproxEqAbs(_getLpTokenValue(lp2), depositsValues[2] + withdrawsValues[2], 4e12 + feeClaimerValue);

        // All rounding errors from LPs can accrue to the burn address after withdrawals are made.
        assertApproxEqAbs(seedValue, startingSeedValue, 6e12);

        // Verify total value accounting
        uint256 sumLpValue = _getLpTokenValue(lp0) + _getLpTokenValue(lp1) + _getLpTokenValue(lp2);
        uint256 totalWithdrawals = sumLpValue - (withdrawsValues[0] + withdrawsValues[1] + withdrawsValues[2]);

        assertApproxEqAbs(totalWithdrawals, groveBasinTotalValue - seedValue - feeClaimerValue, 3 + feeClaimerValue);

        uint256 sumStartingValue =
            (depositsValues[0] + depositsValues[1] + depositsValues[2]) +
            (withdrawsValues[0] + withdrawsValues[1] + withdrawsValues[2]);

        assertApproxEqAbs(sumLpValue, sumStartingValue, seedValue - startingSeedValue + 3 + feeClaimerValue);

        // NOTE: Below logic is not realistic, shown to demonstrate precision.
        _withdraw(address(collateralToken), BURN_ADDRESS, type(uint256).max);
        _withdraw(address(swapToken),       BURN_ADDRESS, type(uint256).max);
        _withdraw(address(creditToken),     BURN_ADDRESS, type(uint256).max);

        // Withdraw fee claimer position
        _withdraw(address(collateralToken), FEE_CLAIMER, type(uint256).max);
        _withdraw(address(swapToken),       FEE_CLAIMER, type(uint256).max);
        _withdraw(address(creditToken),     FEE_CLAIMER, type(uint256).max);

        assertApproxEqAbs(
            sumLpValue + _getLpTokenValue(BURN_ADDRESS) + _getLpTokenValue(FEE_CLAIMER),
            sumStartingValue + startingSeedValue + feeClaimerValue,
            20 + 6e12  // extra rounding from fee claimer withdrawal (up to 2e12 per token type)
        );

        // All funds can always be withdrawn completely (rounding in withdrawal against users).
        assertEq(groveBasin.totalShares(), 0);
        assertLe(groveBasin.totalAssets(), 20 + 6e12);
    }

    function _warpAndAssertConsistentValueAccrual() public {
        address lp0 = lpHandler.lps(0);
        address lp1 = lpHandler.lps(1);
        address lp2 = lpHandler.lps(2);

        // Ensure that all users have a minimum balance of shares to improve precision
        _deposit(address(collateralToken), lp0, 100_000e18);
        _deposit(address(collateralToken), lp1, 100_000e18);
        _deposit(address(collateralToken), lp2, 100_000e18);

        uint256 lp0Value = groveBasin.convertToAssetValue(groveBasin.shares(lp0));
        uint256 lp1Value = groveBasin.convertToAssetValue(groveBasin.shares(lp1));
        uint256 lp2Value = groveBasin.convertToAssetValue(groveBasin.shares(lp2));

        skip(1 days);

        uint256 lp0Apr1 = _getLpAPR(lp0, lp0Value, 1 days);

        uint256 tolerance = 0.000_000_000_001e18;

        // Check that the other LPs have the same APR.
        assertApproxEqRel(_getLpAPR(lp1, lp1Value, 1 days), lp0Apr1, tolerance);
        assertApproxEqRel(_getLpAPR(lp2, lp2Value, 1 days), lp0Apr1, tolerance);

        skip(364 days);

        uint256 lp0Apr2 = _getLpAPR(lp0, lp0Value, 365 days);

        // Since value accrues compounding per second, the APR representation will increase
        assertGe(lp0Apr2, lp0Apr1);

        // Check that the APY remains the same after a year, comparing to LP0 to also ensure
        // consistency across LPs.
        assertApproxEqRel(_getLpAPR(lp1, lp1Value, 365 days), lp0Apr2, tolerance);
        assertApproxEqRel(_getLpAPR(lp2, lp2Value, 365 days), lp0Apr2, tolerance);
    }

}

contract GroveBasinInvariants_ConstantRate_NoTransfer is GroveBasinInvariantTestBase {

    function setUp() public override {
        super.setUp();

        feeSetterHandler = new FeeSetterHandler(groveBasin, 500, owner);  // 0-5% fees
        lpHandler        = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        swapperHandler   = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);

        targetContract(address(feeSetterHandler));
        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    function invariant_D() public view {
        _checkInvariant_D();
    }

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function invariant_G() public view {
        _checkInvariant_G_FeeIncreasesPoolValue();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract GroveBasinInvariants_ConstantRate_WithTransfers is GroveBasinInvariantTestBase {

    function setUp() public override {
        super.setUp();

        feeSetterHandler = new FeeSetterHandler(groveBasin, 500, owner);  // 0-5% fees
        lpHandler        = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        swapperHandler   = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        transferHandler  = new TransferHandler(groveBasin, swapToken, collateralToken, creditToken);

        targetContract(address(feeSetterHandler));
        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
        targetContract(address(transferHandler));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function invariant_G() public view {
        _checkInvariant_G_FeeIncreasesPoolValue();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract GroveBasinInvariants_RateSetting_NoTransfer is GroveBasinInvariantTestBase {

    function setUp() public override {
        super.setUp();

        feeSetterHandler  = new FeeSetterHandler(groveBasin, 500, owner);  // 0-5% fees
        lpHandler         = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        rateSetterHandler = new RateSetterHandler(groveBasin, address(creditTokenRateProvider), 1.25e27);
        swapperHandler    = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);

        targetContract(address(feeSetterHandler));
        targetContract(address(lpHandler));
        targetContract(address(rateSetterHandler));
        targetContract(address(swapperHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

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

contract GroveBasinInvariants_RateSetting_WithTransfers is GroveBasinInvariantTestBase {

    function setUp() public override {
        super.setUp();

        feeSetterHandler  = new FeeSetterHandler(groveBasin, 500, owner);  // 0-5% fees
        lpHandler         = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        rateSetterHandler = new RateSetterHandler(groveBasin, address(creditTokenRateProvider), 1.25e27);
        swapperHandler    = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        transferHandler   = new TransferHandler(groveBasin, swapToken, collateralToken, creditToken);

        targetContract(address(feeSetterHandler));
        targetContract(address(lpHandler));
        targetContract(address(rateSetterHandler));
        targetContract(address(swapperHandler));
        targetContract(address(transferHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function invariant_G() public view {
        _checkInvariant_G_FeeIncreasesPoolValue();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract GroveBasinInvariants_TimeBasedRateSetting_NoTransfer is GroveBasinInvariantTestBase {

    function setUp() public override {
        super.setUp();

        SSRAuthOracle ssrOracle = new SSRAuthOracle();

        // Workaround to initialize GroveBasin with an oracle that does not return zero
        // This gets overwritten by the handler
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));
        ssrOracle.setSUSDSData(ISSROracle.SUSDSData({
            ssr: uint96(1e27),
            chi: uint120(1e27),
            rho: uint40(block.timestamp)
        }));
        ssrOracle.revokeRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));

        MockSSRRateProvider ssrRateProvider = new MockSSRRateProvider(ssrOracle);

        // Redeploy GroveBasin with new rate provider
        groveBasin = new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(ssrRateProvider));

        // Set a large staleness threshold so warps don't cause stale-rate reverts
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);
        groveBasin.setStalenessThresholdBounds(1, type(uint128).max);
        groveBasin.setStalenessThreshold(type(uint128).max);
        // Set up fee claimer and bounds for this test suite
        groveBasin.setFeeClaimer(FEE_CLAIMER);
        groveBasin.setFeeBounds(0, 500);  // 0-5% fees
        vm.stopPrank();

        // NOTE: Don't need to set GroveBasin as pocket for this suite as its default on deploy

        // Initial LP deposit for baseline liquidity
        _deposit(address(swapToken), BURN_ADDRESS, 1e6);
        _deposit(address(collateralToken), BURN_ADDRESS, 1e18);

        seedSwapTokenInflow       = 1e6;
        seedCollateralTokenInflow = 1e18;
        seedDepositValue          = 2e18;

        feeSetterHandler     = new FeeSetterHandler(groveBasin, 500, owner);  // 0-5% fees
        lpHandler            = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        swapperHandler       = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        timeBasedRateHandler = new TimeBasedRateHandler(groveBasin, ssrOracle);

        // Handler acts in the same way as a receiver on L2, so add as a data provider to the
        // oracle.
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(timeBasedRateHandler));

        creditTokenRateProvider = IRateProviderLike(address(ssrRateProvider));

        // Manually set initial values for the oracle through the handler to start
        timeBasedRateHandler.setRateData(1e27);

        targetContract(address(feeSetterHandler));
        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
        targetContract(address(timeBasedRateHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function invariant_G() public view {
        _checkInvariant_G_FeeIncreasesPoolValue();
    }

    function afterInvariant() public {
        uint256 snapshot = vm.snapshot();

        _warpAndAssertConsistentValueAccrual();

        vm.revertTo(snapshot);

        _withdrawAllPositions();
    }

}

contract GroveBasinInvariants_TimeBasedRateSetting_WithTransfers is GroveBasinInvariantTestBase {

    function setUp() public virtual override {
        super.setUp();

        SSRAuthOracle ssrOracle = new SSRAuthOracle();

        // Workaround to initialize GroveBasin with an oracle that does not return zero
        // This gets overwritten by the handler
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));
        ssrOracle.setSUSDSData(ISSROracle.SUSDSData({
            ssr: uint96(1e27),
            chi: uint120(1e27),
            rho: uint40(block.timestamp)
        }));
        ssrOracle.revokeRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));

        MockSSRRateProvider ssrRateProvider = new MockSSRRateProvider(ssrOracle);

        // Redeploy GroveBasin with new rate provider
        groveBasin = new GroveBasin(owner, lp, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(ssrRateProvider));

        // Set a large staleness threshold so warps don't cause stale-rate reverts
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);
        groveBasin.setStalenessThresholdBounds(1, type(uint128).max);
        groveBasin.setStalenessThreshold(type(uint128).max);
        // Set up fee claimer and bounds for this test suite
        groveBasin.setFeeClaimer(FEE_CLAIMER);
        groveBasin.setFeeBounds(0, 500);  // 0-5% fees
        vm.stopPrank();

        // NOTE: This base test suite tests the case of the GroveBasin being the pocket for the whole time,
        //       where the other suites are testing with an external `pocket`.

        // Initial LP deposit for baseline liquidity
        _deposit(address(swapToken), BURN_ADDRESS, 1e6);
        _deposit(address(collateralToken), BURN_ADDRESS, 1e18);

        seedSwapTokenInflow       = 1e6;
        seedCollateralTokenInflow = 1e18;
        seedDepositValue          = 2e18;

        feeSetterHandler     = new FeeSetterHandler(groveBasin, 500, owner);  // 0-5% fees
        lpHandler            = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3, owner);
        swapperHandler       = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        timeBasedRateHandler = new TimeBasedRateHandler(groveBasin, ssrOracle);
        transferHandler      = new TransferHandler(groveBasin, swapToken, collateralToken, creditToken);

        // Handler acts in the same way as a receiver on L2, so add as a data provider to the
        // oracle.
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(timeBasedRateHandler));

        creditTokenRateProvider = IRateProviderLike(address(ssrRateProvider));

        // Manually set initial values for the oracle through the handler to start
        timeBasedRateHandler.setRateData(1e27);

        targetContract(address(feeSetterHandler));
        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
        targetContract(address(timeBasedRateHandler));
        targetContract(address(transferHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function invariant_G() public view {
        _checkInvariant_G_FeeIncreasesPoolValue();
    }

    function afterInvariant() public {
        uint256 snapshot = vm.snapshot();

        _warpAndAssertConsistentValueAccrual();

        vm.revertTo(snapshot);

        _withdrawAllPositions();
    }

}

// NOTE: Adding pocket setting to only one invariant test suite, as the probability distribution of `setPocket` being
//       called is too high to be considered reflective of reality (setting pocket as often as deposits for example).
//       This inherited test suite is the most complex and realistic, so setting the pocket in this
//       one is sufficient to ensure the expected behavior and accounting.
contract GroveBasinInvariants_TimeBasedRateSetting_WithTransfers_WithPocketSetting is GroveBasinInvariants_TimeBasedRateSetting_WithTransfers {

    OwnerHandler ownerHandler;

    function setUp() public override {
        super.setUp();

        // NOTE: The GroveBasin is the pocket to start, so the test suite will start with it as the pocket
        //       and transfer it to other addresses.

        PocketFactory pocketFactory                 = new PocketFactory();
        UsdsUsdcPocketFactory usdsUsdcPocketFactory = new UsdsUsdcPocketFactory();

        ownerHandler = new OwnerHandler(groveBasin, swapToken, usds, psm, groveProxy, pocketFactory, usdsUsdcPocketFactory);
        targetContract(address(ownerHandler));

        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(managerAdminRole, address(ownerHandler));
    }

}