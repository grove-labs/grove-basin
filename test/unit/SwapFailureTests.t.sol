// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

/**
 * @title SwapFailureTestBase
 * @notice Base contract for common swap failure tests shared between SwapExactIn and SwapExactOut
 * @dev Consolidates duplicate validation tests to reduce code duplication
 */
abstract contract SwapFailureTestBase is GroveBasinTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public virtual override {
        super.setUp();

        // Needed for boundary success conditions
        swapToken.mint(pocket, 100e6);
        creditToken.mint(address(groveBasin), 100e18);
    }

    // Abstract functions to be implemented by concrete test contracts
    function swapFunction(
        address assetIn,
        address assetOut,
        uint256 amountSpecified,
        uint256 amountLimit,
        address recipient,
        uint256 deadline
    ) internal virtual returns (uint256);

    function getAmountZeroRevertMessage() internal pure virtual returns (string memory);

    /**********************************************************************************************/
    /*** Common Validation Tests                                                                ***/
    /**********************************************************************************************/

    function test_swap_amountZero() public {
        vm.expectRevert(bytes(getAmountZeroRevertMessage()));
        swapFunction(address(swapToken), address(creditToken), 0, 0, receiver, 0);
    }

    function test_swap_receiverZero() public {
        vm.expectRevert("GroveBasin/invalid-receiver");
        swapFunction(address(swapToken), address(creditToken), 100e6, 80e18, address(0), 0);
    }

    function test_swap_invalid_assetIn() public {
        vm.expectRevert();  // Different revert messages between ExactIn and ExactOut
        swapFunction(makeAddr("other-token"), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swap_invalid_assetOut() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        swapFunction(address(swapToken), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swap_bothSwapToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        swapFunction(address(swapToken), address(swapToken), 100e6, 80e18, receiver, 0);
    }

    function test_swap_bothCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        swapFunction(address(collateralToken), address(collateralToken), 100e6, 80e18, receiver, 0);
    }

    function test_swap_bothCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        swapFunction(address(creditToken), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swap_collateralTokenToSwapToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        swapFunction(address(collateralToken), address(swapToken), 100e18, 100e6, receiver, 0);
    }

    function test_swap_swapTokenToCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        swapFunction(address(swapToken), address(collateralToken), 100e6, 100e18, receiver, 0);
    }
}

contract GroveBasinSwapExactInFailureTests is SwapFailureTestBase {

    function swapFunction(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) internal override returns (uint256) {
        return groveBasin.swapExactIn(assetIn, assetOut, amountIn, minAmountOut, recipient, deadline);
    }

    function getAmountZeroRevertMessage() internal pure override returns (string memory) {
        return "GroveBasin/invalid-amountIn";
    }

    function test_swapExactIn_minAmountOutBoundary() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 100e6);

        uint256 expectedAmountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("GroveBasin/amountOut-too-low");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 80e18 + 1, receiver, 0);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientApproveBoundary() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 80e18, receiver, 0);

        swapToken.approve(address(groveBasin), 100e6);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientUserBalanceBoundary() public {
        swapToken.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 80e18, receiver, 0);

        swapToken.mint(swapper, 1);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientGroveBasinBalanceBoundary() public {
        // NOTE: Using 2 instead of 1 here because 1/1.25 rounds to 0, 2/1.25 rounds to 1
        //       this is because the conversion rate is divided out before the precision conversion
        //       is done.
        swapToken.mint(swapper, 125e6 + 2);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 125e6 + 2);

        uint256 expectedAmountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 125e6 + 2);

        assertEq(expectedAmountOut, 100.000001e18);  // More than balance of creditToken

        vm.expectRevert("SafeERC20/transfer-failed");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 125e6 + 2, 100e18, receiver, 0);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 125e6, 100e18, receiver, 0);
    }

}

contract GroveBasinSwapExactOutFailureTests is SwapFailureTestBase {

    function swapFunction(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address recipient,
        uint256 deadline
    ) internal override returns (uint256) {
        return groveBasin.swapExactOut(assetIn, assetOut, amountOut, maxAmountIn, recipient, deadline);
    }

    function getAmountZeroRevertMessage() internal pure override returns (string memory) {
        return "GroveBasin/invalid-amountOut";
    }

    function test_swapExactOut_maxAmountBoundary() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 100e6);

        uint256 expectedAmountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);

        assertEq(expectedAmountIn, 100e6);

        vm.expectRevert("GroveBasin/amountIn-too-high");
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 100e6 - 1, receiver, 0);

        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientApproveBoundary() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 100e6, receiver, 0);

        swapToken.approve(address(groveBasin), 100e6);

        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientUserBalanceBoundary() public {
        swapToken.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 100e6, receiver, 0);

        swapToken.mint(swapper, 1);

        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientGroveBasinBalanceBoundary() public {
        // NOTE: Using higher amount so transfer fails
        swapToken.mint(swapper, 125e6 + 1);

        vm.startPrank(swapper);

        swapToken.approve(address(groveBasin), 125e6 + 1);

        vm.expectRevert("SafeERC20/transfer-failed");
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 100e18 + 1, 125e6 + 1, receiver, 0);

        groveBasin.swapExactOut(address(swapToken), address(creditToken), 100e18, 125e6 + 1, receiver, 0);
    }

}
