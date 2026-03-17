// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ForkTestBase }     from "test/fork/ForkTestBase.sol";
import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

interface IFullRestrictionsLike {
    function updateMember(address token, address user, uint64 validUntil) external;
    function isMember(address token, address user) external view returns (bool isValid, uint64 validUntil);
    function wards(address who) external view returns (uint256);
}

interface IShareTokenLike {
    function balanceOf(address) external view returns (uint256);
    function hookDataOf(address) external view returns (bytes16);
}

abstract contract JTRSYForkTestBase is ForkTestBase {

    address public constant JTRSY_TOKEN         = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address public constant FULL_RESTRICTIONS   = 0x8E680873b4C77e6088b4Ba0aBD59d100c3D224a4;
    address public constant CENTRIFUGE_ROOT     = 0x7Ed48C31f2fdC40d37407cBaBf0870B2b688368f;

    IFullRestrictionsLike public fullRestrictions = IFullRestrictionsLike(FULL_RESTRICTIONS);

    function _initTokens() internal override {
        swapToken       = IERC20(Ethereum.USDS);
        collateralToken = IERC20(Ethereum.USDC);
        creditToken     = IERC20(JTRSY_TOKEN);
    }

    function _initRateProviders() internal override {
        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        // USDS at $1
        swapTokenRateProvider.__setConversionRate(1e27);

        // USDC at $1
        collateralTokenRateProvider.__setConversionRate(1e27);

        // JTRSY at ~$1.05 (example NAV per share)
        creditTokenRateProvider.__setConversionRate(1.05e27);
    }

    function _postDeploy() internal override {
        _addToJTRSYAllowlist(address(groveBasin));
        _addToJTRSYAllowlist(pocket);
    }

    function _addToJTRSYAllowlist(address account) internal {
        // Give ourselves ward access on the FullRestrictions hook to call updateMember.
        // Storage slot 0 is the `wards` mapping in the Auth base contract.
        vm.store(
            FULL_RESTRICTIONS,
            keccak256(abi.encode(address(this), uint256(0))),
            bytes32(uint256(1))
        );
        fullRestrictions.updateMember(JTRSY_TOKEN, account, type(uint64).max);
    }

    function _dealToken(address token, address to, uint256 amount) internal override {
        if (token == JTRSY_TOKEN) {
            _dealJTRSY(to, amount);
        } else {
            deal(token, to, amount);
        }
    }

    // Centrifuge share tokens pack hookData (upper 128 bits) and balance (lower 128 bits)
    // in the same storage slot, so Foundry's deal() cannot be used directly.
    function _dealJTRSY(address to, uint256 amount) internal {
        require(amount <= type(uint128).max, "JTRSY balance overflow");

        _addToJTRSYAllowlist(to);

        // Find the packed storage slot by probing balanceOf
        IShareTokenLike token = IShareTokenLike(JTRSY_TOKEN);
        bytes16 hookData = token.hookDataOf(to);
        bytes32 slot = _findBalanceSlot(to);

        // Write combined hookData (upper 128 bits) + balance (lower 128 bits)
        bytes32 packed = bytes32(uint256(uint128(hookData)) << 128 | uint256(amount));
        vm.store(JTRSY_TOKEN, slot, packed);

        assertEq(token.balanceOf(to), amount);
    }

    function _findBalanceSlot(address account) internal returns (bytes32) {
        // Probe storage to find the slot that controls balanceOf(account)
        vm.record();
        IShareTokenLike(JTRSY_TOKEN).balanceOf(account);
        (bytes32[] memory reads,) = vm.accesses(JTRSY_TOKEN);
        require(reads.length > 0, "Could not find balance slot");
        return reads[0];
    }

}

/**********************************************************************************************/
/*** Deployment and basic sanity tests                                                      ***/
/**********************************************************************************************/

contract JTRSYForkTest_Deployment is JTRSYForkTestBase {

    function test_deployment() public view {
        assertEq(address(groveBasin.swapToken()),       Ethereum.USDS);
        assertEq(address(groveBasin.collateralToken()), Ethereum.USDC);
        assertEq(address(groveBasin.creditToken()),     JTRSY_TOKEN);
        assertEq(groveBasin.pocket(),                   pocket);
    }

    function test_jtrsyAllowlist() public view {
        (bool isMember,) = fullRestrictions.isMember(JTRSY_TOKEN, address(groveBasin));
        assertTrue(isMember);
    }

}

