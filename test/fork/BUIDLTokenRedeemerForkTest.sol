// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { BUIDLTokenRedeemer } from "src/BUIDLTokenRedeemer.sol";
import { IGroveBasin }        from "src/interfaces/IGroveBasin.sol";
import { ITokenRedeemer }     from "src/interfaces/ITokenRedeemer.sol";

import { BUIDLForkTestBase, IBUIDLLike } from "test/fork/BUIDLForkTest.sol";

abstract contract BUIDLTokenRedeemerForkTestBase is BUIDLForkTestBase {

    BUIDLTokenRedeemer public redeemer;

    function _initTokens() internal override {
        swapToken       = IERC20(Ethereum.USDS);
        collateralToken = IERC20(Ethereum.USDC);
        creditToken     = IERC20(Ethereum.BUIDLI);

        buidl = IBUIDLLike(Ethereum.BUIDLI);
    }

    function _postDeploy() internal override {
        super._postDeploy();

        redeemer = new BUIDLTokenRedeemer(
            Ethereum.BUIDLI,
            Ethereum.BUIDLI_REDEEM,
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
        assertEq(redeemer.creditToken(),       Ethereum.BUIDLI);
        assertEq(redeemer.collateralToken(),   Ethereum.USDC);
        assertEq(redeemer.redemptionAddress(), Ethereum.BUIDLI_REDEEM);
        assertEq(redeemer.vault(),             Ethereum.BUIDLI_REDEEM);
        assertEq(address(redeemer.basin()),    address(groveBasin));
    }

}

/**********************************************************************************************/
/*** InitiateRedeem tests                                                                   ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerForkTest_InitiateRedeem is BUIDLTokenRedeemerForkTestBase {

    function test_initiateRedeem() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;
        uint256 redemptionAddrBefore = IERC20(Ethereum.BUIDLI).balanceOf(Ethereum.BUIDLI_REDEEM);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        assertEq(IERC20(Ethereum.BUIDLI).balanceOf(address(groveBasin)), depositAmount - redeemAmount);
        assertEq(IERC20(Ethereum.BUIDLI).balanceOf(address(redeemer)),   0);
        assertEq(
            IERC20(Ethereum.BUIDLI).balanceOf(Ethereum.BUIDLI_REDEEM),
            redemptionAddrBefore + redeemAmount
        );
        assertEq(groveBasin.pendingCollateralTokenBalance(), redeemAmount);
    }

    function test_initiateRedeem_emitsEvent() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

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
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        // Simulate offchain settlement: USDC sent to redeemer
        deal(Ethereum.USDC, address(redeemer), redeemAmount);

        uint256 basinUsdcBefore = IERC20(Ethereum.USDC).balanceOf(address(groveBasin));

        vm.prank(owner);
        groveBasin.completeRedeem(address(redeemer), redeemAmount, redeemAmount);

        assertEq(
            IERC20(Ethereum.USDC).balanceOf(address(groveBasin)),
            basinUsdcBefore + redeemAmount
        );
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(redeemer)), 0);
        assertEq(groveBasin.pendingCollateralTokenBalance(), 0);
    }

    function test_completeRedeem_partialFill() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

        uint256 redeemAmount   = 1_000e6;
        uint256 settledAmount  = 999e6;  // Slightly less than redeemed

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        // Simulate partial fill
        deal(Ethereum.USDC, address(redeemer), settledAmount);

        uint256 basinUsdcBefore = IERC20(Ethereum.USDC).balanceOf(address(groveBasin));

        vm.prank(owner);
        groveBasin.completeRedeem(address(redeemer), redeemAmount, redeemAmount);

        assertEq(
            IERC20(Ethereum.USDC).balanceOf(address(groveBasin)),
            basinUsdcBefore + settledAmount
        );
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(redeemer)), 0);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 1_000e6;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        deal(Ethereum.USDC, address(redeemer), redeemAmount);

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.RedeemCompleted(address(redeemer), owner, redeemAmount);

        vm.prank(owner);
        groveBasin.completeRedeem(address(redeemer), redeemAmount, redeemAmount);
    }

}

/**********************************************************************************************/
/*** Full flow tests                                                                        ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerForkTest_FullFlow is BUIDLTokenRedeemerForkTestBase {

    function test_fullFlow_initiateAndComplete() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

        uint256 redeemAmount = 2_000e6;

        // Initiate
        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), redeemAmount);

        assertEq(groveBasin.pendingCollateralTokenBalance(), redeemAmount);
        assertEq(IERC20(Ethereum.BUIDLI).balanceOf(address(groveBasin)), depositAmount - redeemAmount);

        // Simulate settlement
        deal(Ethereum.USDC, address(redeemer), redeemAmount);

        // Complete
        uint256 basinUsdcBefore = IERC20(Ethereum.USDC).balanceOf(address(groveBasin));

        vm.prank(owner);
        groveBasin.completeRedeem(address(redeemer), redeemAmount, redeemAmount);

        assertEq(groveBasin.pendingCollateralTokenBalance(), 0);
        assertEq(
            IERC20(Ethereum.USDC).balanceOf(address(groveBasin)),
            basinUsdcBefore + redeemAmount
        );
    }

    function test_fullFlow_multipleRedemptions() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDLI, makeAddr("lp"), depositAmount);

        // First redemption
        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 1_000e6);
        assertEq(groveBasin.pendingCollateralTokenBalance(), 1_000e6);

        // Second redemption
        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), 2_000e6);
        assertEq(groveBasin.pendingCollateralTokenBalance(), 3_000e6);

        // Complete first (partial settlement)
        deal(Ethereum.USDC, address(redeemer), 999e6);

        vm.prank(owner);
        groveBasin.completeRedeem(address(redeemer), 1_000e6, 1_000e6);

        // pendingCollateralTokenBalance decrements by the actual collateral received
        assertEq(groveBasin.pendingCollateralTokenBalance(), 2_001e6);

        // Complete second
        deal(Ethereum.USDC, address(redeemer), 2_000e6);

        vm.prank(owner);
        groveBasin.completeRedeem(address(redeemer), 2_000e6, 2_000e6);

        // 1e6 remains from the first partial fill (999e6 received vs 1000e6 expected)
        assertEq(groveBasin.pendingCollateralTokenBalance(), 1e6);
    }

}
