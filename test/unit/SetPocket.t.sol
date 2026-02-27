// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasinTestBase }    from "test/GroveBasinTestBase.sol";
import { MockGroveBasinPocket }  from "test/mocks/MockGroveBasinPocket.sol";

contract GroveBasinSetPocketFailureTests is GroveBasinTestBase {

    function test_setPocket_invalidOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
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
        groveBasin.setPocket(address(groveBasin));
    }

    function test_setPocket_notContract() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/pocket-not-contract");
        groveBasin.setPocket(makeAddr("eoa"));
    }

    // NOTE: In practice this won't happen because pockets will infinite approve GroveBasin
    function test_setPocket_insufficientAllowanceBoundary() public {
        MockGroveBasinPocket pocket1 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));
        MockGroveBasinPocket pocket2 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        // Override the max approval with a limited one
        vm.prank(address(pocket1));
        swapToken.approve(address(groveBasin), 1_000_000e6);

        deal(address(swapToken), address(pocket1), 1_000_000e6 + 1);

        vm.prank(owner);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.setPocket(address(pocket2));

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket2));
    }

}

contract GroveBasinSetPocketSuccessTests is GroveBasinTestBase {

    MockGroveBasinPocket pocket1;
    MockGroveBasinPocket pocket2;

    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    function setUp() public override {
        super.setUp();
        pocket1 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));
        pocket2 = new MockGroveBasinPocket(address(groveBasin), address(swapToken));
    }

    function test_setPocket_pocketIsGroveBasin() public {
        deal(address(swapToken), address(groveBasin), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(groveBasin)), 1_000_000e6);
        assertEq(swapToken.balanceOf(address(pocket1)),    0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(groveBasin));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(groveBasin), address(pocket1), 1_000_000e6);
        groveBasin.setPocket(address(pocket1));

        assertEq(swapToken.balanceOf(address(groveBasin)), 0);
        assertEq(swapToken.balanceOf(address(pocket1)),    1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket1));
    }

    function test_setPocket_pocketIsNotGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        deal(address(swapToken), address(pocket1), 1_000_000e6);

        assertEq(swapToken.balanceOf(address(pocket1)), 1_000_000e6);
        assertEq(swapToken.balanceOf(address(pocket2)), 0);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket1));

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PocketSet(address(pocket1), address(pocket2), 1_000_000e6);
        groveBasin.setPocket(address(pocket2));

        assertEq(swapToken.balanceOf(address(pocket1)), 0);
        assertEq(swapToken.balanceOf(address(pocket2)), 1_000_000e6);

        assertEq(groveBasin.totalAssets(), 1_000_000e18);

        assertEq(groveBasin.pocket(), address(pocket2));
    }

    function test_setPocket_valueStaysConstant() public {
        _deposit(address(swapToken),   owner, 1_000_000e6);
        _deposit(address(collateralToken),  owner, 1_000_000e18);
        _deposit(address(creditToken), owner, 800_000e18);

        assertEq(groveBasin.totalAssets(), 3_000_000e18);

        vm.prank(owner);
        groveBasin.setPocket(address(pocket1));

        assertEq(groveBasin.totalAssets(), 3_000_000e18);
    }

}
