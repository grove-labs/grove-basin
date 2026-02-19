// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract InflationAttackTests is GroveBasinTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function test_dos_sendFundsBeforeFirstDeposit() public {
        // Attack pool sending funds in before the first deposit
        secondaryToken.mint(address(this), 100e6);
        secondaryToken.transfer(pocket, 100e6);

        assertEq(secondaryToken.balanceOf(pocket), 100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        _deposit(address(secondaryToken), address(user1), 1_000_000e6);

        // Since exchange rate is zero, convertToShares returns 1m * 0 / 100e6
        // because totalValue is not zero so it enters that if statement.
        // This results in the funds going in the pool with no way for the user
        // to recover them.
        assertEq(secondaryToken.balanceOf(pocket), 1_000_100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        // This issue is not related to the first deposit only because totalShares cannot
        // get above zero.
        _deposit(address(secondaryToken), address(user2), 1_000_000e6);

        assertEq(secondaryToken.balanceOf(pocket), 2_000_100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);
    }

}
