// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { BUIDLTokenRedeemer } from "src/redeemers/BUIDLTokenRedeemer.sol";
import { IGroveBasin }        from "src/interfaces/IGroveBasin.sol";

import { BUIDLForkTestBase, IBUIDLLike } from "test/fork/BUIDLForkTest.sol";

abstract contract BUIDLTokenRedeemerForkTestBase is BUIDLForkTestBase {

    BUIDLTokenRedeemer public redeemer;

    function _initTokens() internal override {
        swapToken       = IERC20(Ethereum.USDS);
        collateralToken = IERC20(Ethereum.USDC);
        creditToken     = IERC20(Ethereum.BUIDL);

        buidl = IBUIDLLike(Ethereum.BUIDL);
    }

    function _postDeploy() internal override {
        super._postDeploy();

        redeemer = new BUIDLTokenRedeemer(
            Ethereum.BUIDL,
            Ethereum.BUIDL_REDEEM,
            address(groveBasin)
        );

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** Deployment tests                                                                       ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerForkTest_Deployment is BUIDLTokenRedeemerForkTestBase {

    function test_deployment() public view {
        assertEq(redeemer.creditToken(),       Ethereum.BUIDL);
        assertEq(redeemer.collateralToken(),   Ethereum.USDC);
        assertEq(redeemer.redemptionAddress(), Ethereum.BUIDL_REDEEM);
        assertEq(redeemer.vault(),             Ethereum.BUIDL_REDEEM);
        assertEq(address(redeemer.basin()),    address(groveBasin));
    }

}

/**********************************************************************************************/
/*** InitiateRedeem tests                                                                   ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerForkTest_InitiateRedeem is BUIDLTokenRedeemerForkTestBase {

    function test_initiateRedeem() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;
        uint256 redemptionAddrBefore = IERC20(Ethereum.BUIDL).balanceOf(Ethereum.BUIDL_REDEEM);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        assertEq(IERC20(Ethereum.BUIDL).balanceOf(address(groveBasin)), depositAmount - redeemAmount);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(address(redeemer)),   0);
        assertEq(
            IERC20(Ethereum.BUIDL).balanceOf(Ethereum.BUIDL_REDEEM),
            redemptionAddrBefore + redeemAmount
        );
        assertEq(groveBasin.pendingCreditTokenBalance(), redeemAmount);
    }

    function test_initiateRedeem_emitsEvent() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.RedeemInitiated(address(redeemer), owner, redeemAmount);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);
    }

}

/**********************************************************************************************/
/*** CompleteRedeem tests                                                                   ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerForkTest_CompleteRedeem is BUIDLTokenRedeemerForkTestBase {

    function test_completeRedeem() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        // Simulate offchain settlement: USDC sent to redeemer
        deal(Ethereum.USDC, address(redeemer), redeemAmount);

        uint256 basinUsdcBefore = IERC20(Ethereum.USDC).balanceOf(address(groveBasin));

        vm.prank(owner);
        groveBasin.completeRedeem(requestId);

        assertEq(
            IERC20(Ethereum.USDC).balanceOf(address(groveBasin)),
            basinUsdcBefore + redeemAmount
        );
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(redeemer)), 0);
        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
    }

    function test_completeRedeem_partialFill() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        uint256 redeemAmount   = 1_000e6;
        uint256 settledAmount  = 999e6;  // Slightly less than redeemed

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        // Simulate partial fill
        deal(Ethereum.USDC, address(redeemer), settledAmount);

        uint256 basinUsdcBefore = IERC20(Ethereum.USDC).balanceOf(address(groveBasin));

        vm.prank(owner);
        groveBasin.completeRedeem(requestId);

        assertEq(
            IERC20(Ethereum.USDC).balanceOf(address(groveBasin)),
            basinUsdcBefore + settledAmount
        );
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(redeemer)), 0);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        deal(Ethereum.USDC, address(redeemer), redeemAmount);

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.RedeemCompleted(address(redeemer), owner, redeemAmount);

        vm.prank(owner);
        groveBasin.completeRedeem(requestId);
    }

}

/**********************************************************************************************/
/*** Full flow tests                                                                        ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerForkTest_FullFlow is BUIDLTokenRedeemerForkTestBase {

    function test_fullFlow_initiateAndComplete() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 2_000e6;

        // Initiate
        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        assertEq(groveBasin.pendingCreditTokenBalance(), redeemAmount);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(address(groveBasin)), depositAmount - redeemAmount);

        // Simulate settlement
        deal(Ethereum.USDC, address(redeemer), redeemAmount);

        // Complete
        uint256 basinUsdcBefore = IERC20(Ethereum.USDC).balanceOf(address(groveBasin));

        vm.prank(owner);
        groveBasin.completeRedeem(requestId);

        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
        assertEq(
            IERC20(Ethereum.USDC).balanceOf(address(groveBasin)),
            basinUsdcBefore + redeemAmount
        );
    }

    function test_fullFlow_multipleRedemptions() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, makeAddr("lp"), depositAmount);

        // First redemption
        vm.prank(owner);
        bytes32 requestId1 = groveBasin.initiateRedeem(address(redeemer), 1_000e6);
        assertEq(groveBasin.pendingCreditTokenBalance(), 1_000e6);

        vm.roll(block.number + 1);

        // Second redemption on different block
        vm.prank(owner);
        bytes32 requestId2 = groveBasin.initiateRedeem(address(redeemer), 2_000e6);
        assertEq(groveBasin.pendingCreditTokenBalance(), 3_000e6);

        // Complete first request
        deal(Ethereum.USDC, address(redeemer), 1_000e6);

        vm.prank(owner);
        groveBasin.completeRedeem(requestId1);

        assertEq(groveBasin.pendingCreditTokenBalance(), 2_000e6);

        // Complete second request
        deal(Ethereum.USDC, address(redeemer), 2_000e6);

        vm.prank(owner);
        groveBasin.completeRedeem(requestId2);

        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
    }

}
