// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

contract RoundingTests is GroveBasinTestBase {

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        // Seed the GroveBasin with max liquidity so withdrawals can always be performed
        _deposit(address(collateralToken),  address(this), COLLATERAL_TOKEN_MAX);
        _deposit(address(creditToken),      address(this), CREDIT_TOKEN_MAX);
        _deposit(address(swapToken),        address(this), SWAP_TOKEN_MAX);

        // Set an exchange rate that will cause rounding
        mockCreditTokenRateProvider.__setConversionRate(1.25e27 * uint256(100) / 99);
    }

    function test_roundAgainstUser_collateralToken() public {
        _deposit(address(collateralToken), address(user), 1e18);

        assertEq(collateralToken.balanceOf(address(user)), 0);

        vm.prank(user);
        groveBasin.withdraw(address(collateralToken), address(user), 1e18);

        assertEq(collateralToken.balanceOf(address(user)), 1e18 - 1);  // Rounds against user
    }

    function test_roundAgainstUser_swapToken() public {
        _deposit(address(swapToken), address(user), 1e6);

        assertEq(swapToken.balanceOf(address(user)), 0);

        vm.prank(user);
        groveBasin.withdraw(address(swapToken), address(user), 1e6);

        assertEq(swapToken.balanceOf(address(user)), 1e6 - 1);  // Rounds against user
    }

    function test_roundAgainstUser_creditToken() public {
        _deposit(address(creditToken), address(user), 1e18);

        assertEq(creditToken.balanceOf(address(user)), 0);

        vm.prank(user);
        groveBasin.withdraw(address(creditToken), address(user), 1e18);

        assertEq(creditToken.balanceOf(address(user)), 1e18 - 1);  // Rounds against user
    }

    function testFuzz_roundingAgainstUser_multiUser_collateralToken(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            collateralToken,
            COLLATERAL_TOKEN_MAX,
            rate1,
            rate2,
            amount1,
            amount2,
            4
        );
    }

    function testFuzz_roundingAgainstUser_multiUser_swapToken(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            swapToken,
            SWAP_TOKEN_MAX,
            rate1,
            rate2,
            amount1,
            amount2,
            1  // Lower precision so rounding errors are lower
        );
    }

    function testFuzz_roundingAgainstUser_multiUser_creditToken(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            creditToken,
            CREDIT_TOKEN_MAX,
            rate1,
            rate2,
            amount1,
            amount2,
            4  // creditToken has higher rounding errors that can be introduced because of rate conversion
        );
    }

    function _runRoundingAgainstUsersFuzzTest(
        MockERC20 asset,
        uint256   tokenMax,
        uint256   rate1,
        uint256   rate2,
        uint256   amount1,
        uint256   amount2,
        uint256   roundingTolerance
    ) internal {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        rate1 = _bound(rate1, 1e27,  10e27);
        rate2 = _bound(rate2, rate1, 10e27);

        amount1 = _bound(amount1, 1, tokenMax);
        amount2 = _bound(amount2, 1, tokenMax);

        mockCreditTokenRateProvider.__setConversionRate(rate1);

        // Skip fuzz inputs where deposit would produce zero shares (guarded by no-new-shares)
        vm.assume(groveBasin.previewDeposit(address(asset), amount1) > 0);

        _deposit(address(asset), address(user1), amount1);

        assertEq(asset.balanceOf(address(user1)), 0);

        vm.prank(user1);
        groveBasin.withdraw(address(asset), address(user1), amount1);

        // Rounds against user up to one unit, always rounding down
        assertApproxEqAbs(asset.balanceOf(address(user1)), amount1, roundingTolerance);
        assertLe(asset.balanceOf(address(user1)), amount1);

        mockCreditTokenRateProvider.__setConversionRate(rate2);

        // Skip fuzz inputs where deposit would produce zero shares (guarded by no-new-shares)
        vm.assume(groveBasin.previewDeposit(address(asset), amount2) > 0);

        _deposit(address(asset), address(user2), amount2);

        assertEq(asset.balanceOf(address(user2)), 0);

        vm.prank(user2);
        groveBasin.withdraw(address(asset), address(user2), amount2);

        // Rounds against user up to one unit, always rounding down

        assertApproxEqAbs(asset.balanceOf(address(user2)), amount2, roundingTolerance);
        assertLe(asset.balanceOf(address(user2)), amount2);
    }
}

contract RoundingZeroShareWithdrawalTests is GroveBasinTestBase {

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        // Set collateral token rate to $0.50 (0.5e27) so that _getCollateralTokenValue(1)
        // evaluates to (1 * 0.5e26 * 1e18) / (1e27 * 1e18) = 0.5, which rounds to 0 (floor) or 1 (ceil).
        mockCollateralTokenRateProvider.__setConversionRate(0.5e27);
    }

    // Worst case: with an 18-decimal token at $0.50, withdrawing 1 wei would previously round
    // the asset value to zero, causing zero shares to burn. The fix passes roundUp through to
    // _getCollateralTokenValue(), so the value rounds up to 1 and at least 1 share is burned.
    function test_withdrawOneWei_collateralToken_roundsUpSharesBurned() public {
        _deposit(address(collateralToken), user, 1e18);

        uint256 sharesBefore = groveBasin.shares(user);
        assertGt(sharesBefore, 0);

        // Preview a 1 wei withdrawal as `user`: asset value must round up so sharesToBurn > 0
        vm.prank(user);
        ( uint256 sharesToBurn, uint256 assetsWithdrawn ) = groveBasin.previewWithdraw(address(collateralToken), 1);

        assertEq(assetsWithdrawn, 1);
        assertGt(sharesToBurn, 0, "sharesToBurn must be non-zero for 1 wei withdrawal");

        // Execute the withdrawal and verify shares are actually burned
        vm.prank(user);
        groveBasin.withdraw(address(collateralToken), user, 1);

        assertLt(groveBasin.shares(user), sharesBefore, "shares must decrease after withdrawal");
    }

    // Same scenario but with the swap token: 6-decimal token at $0.50.
    // _getSwapTokenValue(1) = (1 * 0.5e27 * 1e18) / (1e27 * 1e6) = 5e11, which is non-zero even
    // without rounding up, but we verify the invariant that sharesToBurn > 0 holds regardless.
    function test_withdrawOneWei_swapToken_roundsUpSharesBurned() public {
        mockSwapTokenRateProvider.__setConversionRate(0.5e27);

        _deposit(address(swapToken), user, 1e6);

        uint256 sharesBefore = groveBasin.shares(user);
        assertGt(sharesBefore, 0);

        vm.prank(user);
        ( uint256 sharesToBurn, uint256 assetsWithdrawn ) = groveBasin.previewWithdraw(address(swapToken), 1);

        assertEq(assetsWithdrawn, 1);
        assertGt(sharesToBurn, 0, "sharesToBurn must be non-zero for 1 wei withdrawal");

        vm.prank(user);
        groveBasin.withdraw(address(swapToken), user, 1);

        assertLt(groveBasin.shares(user), sharesBefore, "shares must decrease after withdrawal");
    }
}
