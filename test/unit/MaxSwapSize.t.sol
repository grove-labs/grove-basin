// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinMaxSwapSizeSwapExactInTests is GroveBasinTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        swapToken.mint(pocket, 1_000_000e6);
        creditToken.mint(address(groveBasin), 1_000_000e18);
        collateralToken.mint(address(groveBasin), 1_000_000e18);

        vm.prank(owner);
        groveBasin.setMaxSwapSize(100e18);
    }

    function test_swapExactIn_swapTokenToCreditToken_exceedsMaxSwapSize() public {
        swapToken.mint(swapper, 101e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 101e6);

        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 101e6, 0, receiver, 0);
    }

    function test_swapExactIn_swapTokenToCreditToken_exactMaxSwapSize() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactIn_swapTokenToCreditToken_belowMaxSwapSize() public {
        swapToken.mint(swapper, 99e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 99e6);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 99e6, 0, receiver, 0);
    }

    function test_swapExactIn_collateralTokenToCreditToken_exceedsMaxSwapSize() public {
        collateralToken.mint(swapper, 101e18);

        vm.startPrank(swapper);
        collateralToken.approve(address(groveBasin), 101e18);

        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 101e18, 0, receiver, 0);
    }

    function test_swapExactIn_collateralTokenToCreditToken_exactMaxSwapSize() public {
        collateralToken.mint(swapper, 100e18);

        vm.startPrank(swapper);
        collateralToken.approve(address(groveBasin), 100e18);

        groveBasin.swapExactIn(address(collateralToken), address(creditToken), 100e18, 0, receiver, 0);
    }

    function test_swapExactIn_creditTokenToSwapToken_exceedsMaxSwapSize() public {
        // creditToken at 1.25 rate, 80e18 credit = 100e18 value, 81e18 credit > 100e18 value
        creditToken.mint(swapper, 81e18);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 81e18);

        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.swapExactIn(address(creditToken), address(swapToken), 81e18, 0, receiver, 0);
    }

    function test_swapExactIn_creditTokenToSwapToken_exactMaxSwapSize() public {
        // 80e18 credit * 1.25 = 100e18 value
        creditToken.mint(swapper, 80e18);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 80e18);

        groveBasin.swapExactIn(address(creditToken), address(swapToken), 80e18, 0, receiver, 0);
    }

    function test_swapExactIn_creditTokenToCollateralToken_exceedsMaxSwapSize() public {
        creditToken.mint(swapper, 81e18);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 81e18);

        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 81e18, 0, receiver, 0);
    }

    function test_swapExactIn_swapsDisabled() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(0);

        swapToken.mint(swapper, 1e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 1e6);

        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 1e6, 0, receiver, 0);
    }

    function test_swapExactIn_defaultMaxSwapSize() public {
        GroveBasin basin = new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertEq(basin.maxSwapSize(), 50_000_000e18);
    }

}

contract GroveBasinMaxSwapSizeSwapExactOutTests is GroveBasinTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        swapToken.mint(pocket, 1_000_000e6);
        creditToken.mint(address(groveBasin), 1_000_000e18);
        collateralToken.mint(address(groveBasin), 1_000_000e18);

        vm.prank(owner);
        groveBasin.setMaxSwapSize(100e18);
    }

    function test_swapExactOut_swapTokenToCreditToken_exceedsMaxSwapSize() public {
        // amountIn of 101e6 swap token = 101e18 value > 100e18 max
        // Preview also reverts since check is in _getSwapQuote
        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80.8e18);
    }

    function test_swapExactOut_swapTokenToCreditToken_exactMaxSwapSize() public {
        // 100e6 swap token in = 100e18 value = max
        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);

        assertEq(amountIn, 100e6);

        swapToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);

        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, amountIn, receiver, 0);
    }

    function test_swapExactOut_creditTokenToSwapToken_exceedsMaxSwapSize() public {
        // 81e18 credit * 1.25 = 101.25e18 value > 100e18 max
        // Preview also reverts since check is in _getSwapQuote
        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 101e6);
    }

    function test_swapExactOut_creditTokenToSwapToken_exactMaxSwapSize() public {
        // 80e18 credit * 1.25 = 100e18 value = max
        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 100e6);

        assertEq(amountIn, 80e18);

        creditToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), amountIn);

        groveBasin.swapExactOut(address(creditToken), address(swapToken), 100e6, amountIn, receiver, 0);
    }

    function test_swapExactOut_swapsDisabled() public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(0);

        vm.expectRevert("GroveBasin/swap-size-exceeded");
        groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 800_000e18);
    }

}

