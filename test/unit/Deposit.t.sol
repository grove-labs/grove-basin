// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract PSMDepositTests is GroveBasinTestBase {

    address user1     = makeAddr("user1");
    address user2     = makeAddr("user2");
    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function test_deposit_zeroAmount() public {
        vm.expectRevert("GroveBasin/invalid-amount");
        groveBasin.deposit(address(usdc), user1, 0);
    }

    function test_deposit_invalidAsset() public {
        // NOTE: This reverts in _getAssetValue
        vm.expectRevert("GroveBasin/invalid-asset-for-value");
        groveBasin.deposit(makeAddr("new-asset"), user1, 100e6);
    }

    function test_deposit_insufficientApproveBoundary() public {
        usds.mint(user1, 100e18);

        vm.startPrank(user1);

        usds.approve(address(groveBasin), 100e18 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.deposit(address(usds), user1, 100e18);

        usds.approve(address(groveBasin), 100e18);

        groveBasin.deposit(address(usds), user1, 100e18);
    }

    function test_deposit_insufficientBalanceBoundary() public {
        usds.mint(user1, 100e18 - 1);

        vm.startPrank(user1);

        usds.approve(address(groveBasin), 100e18);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.deposit(address(usds), user1, 100e18);

        usds.mint(user1, 1);

        groveBasin.deposit(address(usds), user1, 100e18);
    }

    function test_deposit_firstDepositUsds() public {
        usds.mint(user1, 100e18);

        vm.startPrank(user1);

        usds.approve(address(groveBasin), 100e18);

        assertEq(usds.allowance(user1, address(groveBasin)), 100e18);
        assertEq(usds.balanceOf(user1),               100e18);
        assertEq(usds.balanceOf(address(groveBasin)),        0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(usds), receiver1, 100e18);

        assertEq(newShares, 100e18);

        assertEq(usds.allowance(user1, address(groveBasin)), 0);
        assertEq(usds.balanceOf(user1),               0);
        assertEq(usds.balanceOf(address(groveBasin)),        100e18);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositUsdc() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(groveBasin), 100e6);

        assertEq(usdc.allowance(user1, address(groveBasin)), 100e6);
        assertEq(usdc.balanceOf(user1),               100e6);
        assertEq(usdc.balanceOf(pocket),              0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(usdc.allowance(user1, address(groveBasin)), 0);
        assertEq(usdc.balanceOf(user1),               0);
        assertEq(usdc.balanceOf(pocket),              100e6);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositUsdc_pocketIsPsm() public {
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(groveBasin), 100e6);

        assertEq(usdc.allowance(user1, address(groveBasin)), 100e6);
        assertEq(usdc.balanceOf(user1),               100e6);
        assertEq(usdc.balanceOf(address(groveBasin)),        0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(usdc.allowance(user1, address(groveBasin)), 0);
        assertEq(usdc.balanceOf(user1),               0);
        assertEq(usdc.balanceOf(address(groveBasin)),       100e6);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositSUsds() public {
        susds.mint(user1, 100e18);

        vm.startPrank(user1);

        susds.approve(address(groveBasin), 100e18);

        assertEq(susds.allowance(user1, address(groveBasin)), 100e18);
        assertEq(susds.balanceOf(user1),               100e18);
        assertEq(susds.balanceOf(address(groveBasin)),        0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(susds), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(susds.allowance(user1, address(groveBasin)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(groveBasin)),        100e18);

        assertEq(groveBasin.totalShares(),     125e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 125e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_usdcThenSUsds() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        susds.mint(user1, 100e18);
        susds.approve(address(groveBasin), 100e18);

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(susds.allowance(user1, address(groveBasin)), 100e18);
        assertEq(susds.balanceOf(user1),               100e18);
        assertEq(susds.balanceOf(address(groveBasin)),        0);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        newShares = groveBasin.deposit(address(susds), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(susds.allowance(user1, address(groveBasin)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(groveBasin)),        100e18);

        assertEq(groveBasin.totalShares(),     225e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function testFuzz_deposit_usdcThenSUsds(uint256 usdcAmount, uint256 susdsAmount) public {
        // Zero amounts revert
        usdcAmount = _bound(usdcAmount, 1, USDC_TOKEN_MAX);
        susdsAmount = _bound(susdsAmount, 1, SUSDS_TOKEN_MAX);

        usdc.mint(user1, usdcAmount);

        vm.startPrank(user1);

        usdc.approve(address(groveBasin), usdcAmount);

        uint256 newShares = groveBasin.deposit(address(usdc), receiver1, usdcAmount);

        assertEq(newShares, usdcAmount * 1e12);

        susds.mint(user1, susdsAmount);
        susds.approve(address(groveBasin), susdsAmount);

        assertEq(usdc.balanceOf(pocket), usdcAmount);

        assertEq(susds.allowance(user1, address(groveBasin)), susdsAmount);
        assertEq(susds.balanceOf(user1),               susdsAmount);
        assertEq(susds.balanceOf(address(groveBasin)),        0);

        assertEq(groveBasin.totalShares(),     usdcAmount * 1e12);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), usdcAmount * 1e12);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        newShares = groveBasin.deposit(address(susds), receiver1, susdsAmount);

        assertEq(newShares, susdsAmount * 125/100);

        assertEq(usdc.balanceOf(pocket), usdcAmount);

        assertEq(susds.allowance(user1, address(groveBasin)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(groveBasin)),        susdsAmount);

        assertEq(groveBasin.totalShares(),     usdcAmount * 1e12 + susdsAmount * 125/100);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), usdcAmount * 1e12 + susdsAmount * 125/100);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_multiUser_changeConversionRate() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        susds.mint(user1, 100e18);
        susds.approve(address(groveBasin), 100e18);

        newShares = groveBasin.deposit(address(susds), receiver1, 100e18);

        assertEq(newShares, 125e18);

        vm.stopPrank();

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(susds.allowance(user1, address(groveBasin)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(groveBasin)),        100e18);

        assertEq(groveBasin.totalShares(),     225e18);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 225e18);

        mockRateProvider.__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 sUSDS value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(groveBasin.convertToShares(1e18), expectedConversionRate);

        vm.startPrank(user2);

        susds.mint(user2, 100e18);
        susds.approve(address(groveBasin), 100e18);

        assertEq(susds.allowance(user2, address(groveBasin)), 100e18);
        assertEq(susds.balanceOf(user2),               100e18);
        assertEq(susds.balanceOf(address(groveBasin)),        100e18);

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 250e18);
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 0);

        assertEq(groveBasin.totalAssets(), 250e18);

        newShares = groveBasin.deposit(address(susds), receiver2, 100e18);

        assertEq(newShares, 135e18);

        assertEq(susds.allowance(user2, address(groveBasin)), 0);
        assertEq(susds.balanceOf(user2),               0);
        assertEq(susds.balanceOf(address(groveBasin)),        200e18);

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
        uint256 usdcAmount,
        uint256 susdsAmount1,
        uint256 susdsAmount2,
        uint256 newRate
    )
        public
    {
        // Zero amounts revert
        usdcAmount   = _bound(usdcAmount,   1,       USDC_TOKEN_MAX);
        susdsAmount1 = _bound(susdsAmount1, 1,       SUSDS_TOKEN_MAX);
        susdsAmount2 = _bound(susdsAmount2, 1,       SUSDS_TOKEN_MAX);
        newRate      = _bound(newRate,      1.25e27, 1000e27);

        uint256 user1DepositValue = usdcAmount * 1e12 + susdsAmount1 * 125/100;

        usdc.mint(user1, usdcAmount);

        vm.startPrank(user1);

        usdc.approve(address(groveBasin), usdcAmount);

        uint256 newShares = groveBasin.deposit(address(usdc), receiver1, usdcAmount);

        assertEq(newShares, usdcAmount * 1e12);

        susds.mint(user1, susdsAmount1);
        susds.approve(address(groveBasin), susdsAmount1);

        newShares = groveBasin.deposit(address(susds), receiver1, susdsAmount1);

        assertEq(newShares, susdsAmount1 * 125/100);

        vm.stopPrank();

        assertEq(usdc.balanceOf(pocket), usdcAmount);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(address(groveBasin)), susdsAmount1);

        // Deposited at 1:1 conversion
        uint256 receiver1Shares = user1DepositValue;

        assertEq(groveBasin.totalShares(),     receiver1Shares);
        assertEq(groveBasin.shares(user1),     0);
        assertEq(groveBasin.shares(receiver1), receiver1Shares);

        mockRateProvider.__setConversionRate(newRate);

        vm.startPrank(user2);

        susds.mint(user2, susdsAmount2);
        susds.approve(address(groveBasin), susdsAmount2);

        assertEq(susds.allowance(user2, address(groveBasin)), susdsAmount2);
        assertEq(susds.balanceOf(user2),               susdsAmount2);
        assertEq(susds.balanceOf(address(groveBasin)),        susdsAmount1);

        // Receiver1 has gained from conversion change
        uint256 receiver1NewValue = user1DepositValue + susdsAmount1 * (newRate - 1.25e27) / 1e27;

        // Receiver1 has gained from conversion change
        assertApproxEqAbs(
            groveBasin.convertToAssetValue(groveBasin.shares(receiver1)),
            receiver1NewValue,
            1
        );

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 0);

        assertApproxEqAbs(groveBasin.totalAssets(), receiver1NewValue, 1);

        newShares = groveBasin.deposit(address(susds), receiver2, susdsAmount2);

        // Using queried values here instead of derived to avoid larger errors getting introduced
        // Assertions above prove that these values are as expected.
        uint256 receiver2Shares
            = (susdsAmount2 * newRate / 1e27) * groveBasin.totalShares() / groveBasin.totalAssets();

        assertApproxEqAbs(newShares, receiver2Shares, 2);

        assertEq(susds.allowance(user2, address(groveBasin)), 0);
        assertEq(susds.balanceOf(user2),               0);
        assertEq(susds.balanceOf(address(groveBasin)),        susdsAmount1 + susdsAmount2);

        assertEq(groveBasin.shares(user1), 0);
        assertEq(groveBasin.shares(user2), 0);

        assertApproxEqAbs(groveBasin.totalShares(),     receiver1Shares + receiver2Shares, 2);
        assertApproxEqAbs(groveBasin.shares(receiver1), receiver1Shares,                   2);
        assertApproxEqAbs(groveBasin.shares(receiver2), receiver2Shares,                   2);

        uint256 receiver2NewValue = susdsAmount2 * newRate / 1e27;

        // Rate change of up to 1000x introduces errors
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), receiver1NewValue, 1000);
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), receiver2NewValue, 1000);

        assertApproxEqAbs(groveBasin.totalAssets(), receiver1NewValue + receiver2NewValue, 1000);
    }

}
