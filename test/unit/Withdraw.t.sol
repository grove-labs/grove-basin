// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockPocket }       from "test/mocks/MockPocket.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

contract GroveBasinWithdrawTests is GroveBasinTestBase {

    address user1     = makeAddr("user1");
    address user2     = makeAddr("user2");
    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function test_withdraw_zeroAmount() public {
        _deposit(address(swapToken), user1, 100e6);

        vm.expectRevert(IGroveBasin.ZeroAmount.selector);
        groveBasin.withdraw(address(swapToken), receiver1, 0);
    }

    function test_withdraw_notSwapTokenOrCollateralToken() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.withdraw(makeAddr("new-asset"), receiver1, 100e6);
    }

    function test_withdraw_pocketInsufficientApprovalBoundary() public {
        MockPocket mockPocket = new MockPocket(address(groveBasin), address(swapToken), address(usds), address(psm));

        vm.prank(owner);
        groveBasin.setPocket(address(mockPocket));

        // Override the max approval with a limited one
        vm.prank(address(mockPocket));
        swapToken.approve(address(groveBasin), 100e18);

        _deposit(address(swapToken), user1, 100e18 + 1);

        vm.prank(user1);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.withdraw(address(swapToken), receiver1, 100e18 + 1);
    }

    function test_withdraw_onlyCollateralTokenInGroveBasin() public {
        _deposit(address(collateralToken), user1, 100e18);

        assertEq(collateralToken.balanceOf(user1),               0);
        assertEq(collateralToken.balanceOf(receiver1),           0);
        assertEq(collateralToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(collateralToken), receiver1, 100e18);

        assertEq(amount, 100e18);

        assertEq(collateralToken.balanceOf(user1),               0);
        assertEq(collateralToken.balanceOf(receiver1),           100e18);
        assertEq(collateralToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlySwapTokenInGroveBasin() public {
        _deposit(address(swapToken), user1, 100e6);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 0);
        assertEq(_pocketSwapBalance(),           100e6);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver1, 100e6);

        assertEq(amount, 100e6);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 100e6);
        assertEq(_pocketSwapBalance(),           0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlySwapTokenInGroveBasin_pocketIsGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));
        pocket = address(groveBasin);

        _deposit(address(swapToken), user1, 100e6);

        assertEq(swapToken.balanceOf(user1),               0);
        assertEq(swapToken.balanceOf(receiver1),           0);
        assertEq(swapToken.balanceOf(address(groveBasin)), 100e6);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver1, 100e6);

        assertEq(amount, 100e6);

        assertEq(swapToken.balanceOf(user1),               0);
        assertEq(swapToken.balanceOf(receiver1),           100e6);
        assertEq(swapToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlyCreditTokenInGroveBasin() public {
        _deposit(address(creditToken), user1, 80e18);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(receiver1),           0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 80e18);

        assertEq(groveBasin.totalShares(), 100e18);
        assertEq(groveBasin.shares(user1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(creditToken), receiver1, 80e18);

        assertEq(amount, 80e18);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(receiver1),           80e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_withdraw_swapTokenThenCreditToken() public {
        _deposit(address(swapToken),   user1, 100e6);
        _deposit(address(creditToken), user1, 100e18);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 0);
        assertEq(_pocketSwapBalance(),           100e6);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(receiver1),     0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(), 225e18);
        assertEq(groveBasin.shares(user1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver1, 100e6);

        assertEq(amount, 100e6);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 100e6);
        assertEq(_pocketSwapBalance(),           0);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(receiver1),           0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(), 125e18);
        assertEq(groveBasin.shares(user1), 125e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        amount = groveBasin.withdraw(address(creditToken), receiver1, 100e18);

        assertEq(amount, 100e18);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 100e6);
        assertEq(_pocketSwapBalance(),           0);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(receiver1),           100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_withdraw_amountHigherThanBalanceOfAsset() public {
        _deposit(address(swapToken),   user1, 100e6);
        _deposit(address(creditToken), user1, 100e18);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 0);
        assertEq(_pocketSwapBalance(),           100e6);

        assertEq(groveBasin.totalShares(), 225e18);
        assertEq(groveBasin.shares(user1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver1, 125e6);

        assertEq(amount, 100e6);

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 100e6);
        assertEq(_pocketSwapBalance(),           0);

        assertEq(groveBasin.totalShares(), 125e18);  // Only burns $100 of shares
        assertEq(groveBasin.shares(user1), 125e18);
    }

    function test_withdraw_amountHigherThanUserShares() public {
        _deposit(address(swapToken),   user1, 100e6);
        _deposit(address(creditToken), user1, 100e18);
        _deposit(address(swapToken),   user2, 200e6);

        assertEq(swapToken.balanceOf(user2),     0);
        assertEq(swapToken.balanceOf(receiver2), 0);
        assertEq(_pocketSwapBalance(),           300e6);

        assertEq(groveBasin.totalShares(), 425e18);
        assertEq(groveBasin.shares(user2), 200e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        vm.prank(user2);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver2, 225e6);

        assertEq(amount, 200e6);

        assertEq(swapToken.balanceOf(user2),     0);
        assertEq(swapToken.balanceOf(receiver2), 200e6);  // Gets highest amount possible
        assertEq(_pocketSwapBalance(),           100e6);

        assertEq(groveBasin.totalShares(), 225e18);
        assertEq(groveBasin.shares(user2), 0);  // Burns the users full amount of shares
    }

    // Adding this test to demonstrate that numbers are exact and correspond to assets deposits/withdrawals when withdrawals
    // aren't greater than the user's share balance. The next test doesn't constrain this, but there are rounding errors of
    // up to 1e12 for USDC because of the difference in asset precision. Up to 1e12 shares can be burned for 0 USDC in some
    // cases, but this is an intentional rounding error against the user.
    function testFuzz_withdraw_multiUser_noFullShareBurns(
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        public
    {
        // Zero amounts revert
        depositAmount1 = _bound(depositAmount1, 1, SWAP_TOKEN_MAX);
        depositAmount2 = _bound(depositAmount2, 1, SWAP_TOKEN_MAX);
        depositAmount3 = _bound(depositAmount3, 1, CREDIT_TOKEN_MAX);

        // Zero amounts revert
        withdrawAmount1 = _bound(withdrawAmount1, 1, SWAP_TOKEN_MAX);
        withdrawAmount2 = _bound(withdrawAmount2, 1, depositAmount2);  // User can't burn up to 1e12 shares for 0 USDC in this case
        withdrawAmount3 = _bound(withdrawAmount3, 1, CREDIT_TOKEN_MAX);

        // Run with zero share tolerance because the rounding error shouldn't be introduced with the above constraints.
        _runWithdrawFuzzTests(
            0,
            depositAmount1,
            depositAmount2,
            depositAmount3,
            withdrawAmount1,
            withdrawAmount2,
            withdrawAmount3
        );
    }

    function testFuzz_withdraw_multiUser_fullShareBurns(
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        public
    {
        // Zero amounts revert
        depositAmount1 = _bound(depositAmount1, 1, SWAP_TOKEN_MAX);
        depositAmount2 = _bound(depositAmount2, 1, SWAP_TOKEN_MAX);
        depositAmount3 = _bound(depositAmount3, 1, CREDIT_TOKEN_MAX);

        // Zero amounts revert
        withdrawAmount1 = _bound(withdrawAmount1, 1, SWAP_TOKEN_MAX);
        withdrawAmount2 = _bound(withdrawAmount2, 1, SWAP_TOKEN_MAX);
        withdrawAmount3 = _bound(withdrawAmount3, 1, CREDIT_TOKEN_MAX);

        // Run with 1e12 share tolerance because the rounding error will be introduced with the above constraints.
        _runWithdrawFuzzTests(
            1e12,
            depositAmount1,
            depositAmount2,
            depositAmount3,
            withdrawAmount1,
            withdrawAmount2,
            withdrawAmount3
        );
    }

    struct WithdrawFuzzTestVars {
        uint256 totalSwapToken;
        uint256 totalValue;
        uint256 expectedWithdrawnAmount1;
        uint256 expectedWithdrawnAmount2;
        uint256 expectedWithdrawnAmount3;
    }

    // NOTE: For `assertApproxEqAbs` assertions, a difference calculation is used here instead of comparing
    // the two values because this approach inherently asserts that the shares remaining are lower than the
    // theoretical value, proving the GroveBasin rounds against the user.
    function _runWithdrawFuzzTests(
        uint256 swapTokenShareTolerance,
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        internal
    {
        _deposit(address(swapToken),   user1, depositAmount1);
        _deposit(address(swapToken),   user2, depositAmount2);
        _deposit(address(creditToken), user2, depositAmount3);

        WithdrawFuzzTestVars memory vars;

        vars.totalSwapToken  = depositAmount1 + depositAmount2;
        vars.totalValue = vars.totalSwapToken * 1e12 + depositAmount3 * 125/100;

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), 0);
        assertEq(_pocketSwapBalance(),           vars.totalSwapToken);

        assertEq(groveBasin.shares(user1), depositAmount1 * 1e12);
        assertEq(groveBasin.totalShares(), vars.totalValue);

        vars.expectedWithdrawnAmount1 = _getExpectedWithdrawnAmount(swapToken, user1, withdrawAmount1);

        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(swapToken), receiver1, withdrawAmount1);

        assertEq(amount, vars.expectedWithdrawnAmount1);

        _checkGroveBasinInvariant();

        assertEq(
            swapToken.balanceOf(receiver1) * 1e12 + groveBasin.totalAssets(),
            vars.totalValue
        );

        // NOTE: User 1 doesn't need a tolerance because their shares are 1e6 precision because they only
        //       deposited USDC. User 2 has a tolerance because they deposited creditToken which has 1e18 precision
        //       so there is a chance that the rounding will be off by up to 1e12.
        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), vars.expectedWithdrawnAmount1);
        assertEq(swapToken.balanceOf(user2),     0);
        assertEq(swapToken.balanceOf(receiver2), 0);
        assertEq(_pocketSwapBalance(),           vars.totalSwapToken - vars.expectedWithdrawnAmount1);

        assertEq(groveBasin.shares(user1), (depositAmount1 - vars.expectedWithdrawnAmount1) * 1e12);
        assertEq(groveBasin.shares(user2), depositAmount2 * 1e12 + depositAmount3 * 125/100);  // Includes creditToken deposit
        assertEq(groveBasin.totalShares(), vars.totalValue - vars.expectedWithdrawnAmount1 * 1e12);

        vars.expectedWithdrawnAmount2 = _getExpectedWithdrawnAmount(swapToken, user2, withdrawAmount2);

        vm.prank(user2);
        amount = groveBasin.withdraw(address(swapToken), receiver2, withdrawAmount2);

        assertEq(amount, vars.expectedWithdrawnAmount2);

        _checkGroveBasinInvariant();

        assertEq(
            (swapToken.balanceOf(receiver1) + swapToken.balanceOf(receiver2)) * 1e12 + groveBasin.totalAssets(),
            vars.totalValue
        );

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), vars.expectedWithdrawnAmount1);
        assertEq(swapToken.balanceOf(user2),     0);
        assertEq(swapToken.balanceOf(receiver2), vars.expectedWithdrawnAmount2);
        assertEq(_pocketSwapBalance(),           vars.totalSwapToken - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2));

        assertEq(creditToken.balanceOf(user2),               0);
        assertEq(creditToken.balanceOf(receiver2),           0);
        assertEq(creditToken.balanceOf(address(groveBasin)), depositAmount3);

        assertEq(groveBasin.shares(user1), (depositAmount1 - vars.expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            ((depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (vars.expectedWithdrawnAmount2 * 1e12)) - groveBasin.shares(user2),
            0,
            swapTokenShareTolerance
        );

        assertApproxEqAbs(
            (vars.totalValue - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2) * 1e12) - groveBasin.totalShares(),
            0,
            swapTokenShareTolerance
        );

        vars.expectedWithdrawnAmount3 = _getExpectedWithdrawnAmount(creditToken, user2, withdrawAmount3);

        vm.prank(user2);
        amount = groveBasin.withdraw(address(creditToken), receiver2, withdrawAmount3);

        assertApproxEqAbs(amount, vars.expectedWithdrawnAmount3, 1);

        _checkGroveBasinInvariant();

        assertApproxEqAbs(
            (swapToken.balanceOf(receiver1) + swapToken.balanceOf(receiver2)) * 1e12
                + (creditToken.balanceOf(receiver2) * creditTokenRateProvider.getConversionRate() / 1e27)
                + groveBasin.totalAssets(),
            vars.totalValue,
            1
        );

        assertEq(swapToken.balanceOf(user1),     0);
        assertEq(swapToken.balanceOf(receiver1), vars.expectedWithdrawnAmount1);
        assertEq(swapToken.balanceOf(user2),     0);
        assertEq(swapToken.balanceOf(receiver2), vars.expectedWithdrawnAmount2);
        assertEq(_pocketSwapBalance(),           vars.totalSwapToken - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2));

        assertApproxEqAbs(creditToken.balanceOf(user2),               0,                                              0);
        assertApproxEqAbs(creditToken.balanceOf(receiver2),           vars.expectedWithdrawnAmount3,                  1);
        assertApproxEqAbs(creditToken.balanceOf(address(groveBasin)), depositAmount3 - vars.expectedWithdrawnAmount3, 1);

        assertEq(groveBasin.shares(user1), (depositAmount1 - vars.expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            ((depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (vars.expectedWithdrawnAmount2 * 1e12) - (vars.expectedWithdrawnAmount3 * 125/100)) - groveBasin.shares(user2),
            0,
            swapTokenShareTolerance + 1  // 1 is added to the tolerance because of rounding error in creditToken calculations
        );

        assertApproxEqAbs(
            vars.totalValue - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2) * 1e12 - (vars.expectedWithdrawnAmount3 * 125/100) - groveBasin.totalShares(),
            0,
            swapTokenShareTolerance + 1  // 1 is added to the tolerance because of rounding error in creditToken calculations
        );
    }

    function test_withdraw_changeConversionRate() public {
        _deposit(address(swapToken),   user1, 100e6);
        _deposit(address(creditToken), user2, 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 creditToken value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(groveBasin.convertToShares(1e18), 0.9e18);

        assertEq(swapToken.balanceOf(user1),  0);
        assertEq(_pocketSwapBalance(), 100e6);

        assertEq(groveBasin.totalShares(), 225e18);
        assertEq(groveBasin.shares(user1), 100e18);
        assertEq(groveBasin.shares(user2), 125e18);

        // NOTE: Users shares have more value than the balance of USDC now
        vm.prank(user1);
        uint256 amount = groveBasin.withdraw(address(swapToken), user1, type(uint256).max);

        assertEq(amount, 100e6);

        assertEq(swapToken.balanceOf(user1),  100e6);
        assertEq(_pocketSwapBalance(), 0);

        assertEq(creditToken.balanceOf(user1),        0);
        assertEq(creditToken.balanceOf(user2),        0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(), 135e18);
        assertEq(groveBasin.shares(user1), 10e18);  // Burn 90 shares to get 100 USDC
        assertEq(groveBasin.shares(user2), 125e18);

        vm.prank(user1);
        amount = groveBasin.withdraw(address(creditToken), user1, type(uint256).max);

        uint256 user1CreditToken = uint256(10e18) * 1e18 / 0.9e18 * 1e27 / 1.5e27;

        assertEq(amount,     user1CreditToken);
        assertEq(user1CreditToken, 7.407407407407407407e18);

        assertEq(creditToken.balanceOf(user1),               user1CreditToken);
        assertEq(creditToken.balanceOf(user2),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18 - user1CreditToken);

        assertEq(groveBasin.totalShares(), 125e18);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 125e18);

        vm.prank(user2);
        amount = groveBasin.withdraw(address(creditToken), user2, type(uint256).max);

        assertEq(amount, 100e18 - user1CreditToken - 1);  // Remaining funds in GroveBasin (rounding)

        assertEq(creditToken.balanceOf(user1),               user1CreditToken);
        assertEq(creditToken.balanceOf(user2),               100e18 - user1CreditToken - 1);  // Rounding
        assertEq(creditToken.balanceOf(address(groveBasin)), 1);                               // Rounding

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        uint256 user1ResultingValue = swapToken.balanceOf(user1) * 1e12 + creditToken.balanceOf(user1) * 150/100;
        uint256 user2ResultingValue = creditToken.balanceOf(user2) * 150/100;  // Use 1.5 conversion rate

        assertEq(user1ResultingValue, 111.111111111111111110e18);
        assertEq(user2ResultingValue, 138.888888888888888888e18);

        assertEq(user1ResultingValue + user2ResultingValue, 249.999999999999999998e18);

        // Value gains are the same for both users
        assertEq((user1ResultingValue - 100e18) * 1e18 / 100e18, 0.111111111111111111e18);
        assertEq((user2ResultingValue - 125e18) * 1e18 / 125e18, 0.111111111111111111e18);
    }

    function testFuzz_withdraw_changeConversionRate(
        uint256 swapTokenAmount,
        uint256 creditTokenAmount,
        uint256 conversionRate
    )
        public
    {
        // Use higher lower bounds to get returns at the end to be more accurate
        // Always increase exchange rate so accrual of value can be checked.
        // Since rounding is against user if it stays the same the value can decrease and
        // the check will underflow
        swapTokenAmount   = _bound(swapTokenAmount,   1e6,     SWAP_TOKEN_MAX);
        creditTokenAmount = _bound(creditTokenAmount, 1e18,    CREDIT_TOKEN_MAX);
        conversionRate    = _bound(conversionRate,    1.26e27, 1000e27);

        _deposit(address(swapToken), user1, swapTokenAmount);
        _deposit(address(creditToken), user2, creditTokenAmount);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 user1Shares = swapTokenAmount * 1e12;
        uint256 user2Shares = creditTokenAmount * 125/100;
        uint256 totalValue  = swapTokenAmount * 1e12 + creditTokenAmount * conversionRate / 1e27;

        assertEq(groveBasin.totalAssets(), totalValue);

        assertEq(groveBasin.totalShares(), user1Shares + user2Shares);
        assertEq(groveBasin.shares(user1), user1Shares);
        assertEq(groveBasin.shares(user2), user2Shares);

        assertEq(swapToken.balanceOf(user1),  0);
        assertEq(_pocketSwapBalance(), swapTokenAmount);

        {
            // NOTE: Users shares have more value than the balance of USDC now
            vm.prank(user1);
            uint256 amount = groveBasin.withdraw(address(swapToken), user1, type(uint256).max);

            // User gets at least their deposited amount since rate increased
            assertGe(amount, swapTokenAmount);

            assertEq(swapToken.balanceOf(user1),  amount);
            assertEq(_pocketSwapBalance(), swapTokenAmount - amount);

            assertEq(creditToken.balanceOf(user1),               0);
            assertEq(creditToken.balanceOf(user2),               0);
            assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount);

            assertApproxEqAbs(groveBasin.shares(user2), user2Shares, 0);

            vm.prank(user1);
            groveBasin.withdraw(address(creditToken), user1, type(uint256).max);

            assertEq(creditToken.balanceOf(user2), 0);

            vm.prank(user2);
            groveBasin.withdraw(address(creditToken), user2, type(uint256).max);

            // All credit accounted for between user1, user2, and basin (seed's dust)
            assertEq(
                creditToken.balanceOf(user1) + creditToken.balanceOf(user2) + creditToken.balanceOf(address(groveBasin)),
                creditTokenAmount
            );
        }

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        uint256 user1ResultingValue
            = swapToken.balanceOf(user1) * 1e12 + creditToken.balanceOf(user1) * conversionRate / 1e27;

        uint256 user2ResultingValue = creditToken.balanceOf(user2) * conversionRate / 1e27;

        // Total extracted + remaining ≈ totalValue
        assertApproxEqAbs(user1ResultingValue + user2ResultingValue + groveBasin.totalAssets(), totalValue, 2);

        // Value gains are the same for both users, accurate to 0.02%
        // Only check when seed deposit impact is negligible relative to user deposits
        uint256 minUserShares = user1Shares < user2Shares ? user1Shares : user2Shares;
        if (1e18 * 100 < minUserShares) {
            assertApproxEqRel(
                (user1ResultingValue - (swapTokenAmount * 1e12))      * 1e18 / (swapTokenAmount * 1e12),
                (user2ResultingValue - (creditTokenAmount * 125/100)) * 1e18 / (creditTokenAmount * 125/100),
                0.0021e18 + 1e18 * 1e18 / minUserShares
            );
        }
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _checkGroveBasinInvariant() internal view {
        uint256 totalSharesValue = groveBasin.convertToAssetValue(groveBasin.totalShares());
        uint256 totalAssetsValue =
            creditToken.balanceOf(address(groveBasin)) * creditTokenRateProvider.getConversionRate() / 1e27
            + _pocketSwapBalance() * 1e12;

        assertApproxEqAbs(totalSharesValue, totalAssetsValue, 1);
    }

    function _getExpectedWithdrawnAmount(MockERC20 asset, address user, uint256 amount)
        internal view returns (uint256 withdrawAmount)
    {
        uint256 balance = address(asset) == address(swapToken) ? _pocketSwapBalance() : asset.balanceOf(address(groveBasin));
        uint256 userAssets = groveBasin.convertToAssets(address(asset), groveBasin.shares(user));

        // Return the min of assets, balance, and amount
        withdrawAmount = userAssets < balance        ? userAssets : balance;
        withdrawAmount = amount     < withdrawAmount ? amount     : withdrawAmount;
    }

}
