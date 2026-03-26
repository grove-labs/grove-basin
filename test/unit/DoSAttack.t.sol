// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract InflationAttackTests is GroveBasinTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function test_dos_sendFundsBeforeFirstDeposit() public {
        // Seed pool with initial deposit
        address seeder = makeAddr("seeder");
        swapToken.mint(seeder, 1e6);
        vm.startPrank(seeder);
        swapToken.approve(address(groveBasin), 1e6);
        groveBasin.depositInitial(address(swapToken), 1e6);
        vm.stopPrank();

        uint256 seederShares = groveBasin.shares(address(0));
        assertGt(seederShares, 0);

        // Attack pool by sending funds after the initial deposit.
        swapToken.mint(address(this), 100e6);
        swapToken.transfer(pocket, 100e6);

        assertEq(_pocketSwapBalance(), 101e6);

        _deposit(address(swapToken), address(user1), 1_000_000e6);

        // Pocket has seed + attack + user1 deposit
        assertEq(_pocketSwapBalance(), 1_000_101e6);

        uint256 user1Shares = groveBasin.shares(user1);
        assertGt(user1Shares, 0);

        _deposit(address(swapToken), address(user2), 1_000_000e6);

        assertEq(_pocketSwapBalance(), 2_000_101e6);

        uint256 user2Shares = groveBasin.shares(user2);
        assertGt(user2Shares, 0);
        assertEq(groveBasin.totalShares(), seederShares + user1Shares + user2Shares);
    }

}