contract GroveBasinMaxSwapSizeFuzzTests is GroveBasinTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        collateralToken.mint(address(groveBasin), COLLATERAL_TOKEN_MAX * 100);
        swapToken.mint(pocket, SWAP_TOKEN_MAX * 100);
        creditToken.mint(address(groveBasin), CREDIT_TOKEN_MAX * 100);
    }

    function testFuzz_swapExactIn_maxSwapSize_reverts(
        uint256 maxSwapSize,
        uint256 amountIn
    )
        public
    {
        maxSwapSize = _bound(maxSwapSize, 1, 1_000_000e18);
        amountIn    = _bound(amountIn, 1, SWAP_TOKEN_MAX);

        vm.prank(owner);
        groveBasin.setMaxSwapSize(maxSwapSize);

        uint256 swapValue = amountIn * 1e12;  // swap token value in 1e18 terms

        swapToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);

        if (swapValue > maxSwapSize) {
            vm.expectRevert("GroveBasin/swap-size-exceeded");
        }

        groveBasin.swapExactIn(address(swapToken), address(creditToken), amountIn, 0, receiver, 0);
    }

    function testFuzz_swapExactIn_maxSwapSize_collateralToken(
        uint256 maxSwapSize,
        uint256 amountIn
    )
        public
    {
        maxSwapSize = _bound(maxSwapSize, 1, 1_000_000e18);
        amountIn    = _bound(amountIn, 1, COLLATERAL_TOKEN_MAX);

        vm.prank(owner);
        groveBasin.setMaxSwapSize(maxSwapSize);

        uint256 swapValue = amountIn;  // collateral token 1:1 at default rate

        collateralToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        collateralToken.approve(address(groveBasin), amountIn);

        if (swapValue > maxSwapSize) {
            vm.expectRevert("GroveBasin/swap-size-exceeded");
        }

        groveBasin.swapExactIn(address(collateralToken), address(creditToken), amountIn, 0, receiver, 0);
    }

    function testFuzz_swapExactIn_maxSwapSize_creditToken(
        uint256 maxSwapSize,
        uint256 amountIn
    )
        public
    {
        maxSwapSize = _bound(maxSwapSize, 1, 1_000_000e18);
        amountIn    = _bound(amountIn, 1, CREDIT_TOKEN_MAX);

        vm.prank(owner);
        groveBasin.setMaxSwapSize(maxSwapSize);

        // credit token value = amountIn * 1.25e27 / 1e27 = amountIn * 1.25
        uint256 swapValue = amountIn * 1.25e27 / 1e27;

        creditToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), amountIn);

        if (swapValue > maxSwapSize) {
            vm.expectRevert("GroveBasin/swap-size-exceeded");
        }

        groveBasin.swapExactIn(address(creditToken), address(swapToken), amountIn, 0, receiver, 0);
    }

    function testFuzz_swapExactOut_maxSwapSize_reverts(
        uint256 maxSwapSize,
        uint256 amountOut
    )
        public
    {
        maxSwapSize = _bound(maxSwapSize, 1, 1_000_000e18);

        vm.prank(owner);
        groveBasin.setMaxSwapSize(maxSwapSize);

        // Swap credit -> swap token. amountOut in swap token terms.
        amountOut = _bound(amountOut, 1, _pocketSwapBalance());

        // Compute the expected input value to determine if the swap exceeds maxSwapSize.
        // amountOut is in swap token (6 decimals), value = amountOut * 1e12.
        // amountIn in credit token, rounded up. Credit rate = 1.25e27.
        // swapValue = amountIn * 1.25e27 / 1e27
        uint256 swapTokenValue = amountOut * 1e12;

        // The preview reverts if the computed input value exceeds maxSwapSize.
        // Use try/catch since rounding can cause the input value to exceed even when
        // the output value is under the limit.
        try groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), amountOut)
            returns (uint256 amountIn)
        {
            creditToken.mint(swapper, amountIn);

            vm.startPrank(swapper);
            creditToken.approve(address(groveBasin), amountIn);

            groveBasin.swapExactOut(
                address(creditToken),
                address(swapToken),
                amountOut,
                amountIn,
                receiver,
                0
            );
        } catch {
            vm.expectRevert("GroveBasin/swap-size-exceeded");
            groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), amountOut);
        }
    }

    function testFuzz_setMaxSwapSize(uint256 maxSwapSize) public {
        vm.prank(owner);
        groveBasin.setMaxSwapSize(maxSwapSize);

        assertEq(groveBasin.maxSwapSize(), maxSwapSize);
    }

}
