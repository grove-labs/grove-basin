// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinSetMaxSwapSizeFailureTests is GroveBasinTestBase {

    function test_setMaxSwapSize_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ROLE()
            )
        );
        groveBasin.setMaxSwapSize(1e18);
    }

    function test_setMaxSwapSize_belowLowerBound() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSizeBounds(100e18, 1_000_000e18);

        vm.prank(owner);
        vm.expectRevert("GB/swap-size-oob");
        groveBasin.setMaxSwapSize(50e18);
    }

    function test_setMaxSwapSize_aboveUpperBound() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSizeBounds(100e18, 1_000_000e18);

        vm.prank(owner);
        vm.expectRevert("GB/swap-size-oob");
        groveBasin.setMaxSwapSize(2_000_000e18);
    }

}

contract GroveBasinSetMaxSwapSizeBoundsFailureTests is GroveBasinTestBase {

    function test_setMaxSwapSizeBounds_lowerBoundGreaterThanUpperBound() public {
        vm.prank(owner);
        vm.expectRevert("GB/min-gt-max-swap-size");
        groveBasin.setMaxSwapSizeBounds(1_000_000e18, 100e18);
    }

}

contract GroveBasinSetMaxSwapSizeBoundsClampTests is GroveBasinTestBase {

    event MaxSwapSizeSet(uint256 oldMaxSwapSize, uint256 newMaxSwapSize);
    event MaxSwapSizeBoundsSet(uint256 oldLowerBound, uint256 oldUpperBound, uint256 newLowerBound, uint256 newUpperBound);

    function test_setMaxSwapSizeBounds_clampsMaxSwapSizeUp() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(50e18);

        assertEq(groveBasin.maxSwapSize(), 50e18);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit MaxSwapSizeSet(50e18, 500e18);
        groveBasin.setMaxSwapSizeBounds(500e18, 1_000_000e18);

        assertEq(groveBasin.maxSwapSize(),           500e18);
        assertEq(groveBasin.maxSwapSizeLowerBound(), 500e18);
    }

    function test_setMaxSwapSizeBounds_clampsMaxSwapSizeDown() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(500e18);

        assertEq(groveBasin.maxSwapSize(), 500e18);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit MaxSwapSizeSet(500e18, 200e18);
        groveBasin.setMaxSwapSizeBounds(0, 200e18);

        assertEq(groveBasin.maxSwapSize(),          200e18);
        assertEq(groveBasin.maxSwapSizeUpperBound(), 200e18);
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