/**********************************************************************************************/
/*** Deposit tests                                                                          ***/
/**********************************************************************************************/

contract JTRSYForkTest_Deposit is JTRSYForkTestBase {

    address public depositor = makeAddr("depositor");

    function test_deposit_creditToken() public {
        uint256 amount = 1000e6;  // JTRSY has 6 decimals
        _deposit(JTRSY_TOKEN, depositor, amount);

        assertGt(groveBasin.shares(depositor), 0);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(address(groveBasin)), amount);
    }

    function test_deposit_collateralToken() public {
        uint256 amount = 1000e6;
        _deposit(Ethereum.USDC, depositor, amount);

        assertGt(groveBasin.shares(depositor), 0);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(groveBasin)), amount);
    }

    function test_deposit_swapToken() public {
        uint256 amount = 1000e18;
        _deposit(Ethereum.USDS, depositor, amount);

        assertGt(groveBasin.shares(depositor), 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(pocket), amount);
    }

    function test_deposit_allTokens() public {
        _deposit(Ethereum.USDS, depositor, 1000e18);
        uint256 sharesAfterFirst = groveBasin.shares(depositor);

        _deposit(Ethereum.USDC, depositor, 1000e6);
        uint256 sharesAfterSecond = groveBasin.shares(depositor);

        _deposit(JTRSY_TOKEN, depositor, 1000e6);
        uint256 sharesAfterThird = groveBasin.shares(depositor);

        assertGt(sharesAfterSecond, sharesAfterFirst);
        assertGt(sharesAfterThird, sharesAfterSecond);
    }

}

/**********************************************************************************************/
/*** Withdraw tests                                                                         ***/
/**********************************************************************************************/

contract JTRSYForkTest_Withdraw is JTRSYForkTestBase {

    address public depositor = makeAddr("depositor");
    address public receiver  = makeAddr("receiver");

    function setUp() public override {
        super.setUp();
        _addToJTRSYAllowlist(receiver);
    }

    function test_withdraw_creditToken() public {
        uint256 depositAmount = 1000e6;  // JTRSY has 6 decimals
        _deposit(JTRSY_TOKEN, depositor, depositAmount);

        uint256 sharesBefore = groveBasin.shares(depositor);

        _withdraw(JTRSY_TOKEN, depositor, receiver, depositAmount);

        assertLt(groveBasin.shares(depositor), sharesBefore);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), depositAmount);
    }

    function test_withdraw_collateralToken() public {
        uint256 depositAmount = 1000e6;
        _deposit(Ethereum.USDC, depositor, depositAmount);

        uint256 sharesBefore = groveBasin.shares(depositor);

        _withdraw(Ethereum.USDC, depositor, receiver, depositAmount);

        assertLt(groveBasin.shares(depositor), sharesBefore);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), depositAmount);
    }

    function test_withdraw_swapToken() public {
        uint256 depositAmount = 1000e18;
        _deposit(Ethereum.USDS, depositor, depositAmount);

        uint256 sharesBefore = groveBasin.shares(depositor);

        _withdraw(Ethereum.USDS, depositor, receiver, depositAmount);

        assertLt(groveBasin.shares(depositor), sharesBefore);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), depositAmount);
    }

}

/**********************************************************************************************/
/*** Swap tests                                                                             ***/
/**********************************************************************************************/

