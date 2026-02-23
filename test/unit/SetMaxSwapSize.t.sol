// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinSetMaxSwapSizeFailureTests is GroveBasinTestBase {

    function test_setMaxSwapSize_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)",
            address(this), groveBasin.DEFAULT_ADMIN_ROLE())
        );
        groveBasin.setMaxSwapSize(1e18);
    }

}

contract GroveBasinSetMaxSwapSizeSuccessTests is GroveBasinTestBase {

    event MaxSwapSizeSet(uint256 oldMaxSwapSize, uint256 newMaxSwapSize);

    function test_setMaxSwapSize() public {
        assertEq(groveBasin.maxSwapSize(), 10_000_000_000_000_000e18);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit MaxSwapSizeSet(10_000_000_000_000_000e18, 1_000_000e18);
        groveBasin.setMaxSwapSize(1_000_000e18);

        assertEq(groveBasin.maxSwapSize(), 1_000_000e18);
    }

    function test_setMaxSwapSize_toZero() public {
        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit MaxSwapSizeSet(10_000_000_000_000_000e18, 0);
        groveBasin.setMaxSwapSize(0);

        assertEq(groveBasin.maxSwapSize(), 0);
    }

    function test_setMaxSwapSize_update() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(1_000_000e18);

        assertEq(groveBasin.maxSwapSize(), 1_000_000e18);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit MaxSwapSizeSet(1_000_000e18, 2_000_000e18);
        groveBasin.setMaxSwapSize(2_000_000e18);

        assertEq(groveBasin.maxSwapSize(), 2_000_000e18);
    }

    function test_setMaxSwapSize_sameValue() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(1_000_000e18);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit MaxSwapSizeSet(1_000_000e18, 1_000_000e18);
        groveBasin.setMaxSwapSize(1_000_000e18);

        assertEq(groveBasin.maxSwapSize(), 1_000_000e18);
    }

}
