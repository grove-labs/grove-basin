// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinDepositTests is GroveBasinTestBase {

    address user1     = makeAddr("user1");
    address user2     = makeAddr("user2");
    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function setUp() public override {
        super.setUp();

        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.startPrank(owner);
        groveBasin.grantRole(lpRole, user1);
        groveBasin.grantRole(lpRole, user2);
        vm.stopPrank();
    }

    function test_deposit_zeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("GroveBasin/invalid-amount");
        groveBasin.deposit(address(swapToken), user1, 0);
    }

    function test_deposit_invalidAsset() public {
        // NOTE: This reverts in _getAssetValue
        vm.prank(user1);
        vm.expectRevert("GroveBasin/invalid-asset-for-value");
        groveBasin.deposit(makeAddr("new-asset"), user1, 100e6);
    }

    function test_deposit_insufficientApproveBoundary() public {
        collateralToken.mint(user1, 100e18);

        vm.startPrank(user1);

        collateralToken.approve(address(groveBasin), 100e18 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.deposit(address(collateralToken), user1, 100e18);

        collateralToken.approve(address(groveBasin), 100e18);

        groveBasin.deposit(address(collateralToken), user1, 100e18);
    }

    function test_deposit_insufficientBalanceBoundary() public {
        collateralToken.mint(user1, 100e18 - 1);

        vm.startPrank(user1);

        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.deposit(address(collateralToken), user1, 100e18);

        collateralToken.mint(user1, 1);

        groveBasin.deposit(address(collateralToken), user1, 100e18);
    }

    function test_deposit_firstDepositCollateralToken() public {
        collateralToken.mint(user1, 100e18);

        vm.startPrank(user1);

        collateralToken.approve(address(groveBasin), 100e18);

        assertEq(collateralToken.allowance(user1, address(groveBasin)), 100e18);
        assertEq(collateralToken.balanceOf(user1),                      100e18);
        assertEq(collateralToken.balanceOf(address(groveBasin)),        0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(collateralToken), receiver1, 100e18);

        assertEq(newShares, 100e18);

        assertEq(collateralToken.allowance(user1, address(groveBasin)), 0);
        assertEq(collateralToken.balanceOf(user1),                      0);
        assertEq(collateralToken.balanceOf(address(groveBasin)),        100e18);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositSwapToken() public {
        swapToken.mint(user1, 100e6);

        vm.startPrank(user1);

        swapToken.approve(address(groveBasin), 100e6);

        assertEq(swapToken.allowance(user1, address(groveBasin)), 100e6);

        assertEq(swapToken.balanceOf(user1), 100e6);
        assertEq(_pocketSwapBalance(),       0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(swapToken.allowance(user1, address(groveBasin)), 0);

        assertEq(swapToken.balanceOf(user1), 0);
        assertEq(_pocketSwapBalance(),       100e6);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositSwapToken_pocketIsGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));
        pocket = address(groveBasin);

        swapToken.mint(user1, 100e6);

        vm.startPrank(user1);

        swapToken.approve(address(groveBasin), 100e6);

        assertEq(swapToken.allowance(user1, address(groveBasin)), 100e6);

        assertEq(swapToken.balanceOf(user1),               100e6);
        assertEq(swapToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(swapToken.allowance(user1, address(groveBasin)), 0);

        assertEq(swapToken.balanceOf(user1),               0);
        assertEq(swapToken.balanceOf(address(groveBasin)), 100e6);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositCreditToken() public {
        creditToken.mint(user1, 100e18);

        vm.startPrank(user1);

        creditToken.approve(address(groveBasin), 100e18);

        assertEq(creditToken.allowance(user1, address(groveBasin)), 100e18);

        assertEq(creditToken.balanceOf(user1),               100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(creditToken), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(creditToken.allowance(user1, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(),     125e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 125e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_swapTokenThenCreditToken() public {
        swapToken.mint(user1, 100e6);

        vm.startPrank(user1);

        swapToken.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        creditToken.mint(user1, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        assertEq(_pocketSwapBalance(), 100e6);

        assertEq(creditToken.allowance(user1, address(groveBasin)), 100e18);

        assertEq(creditToken.balanceOf(user1),               100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        newShares = groveBasin.deposit(address(creditToken), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(_pocketSwapBalance(), 100e6);

        assertEq(creditToken.allowance(user1, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(),     225e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function testFuzz_deposit_swapTokenThenCreditToken(uint256 swapTokenAmount, uint256 creditTokenAmount) public {
        // Zero amounts revert
        swapTokenAmount = _bound(swapTokenAmount, 1, SWAP_TOKEN_MAX);
        creditTokenAmount = _bound(creditTokenAmount, 1, CREDIT_TOKEN_MAX);

        swapToken.mint(user1, swapTokenAmount);

        vm.startPrank(user1);

        swapToken.approve(address(groveBasin), swapTokenAmount);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, swapTokenAmount);

        assertEq(newShares, swapTokenAmount * 1e12);

        creditToken.mint(user1, creditTokenAmount);
        creditToken.approve(address(groveBasin), creditTokenAmount);

        assertEq(_pocketSwapBalance(), swapTokenAmount);

        assertEq(creditToken.allowance(user1, address(groveBasin)), creditTokenAmount);

        assertEq(creditToken.balanceOf(user1),               creditTokenAmount);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     swapTokenAmount * 1e12);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), swapTokenAmount * 1e12);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        newShares = groveBasin.deposit(address(creditToken), receiver1, creditTokenAmount);

        assertEq(newShares, creditTokenAmount * 125/100);

        assertEq(_pocketSwapBalance(), swapTokenAmount);

        assertEq(creditToken.allowance(user1, address(groveBasin)), 0);
        
        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount);

        assertEq(groveBasin.totalShares(),     swapTokenAmount * 1e12 + creditTokenAmount * 125/100);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), swapTokenAmount * 1e12 + creditTokenAmount * 125/100);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_multiUser_changeConversionRate() public {
        swapToken.mint(user1, 100e6);

        vm.startPrank(user1);

        swapToken.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        creditToken.mint(user1, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        newShares = groveBasin.deposit(address(creditToken), receiver1, 100e18);

        assertEq(newShares, 125e18);

        vm.stopPrank();

        assertEq(_pocketSwapBalance(), 100e6);

        assertEq(creditToken.allowance(user1, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(),     225e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 225e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 creditToken value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(groveBasin.convertToShares(1e18), expectedConversionRate);

        vm.startPrank(user2);

        creditToken.mint(user2, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        assertEq(creditToken.allowance(user2, address(groveBasin)), 100e18);

        assertEq(creditToken.balanceOf(user2),               100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 250e18);
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 0);

        assertEq(groveBasin.totalAssets(), 250e18);

        newShares = groveBasin.deposit(address(creditToken), receiver2, 100e18);

        assertEq(newShares, 135e18);

        assertEq(creditToken.allowance(user2, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(user2),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 200e18);

        // Depositing 150 dollars of value at 0.9 exchange rate
        uint256 expectedShares = 150e18 * 9/10;

        assertEq(expectedShares, 135e18);

        assertEq(groveBasin.totalShares(),     360e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(user2),     0);
        assertEq(groveBasin.shares(receiver1), 225e18);
        assertEq(groveBasin.shares(receiver2), 135e18);

        // Receiver 1 earned $25 on 225, Receiver 2 has earned nothing
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 250e18);
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 150e18);

        assertEq(groveBasin.totalAssets(), 400e18);
    }

    function testFuzz_deposit_multiUser_changeConversionRate(
        uint256 swapTokenAmount,
        uint256 creditTokenAmount1,
        uint256 creditTokenAmount2,
        uint256 newRate
    )
        public
    {
        // Zero amounts revert
        swapTokenAmount    = _bound(swapTokenAmount,    1,       SWAP_TOKEN_MAX);
        creditTokenAmount1 = _bound(creditTokenAmount1, 1,       CREDIT_TOKEN_MAX);
        creditTokenAmount2 = _bound(creditTokenAmount2, 1,       CREDIT_TOKEN_MAX);
        newRate            = _bound(newRate,            1.25e27, 1000e27);

        uint256 user1DepositValue = swapTokenAmount * 1e12 + creditTokenAmount1 * 125/100;

        swapToken.mint(user1, swapTokenAmount);

        vm.startPrank(user1);

        swapToken.approve(address(groveBasin), swapTokenAmount);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, swapTokenAmount);

        assertEq(newShares, swapTokenAmount * 1e12);

        creditToken.mint(user1, creditTokenAmount1);
        creditToken.approve(address(groveBasin), creditTokenAmount1);

        newShares = groveBasin.deposit(address(creditToken), receiver1, creditTokenAmount1);

        assertEq(newShares, creditTokenAmount1 * 125/100);

        vm.stopPrank();

        assertEq(_pocketSwapBalance(), swapTokenAmount);

        assertEq(creditToken.balanceOf(user1),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount1);

        // Deposited at 1:1 conversion
        uint256 receiver1Shares = user1DepositValue;

        assertEq(groveBasin.totalShares(),     receiver1Shares);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), receiver1Shares);

        mockCreditTokenRateProvider.__setConversionRate(newRate);

        vm.startPrank(user2);

        creditToken.mint(user2, creditTokenAmount2);
        creditToken.approve(address(groveBasin), creditTokenAmount2);

        assertEq(creditToken.allowance(user2, address(groveBasin)), creditTokenAmount2);
    
        assertEq(creditToken.balanceOf(user2),               creditTokenAmount2);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount1);

        // Receiver1 has gained from conversion change
        uint256 receiver1NewValue = user1DepositValue + creditTokenAmount1 * (newRate - 1.25e27) / 1e27;

        // Receiver1 has gained from conversion change
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(groveBasin.shares(receiver1)),
            receiver1NewValue,
            1
        );

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 0);

        assertApproxEqAbs(groveBasin.totalAssets(), receiver1NewValue, 1);

        newShares = groveBasin.deposit(address(creditToken), receiver2, creditTokenAmount2);

        // Using queried values here instead of derived to avoid larger errors getting introduced
        // Assertions above prove that these values are as expected.
        uint256 receiver2Shares
            = (creditTokenAmount2 * newRate / 1e27) * groveBasin.totalShares() / groveBasin.totalAssets();

        assertApproxEqAbs(newShares, receiver2Shares, 2);

        assertEq(creditToken.allowance(user2, address(groveBasin)), 0);
    
        assertEq(creditToken.balanceOf(user2),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount1 + creditTokenAmount2);

        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        assertApproxEqAbs(groveBasin.totalShares(),     receiver1Shares + receiver2Shares, 2);
        assertApproxEqAbs(groveBasin.shares(receiver1), receiver1Shares,                   2);
        assertApproxEqAbs(groveBasin.shares(receiver2), receiver2Shares,                   2);

        uint256 receiver2NewValue = creditTokenAmount2 * newRate / 1e27;

        // Rate change of up to 1000x introduces errors
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), receiver1NewValue, 1000);
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), receiver2NewValue, 1000);

        assertApproxEqAbs(groveBasin.totalAssets(), receiver1NewValue + receiver2NewValue, 1000);
    }

}