contract JTRSYForkTest_SwapExactIn is JTRSYForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _addToJTRSYAllowlist(swapper);
        _addToJTRSYAllowlist(receiver);

        // Seed GroveBasin with liquidity
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDC, makeAddr("lp2"), 100_000e6);
        _deposit(JTRSY_TOKEN,   makeAddr("lp3"), 100_000e6);  // JTRSY has 6 decimals
    }

    function test_swapExactIn_swapTokenToCreditToken() public {
        uint256 amountIn = 1000e18;
        _dealToken(Ethereum.USDS, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(Ethereum.USDS, JTRSY_TOKEN, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.USDS, JTRSY_TOKEN, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), amountOut);
        assertEq(IERC20(Ethereum.USDS).balanceOf(swapper), 0);
    }

    function test_swapExactIn_creditTokenToSwapToken() public {
        uint256 amountIn = 1000e6;  // JTRSY has 6 decimals
        _dealToken(JTRSY_TOKEN, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(JTRSY_TOKEN, Ethereum.USDS, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(JTRSY_TOKEN, Ethereum.USDS, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_collateralTokenToCreditToken() public {
        uint256 amountIn = 1000e6;
        _dealToken(Ethereum.USDC, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDC).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(Ethereum.USDC, JTRSY_TOKEN, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.USDC, JTRSY_TOKEN, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_creditTokenToCollateralToken() public {
        uint256 amountIn = 1000e6;  // JTRSY has 6 decimals
        _dealToken(JTRSY_TOKEN, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(JTRSY_TOKEN, Ethereum.USDC, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(JTRSY_TOKEN, Ethereum.USDC, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_invalidSwap_swapTokenToCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.swapExactIn(Ethereum.USDS, Ethereum.USDC, 100e18, 0, receiver, 0);
    }

    function test_swapExactIn_invalidSwap_collateralTokenToSwapToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.swapExactIn(Ethereum.USDC, Ethereum.USDS, 100e6, 0, receiver, 0);
    }

}

contract JTRSYForkTest_SwapExactOut is JTRSYForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _addToJTRSYAllowlist(swapper);
        _addToJTRSYAllowlist(receiver);

        // Seed GroveBasin with liquidity
        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDC, makeAddr("lp2"), 100_000e6);
        _deposit(JTRSY_TOKEN,   makeAddr("lp3"), 100_000e6);  // JTRSY has 6 decimals
    }

    function test_swapExactOut_swapTokenToCreditToken() public {
        uint256 amountOut = 1000e6;  // JTRSY has 6 decimals
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.USDS, JTRSY_TOKEN, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(Ethereum.USDS, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(Ethereum.USDS, JTRSY_TOKEN, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_creditTokenToSwapToken() public {
        uint256 amountOut = 1000e18;
        uint256 expectedIn = groveBasin.previewSwapExactOut(JTRSY_TOKEN, Ethereum.USDS, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(JTRSY_TOKEN, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(JTRSY_TOKEN, Ethereum.USDS, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_collateralTokenToCreditToken() public {
        uint256 amountOut = 1000e6;  // JTRSY has 6 decimals
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.USDC, JTRSY_TOKEN, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(Ethereum.USDC, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDC).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(Ethereum.USDC, JTRSY_TOKEN, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_creditTokenToCollateralToken() public {
        uint256 amountOut = 1000e6;
        uint256 expectedIn = groveBasin.previewSwapExactOut(JTRSY_TOKEN, Ethereum.USDC, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(JTRSY_TOKEN, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(JTRSY_TOKEN, Ethereum.USDC, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

}

/**********************************************************************************************/
/*** Allowlist enforcement tests                                                            ***/
/**********************************************************************************************/

contract JTRSYForkTest_Allowlist is JTRSYForkTestBase {

    address public depositor  = makeAddr("depositor");
    address public nonMember  = makeAddr("nonMember");

    function test_withdraw_creditToken_toNonMember_reverts() public {
        _deposit(JTRSY_TOKEN, depositor, 1000e6);

        vm.prank(depositor);
        vm.expectRevert();
        groveBasin.withdraw(JTRSY_TOKEN, nonMember, 1000e6);
    }

    function test_withdraw_creditToken_toMember_succeeds() public {
        _deposit(JTRSY_TOKEN, depositor, 1000e6);

        _addToJTRSYAllowlist(nonMember);

        vm.prank(depositor);
        groveBasin.withdraw(JTRSY_TOKEN, nonMember, 1000e6);

        assertEq(IERC20(JTRSY_TOKEN).balanceOf(nonMember), 1000e6);
    }

    function test_swap_creditTokenOut_toNonMember_reverts() public {
        _deposit(JTRSY_TOKEN, makeAddr("lp"), 100_000e6);

        uint256 amountIn = 1000e18;
        _dealToken(Ethereum.USDS, depositor, amountIn);

        vm.startPrank(depositor);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        vm.expectRevert();
        groveBasin.swapExactIn(Ethereum.USDS, JTRSY_TOKEN, amountIn, 0, nonMember, 0);
        vm.stopPrank();
    }

    function test_swap_creditTokenOut_toMember_succeeds() public {
        _deposit(JTRSY_TOKEN, makeAddr("lp"), 100_000e6);

        _addToJTRSYAllowlist(nonMember);

        uint256 amountIn = 1000e18;
        _dealToken(Ethereum.USDS, depositor, amountIn);

        vm.startPrank(depositor);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.USDS, JTRSY_TOKEN, amountIn, 0, nonMember, 0);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(nonMember), amountOut);
    }

}
