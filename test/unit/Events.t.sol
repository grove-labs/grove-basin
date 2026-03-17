// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinEventTests is GroveBasinTestBase {

    event Swap(
        address indexed assetIn,
        address indexed assetOut,
        address sender,
        address indexed receiver,
        uint256 amountIn,
        uint256 amountOut,
        uint256 referralCode
    );

    event Deposit(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsDeposited,
        uint256 sharesMinted
    );

    event Withdraw(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsWithdrawn,
        uint256 sharesBurned
    );

    address sender   = makeAddr("sender");
    address receiver = makeAddr("receiver");

    function test_deposit_events() public {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, sender);

        vm.startPrank(sender);

        collateralToken.mint(sender, 100e18);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectEmit(address(groveBasin));
        emit Deposit(address(collateralToken), sender, receiver, 100e18, 100e18);
        groveBasin.deposit(address(collateralToken), receiver, 100e18);

        swapToken.mint(sender, 100e6);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectEmit(address(groveBasin));
        emit Deposit(address(swapToken), sender, receiver, 100e6, 100e18);
        groveBasin.deposit(address(swapToken), receiver, 100e6);

        creditToken.mint(sender, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        vm.expectEmit(address(groveBasin));
        emit Deposit(address(creditToken), sender, receiver, 100e18, 125e18);
        groveBasin.deposit(address(creditToken), receiver, 100e18);
    }

    function test_withdraw_events() public {
        _deposit(address(collateralToken),  sender, 100e18);
        _deposit(address(swapToken), sender, 100e6);
        _deposit(address(creditToken), sender, 100e18);

        vm.startPrank(sender);

        vm.expectEmit(address(groveBasin));
        emit Withdraw(address(collateralToken), sender, receiver, 100e18, 100e18);
        groveBasin.withdraw(address(collateralToken), receiver, 100e18);

        vm.expectEmit(address(groveBasin));
        emit Withdraw(address(swapToken), sender, receiver, 100e6, 100e18);
        groveBasin.withdraw(address(swapToken), receiver, 100e6);

        vm.expectEmit(address(groveBasin));
        emit Withdraw(address(creditToken), sender, receiver, 100e18, 125e18);
        groveBasin.withdraw(address(creditToken), receiver, 100e18);
    }

    function test_swap_events() public {
        collateralToken.mint(address(groveBasin),  1000e18);
        swapToken.mint(pocket, 1000e6);
        creditToken.mint(address(groveBasin), 1000e18);

        vm.startPrank(sender);

        _swapEventTest(address(collateralToken), address(creditToken), 100e18, 80e18, 1);

        _swapEventTest(address(swapToken), address(creditToken), 100e6, 80e18,  2);

        _swapEventTest(address(creditToken), address(collateralToken), 100e18, 125e18, 3);
        _swapEventTest(address(creditToken), address(swapToken), 100e18, 125e6,  4);
    }

    function _swapEventTest(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        uint16  referralCode
    ) internal {
        MockERC20(assetIn).mint(sender, amountIn);
        MockERC20(assetIn).approve(address(groveBasin), amountIn);

        vm.expectEmit(address(groveBasin));
        emit Swap(assetIn, assetOut, sender, receiver, amountIn, expectedAmountOut, referralCode);
        groveBasin.swapExactIn(assetIn, assetOut, amountIn, 0, receiver, referralCode);
    }

}
