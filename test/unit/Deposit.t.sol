// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { IGroveBasin }       from "src/interfaces/IGroveBasin.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinDepositTests is GroveBasinTestBase {

    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function test_deposit_firstDeposit_nonLp() public {
        GroveBasin freshBasin = new GroveBasin(
            owner, lp,
            address(swapToken), address(collateralToken), address(creditToken),
            address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider)
        );

        collateralToken.mint(address(this), 100e18);
        collateralToken.approve(address(freshBasin), 100e18);

        vm.expectRevert(IGroveBasin.NotLiquidityProvider.selector);
        freshBasin.deposit(address(collateralToken), address(this), 100e18);
    }

    function test_deposit_firstDeposit_nonLpExceedsCap() public {
        GroveBasin freshBasin = new GroveBasin(
            owner, lp,
            address(swapToken), address(collateralToken), address(creditToken),
            address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider)
        );

        uint256 tooMuch = 101e6;
        swapToken.mint(address(this), tooMuch);
        swapToken.approve(address(freshBasin), tooMuch);

        vm.expectRevert(IGroveBasin.NotLiquidityProvider.selector);
        freshBasin.deposit(address(swapToken), address(this), tooMuch);
    }

    function test_deposit_noNewShares() public {
        // First deposit to establish totalShares > 0
        swapToken.mint(lp, 1e6);
        vm.startPrank(lp);
        swapToken.approve(address(groveBasin), 1e6);
        groveBasin.deposit(address(swapToken), lp, 1e6);
        vm.stopPrank();

        // Donate a huge amount of collateral to inflate exchange rate
        collateralToken.mint(address(groveBasin), 1e30);

        // Now try to deposit 1 wei of collateral - should produce 0 shares
        // assetValue = 1 * 1e27 / (1e27 * 1e18) * 1e18 = 1
        // shares = 1 * totalShares / totalAssets ≈ 0 (totalAssets >> totalShares)
        collateralToken.mint(lp, 1);
        vm.startPrank(lp);
        collateralToken.approve(address(groveBasin), 1);
        vm.expectRevert(IGroveBasin.NoNewShares.selector);
        groveBasin.deposit(address(collateralToken), lp, 1);
        vm.stopPrank();
    }

    function test_deposit_zeroAmount() public {
        vm.prank(lp);
        vm.expectRevert(IGroveBasin.ZeroAmount.selector);
        groveBasin.deposit(address(swapToken), lp, 0);
    }

    function test_deposit_invalidAsset() public {
        // NOTE: This reverts in _getAssetValue
        vm.prank(lp);
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        groveBasin.deposit(makeAddr("new-asset"), lp, 100e6);
    }

    function test_deposit_insufficientApproveBoundary() public {
        collateralToken.mint(lp, 100e18);

        vm.startPrank(lp);

        collateralToken.approve(address(groveBasin), 100e18 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.deposit(address(collateralToken), lp, 100e18);

        collateralToken.approve(address(groveBasin), 100e18);

        groveBasin.deposit(address(collateralToken), lp, 100e18);
    }

    function test_deposit_insufficientBalanceBoundary() public {
        collateralToken.mint(lp, 100e18 - 1);

        vm.startPrank(lp);

        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.deposit(address(collateralToken), lp, 100e18);

        collateralToken.mint(lp, 1);

        groveBasin.deposit(address(collateralToken), lp, 100e18);
    }

    function test_deposit_collateralToken() public {
        collateralToken.mint(lp, 100e18);

        vm.startPrank(lp);

        collateralToken.approve(address(groveBasin), 100e18);

        assertEq(collateralToken.allowance(lp, address(groveBasin)), 100e18);
        assertEq(collateralToken.balanceOf(lp),                      100e18);
        assertEq(collateralToken.balanceOf(address(groveBasin)),     0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(collateralToken), receiver1, 100e18);

        assertEq(newShares, 100e18);

        assertEq(collateralToken.allowance(lp, address(groveBasin)), 0);
        assertEq(collateralToken.balanceOf(lp),                      0);
        assertEq(collateralToken.balanceOf(address(groveBasin)),     100e18);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_swapToken() public {
        swapToken.mint(lp, 100e6);

        vm.startPrank(lp);

        swapToken.approve(address(groveBasin), 100e6);

        assertEq(swapToken.allowance(lp, address(groveBasin)), 100e6);

        assertEq(swapToken.balanceOf(lp), 100e6);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(swapToken.allowance(lp, address(groveBasin)), 0);

        assertEq(swapToken.balanceOf(lp), 0);
        assertEq(_pocketSwapBalance(),    100e6);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_swapToken_pocketIsGroveBasin() public {
        vm.prank(owner);
        groveBasin.setPocket(address(groveBasin));

        swapToken.mint(lp, 100e6);

        vm.startPrank(lp);

        swapToken.approve(address(groveBasin), 100e6);

        assertEq(swapToken.allowance(lp, address(groveBasin)), 100e6);

        assertEq(swapToken.balanceOf(lp), 100e6);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(swapToken.allowance(lp, address(groveBasin)), 0);

        assertEq(swapToken.balanceOf(lp), 0);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_creditToken() public {
        creditToken.mint(lp, 100e18);

        vm.startPrank(lp);

        creditToken.approve(address(groveBasin), 100e18);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 100e18);

        assertEq(creditToken.balanceOf(lp),               100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     0);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 0);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        uint256 newShares = groveBasin.deposit(address(creditToken), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(),     125e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 125e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_swapTokenThenCreditToken() public {
        swapToken.mint(lp, 100e6);

        vm.startPrank(lp);

        swapToken.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        creditToken.mint(lp, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 100e18);

        assertEq(creditToken.balanceOf(lp),               100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     100e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 100e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        newShares = groveBasin.deposit(address(creditToken), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(),     225e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function testFuzz_deposit_swapTokenThenCreditToken(uint256 swapTokenAmount, uint256 creditTokenAmount) public {
        // Zero amounts revert
        swapTokenAmount = _bound(swapTokenAmount, 1, SWAP_TOKEN_MAX);
        creditTokenAmount = _bound(creditTokenAmount, 1, CREDIT_TOKEN_MAX);

        swapToken.mint(lp, swapTokenAmount);

        vm.startPrank(lp);

        swapToken.approve(address(groveBasin), swapTokenAmount);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, swapTokenAmount);

        // Shares = value * totalShares / totalAssets = swapTokenAmount * 1e12 * 1e18 / 1e18
        assertEq(newShares, swapTokenAmount * 1e12);

        creditToken.mint(lp, creditTokenAmount);
        creditToken.approve(address(groveBasin), creditTokenAmount);

        assertEq(creditToken.allowance(lp, address(groveBasin)), creditTokenAmount);

        assertEq(creditToken.balanceOf(lp),               creditTokenAmount);
        assertEq(creditToken.balanceOf(address(groveBasin)), 0);

        assertEq(groveBasin.totalShares(),     swapTokenAmount * 1e12);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), swapTokenAmount * 1e12);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        newShares = groveBasin.deposit(address(creditToken), receiver1, creditTokenAmount);

        assertEq(newShares, creditTokenAmount * 125/100);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 0);
        
        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount);

        assertEq(groveBasin.totalShares(),     swapTokenAmount * 1e12 + creditTokenAmount * 125/100);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), swapTokenAmount * 1e12 + creditTokenAmount * 125/100);

        assertEq(groveBasin.convertToShares(1e18), 1e18);
    }

    function test_deposit_multiDeposit_changeConversionRate() public {
        swapToken.mint(lp, 100e6);

        vm.startPrank(lp);

        swapToken.approve(address(groveBasin), 100e6);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);

        assertEq(newShares, 100e18);

        creditToken.mint(lp, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        newShares = groveBasin.deposit(address(creditToken), receiver1, 100e18);

        assertEq(newShares, 125e18);

        vm.stopPrank();

        assertEq(creditToken.allowance(lp, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.totalShares(),     225e18);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 225e18);

        assertEq(groveBasin.convertToShares(1e18), 1e18);

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 225e18);

        mockCreditTokenRateProvider.__setConversionRate(1.5e27);

        // Total assets = 100 (swap) + 150 (credit at new rate) = 250
        // convertToShares = totalShares / totalAssets = 225/250
        uint256 expectedConversionRate = uint256(225) * 1e18 / 250;

        assertEq(groveBasin.convertToShares(1e18), expectedConversionRate);

        vm.startPrank(lp);

        creditToken.mint(lp, 100e18);
        creditToken.approve(address(groveBasin), 100e18);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 100e18);

        assertEq(creditToken.balanceOf(lp),               100e18);
        assertEq(creditToken.balanceOf(address(groveBasin)), 100e18);

        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 250e18);
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 0);

        assertEq(groveBasin.totalAssets(), 250e18);

        newShares = groveBasin.deposit(address(creditToken), receiver2, 100e18);

        // 150e18 value * 225e18 / 250e18 = 135e18
        uint256 expectedShares = uint256(150e18) * 225e18 / 250e18;
        assertEq(newShares, expectedShares);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 0);

        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), 200e18);

        assertEq(groveBasin.totalShares(),     225e18 + expectedShares);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), 225e18);
        assertEq(groveBasin.shares(receiver2), expectedShares);

        // Receiver 1 earned $25 on 225, Receiver 2 has earned nothing
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), 250e18);
        assertEq(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), 150e18);

        assertEq(groveBasin.totalAssets(), 400e18);
    }

    function testFuzz_deposit_multiDeposit_changeConversionRate(
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

        uint256 depositValue1 = swapTokenAmount * 1e12 + creditTokenAmount1 * 125/100;

        swapToken.mint(lp, swapTokenAmount);

        vm.startPrank(lp);

        swapToken.approve(address(groveBasin), swapTokenAmount);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, swapTokenAmount);

        assertEq(newShares, swapTokenAmount * 1e12);

        creditToken.mint(lp, creditTokenAmount1);
        creditToken.approve(address(groveBasin), creditTokenAmount1);

        newShares = groveBasin.deposit(address(creditToken), receiver1, creditTokenAmount1);

        assertEq(newShares, creditTokenAmount1 * 125/100);

        vm.stopPrank();

        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount1);

        uint256 receiver1Shares = depositValue1;

        assertEq(groveBasin.totalShares(),     receiver1Shares);
        assertEq(groveBasin.shares(lp),        0);
        assertEq(groveBasin.shares(receiver1), receiver1Shares);

        mockCreditTokenRateProvider.__setConversionRate(newRate);

        vm.startPrank(lp);

        creditToken.mint(lp, creditTokenAmount2);
        creditToken.approve(address(groveBasin), creditTokenAmount2);

        assertEq(creditToken.allowance(lp, address(groveBasin)), creditTokenAmount2);
    
        assertEq(creditToken.balanceOf(lp),               creditTokenAmount2);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount1);

        uint256 totalValue = depositValue1 + creditTokenAmount1 * (newRate - 1.25e27) / 1e27;

        assertApproxEqAbs(groveBasin.totalAssets(), totalValue, 1);

        // Skip fuzz inputs where deposit would produce zero shares (guarded by no-new-shares)
        vm.assume(groveBasin.previewDeposit(address(creditToken), creditTokenAmount2) > 0);

        newShares = groveBasin.deposit(address(creditToken), receiver2, creditTokenAmount2);

        // Using queried values here instead of derived to avoid larger errors getting introduced
        uint256 receiver2Shares
            = (creditTokenAmount2 * newRate / 1e27) * groveBasin.totalShares() / groveBasin.totalAssets();

        assertApproxEqAbs(newShares, receiver2Shares, 2);

        assertEq(creditToken.allowance(lp, address(groveBasin)), 0);
    
        assertEq(creditToken.balanceOf(lp),               0);
        assertEq(creditToken.balanceOf(address(groveBasin)), creditTokenAmount1 + creditTokenAmount2);

        assertEq(groveBasin.shares(lp), 0);

        assertApproxEqAbs(groveBasin.totalShares(),     receiver1Shares + receiver2Shares, 2);
        assertApproxEqAbs(groveBasin.shares(receiver1), receiver1Shares,                   2);
        assertApproxEqAbs(groveBasin.shares(receiver2), receiver2Shares,                   2);

        uint256 receiver2NewValue = creditTokenAmount2 * newRate / 1e27;

        // Rate change of up to 1000x introduces errors
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(receiver1)), totalValue,                     1000);
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(receiver2)), receiver2NewValue,              1000);

        assertApproxEqAbs(groveBasin.totalAssets(), totalValue + receiver2NewValue, 1000);
    }

    function test_deposit_swapToken_pocketDepositFails_tokensRemainInPocket() public {
        swapToken.mint(lp, 100e6);

        vm.mockCallRevert(
            pocket,
            abi.encodeWithSelector(IGroveBasinPocket.depositLiquidity.selector),
            "pocket deposit failed"
        );

        vm.startPrank(lp);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectEmit(true, true, true, true);
        emit IGroveBasin.DepositLiquidityFailed(pocket, address(swapToken), 100e6);

        uint256 newShares = groveBasin.deposit(address(swapToken), receiver1, 100e6);
        vm.stopPrank();

        assertEq(newShares, 100e18);

        assertEq(swapToken.balanceOf(pocket), 100e6);
        assertEq(groveBasin.totalShares(),    100e18);
        assertEq(groveBasin.shares(receiver1), 100e18);
    }

}
