// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract InflationAttackTests is GroveBasinTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function test_dos_sendFundsBeforeFirstDeposit() public {
        // Attack pool sending funds in before the first deposit
        swapToken.mint(address(this), 100e6);
        swapToken.transfer(pocket, 100e6);

        assertEq(_pocketSwapBalance(), 100e6);

        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        // The no-new-shares check prevents deposits from silently minting zero shares
        // when totalAssets > 0 but totalShares == 0 (inflation attack vector).
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, user1);

        swapToken.mint(user1, 1_000_000e6);
        vm.startPrank(user1);
        swapToken.approve(address(groveBasin), 1_000_000e6);
        vm.expectRevert("GB/no-new-shares");
        groveBasin.deposit(address(swapToken), user1, 1_000_000e6);
        vm.stopPrank();

        // Pool state unchanged - attack is mitigated
        assertEq(_pocketSwapBalance(), 100e6);
        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.shares(user1), 0);
    }

}
