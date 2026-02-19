// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

contract RoundingTests is GroveBasinTestBase {

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        // Seed the GroveBasin with max liquidity so withdrawals can always be performed
        _deposit(address(collateralToken),  address(this), COLLATERAL_TOKEN_MAX);
        _deposit(address(creditToken), address(this), CREDIT_TOKEN_MAX);
        _deposit(address(secondaryToken),  address(this), SECONDARY_TOKEN_MAX);

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

    function test_roundAgainstUser_secondaryToken() public {
        _deposit(address(secondaryToken), address(user), 1e6);

        assertEq(secondaryToken.balanceOf(address(user)), 0);

        vm.prank(user);
        groveBasin.withdraw(address(secondaryToken), address(user), 1e6);

        assertEq(secondaryToken.balanceOf(address(user)), 1e6 - 1);  // Rounds against user
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

    function testFuzz_roundingAgainstUser_multiUser_secondaryToken(
        uint256 rate1,
        uint256 rate2,
        uint256 amount1,
        uint256 amount2
    )
        public
    {
        _runRoundingAgainstUsersFuzzTest(
            secondaryToken,
            SECONDARY_TOKEN_MAX,
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

        _deposit(address(asset), address(user1), amount1);

        assertEq(asset.balanceOf(address(user1)), 0);

        vm.prank(user1);
        groveBasin.withdraw(address(asset), address(user1), amount1);

        // Rounds against user up to one unit, always rounding down
        assertApproxEqAbs(asset.balanceOf(address(user1)), amount1, roundingTolerance);
        assertLe(asset.balanceOf(address(user1)), amount1);

        mockCreditTokenRateProvider.__setConversionRate(rate2);

        _deposit(address(asset), address(user2), amount2);

        assertEq(asset.balanceOf(address(user2)), 0);

        vm.prank(user2);
        groveBasin.withdraw(address(asset), address(user2), amount2);

        // Rounds against user up to one unit, always rounding down

        assertApproxEqAbs(asset.balanceOf(address(user2)), amount2, roundingTolerance);
        assertLe(asset.balanceOf(address(user2)), amount2);
    }
}
