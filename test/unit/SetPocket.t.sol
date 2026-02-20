// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinSetPocketFailureTests is GroveBasinTestBase {

    function test_setPocket_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)",
            address(this), groveBasin.DEFAULT_ADMIN_ROLE())
        );
        groveBasin.setPocket(address(1));
    }

    function test_setPocket_invalidPocket() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/invalid-pocket");
        groveBasin.setPocket(address(0));
    }

    function test_setPocket_samePocket() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/same-pocket");
        groveBasin.setPocket(pocket);
    }


    // NOTE: In practice this won't happen because pockets will infinite approve GroveBasin
    function test_setPocket_insufficientAllowanceBoundary() public {
        address pocket1 = makeAddr("pocket1");
        address pocket2 = makeAddr("pocket2");

        vm.prank(owner);
        groveBasin.setPocket(pocket1);

        vm.prank(pocket1);
        swapToken.approve(address(groveBasin), 1_000_000e6);

        deal(address(swapToken), pocket1, 1_000_000e6 + 1);

        vm.prank(owner);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.setPocket(pocket2);

        deal(address(swapToken), pocket1, 1_000_000e6);

        vm.prank(owner);
        groveBasin.setPocket(pocket2);
    }

}

contract GroveBasinSetPocketSuccessTests is GroveBasinTestBase {

    address pocket1 = makeAddr("pocket1");
    address pocket2 = makeAddr("pocket2");

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function test_setPocket_pocketIsGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        deal(address(swapToken), address(groveBasin), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(groveBasin)), 1_000_000e6);
        assertEq(swapToken.balanceOf(pocket1),      0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(groveBasin));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(groveBasin), pocket1, 1_000_000e6);
        groveBasin.setPocket(pocket1);

        assertEq(swapToken.balanceOf(address(groveBasin)), 0);
        assertEq(swapToken.balanceOf(pocket1),      1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), pocket1);
    }

    function test_setPocket_pocketIsNotGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(pocket1);

        vm.prank(pocket1);
        swapToken.approve(address(groveBasin), 1_000_000e6);

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        assertEq(swapToken.allowance(pocket1, address(groveBasin)), 1_000_000e6);

        assertEq(swapToken.balanceOf(pocket1), 1_000_000e6);
        assertEq(swapToken.balanceOf(pocket2), 0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), pocket1);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(pocket1, pocket2, 1_000_000e6);
        groveBasin.setPocket(pocket2);

        assertEq(swapToken.allowance(pocket1, address(groveBasin)), 0);

        assertEq(swapToken.balanceOf(pocket1), 0);
        assertEq(swapToken.balanceOf(pocket2), 1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), pocket2);
    }

    function test_setPocket_valueStaysConstant() public {
        // NOTE: Need to set pocket to GroveBasin because setUp sets pocket to `pocket`, and zero funds
        //       are transferred from `pocket1` to `pocket`
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        _deposit(address(swapToken),  owner, 1_000_000e6);
        _deposit(address(collateralToken),  owner, 1_000_000e18);
        _deposit(address(creditToken), owner, 800_000e18);

        assertEq(groveBasin.totalAssets(), 3_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(pocket1);

        assertEq(groveBasin.totalAssets(), 3_000_000e18);
    }

}
