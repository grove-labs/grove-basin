// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract InflationAttackTests is GroveBasinTestBase {

    address firstDepositor = makeAddr("firstDepositor");
    address frontRunner    = makeAddr("frontRunner");
    address deployer       = makeAddr("deployer");

    function test_inflationAttack_noInitialDeposit_creditToken() public {
        // Step 1: Front runner deposits 1 creditToken to get 1 share

        // Have to use creditToken because 1 USDC mints 1e12 shares
        _deposit(address(creditToken), frontRunner, 1);

        _runInflationAttack_noInitialDepositTest();
    }

    function test_inflationAttack_noInitialDeposit_collateralToken() public {
        // Step 1: Front runner deposits 1 creditToken to get 1 share

        // Have to use collateralToken because 1 USDC mints 1e12 shares
        _deposit(address(collateralToken), frontRunner, 1);

        _runInflationAttack_noInitialDepositTest();
    }

    function test_inflationAttack_useInitialDeposit_creditToken() public {
        _deposit(address(creditToken), address(deployer), 0.8e18);  // 1e18 shares

        // Step 1: Front runner deposits creditToken to get 1 share

        // User tries to do the same attack, depositing one creditToken for 1 share
        _deposit(address(creditToken), frontRunner, 1);

        _runInflationAttack_useInitialDepositTest();
    }

    function test_inflationAttack_useInitialDeposit_collateralToken() public {
        _deposit(address(collateralToken), address(deployer), 1e18);  // 1e18 shares

        // Step 1: Front runner deposits collateralToken to get 1 share

        // User tries to do the same attack, depositing one creditToken for 1 share
        _deposit(address(collateralToken), frontRunner, 1);

        _runInflationAttack_useInitialDepositTest();
    }

    function _runInflationAttack_noInitialDepositTest() internal {
        assertEq(groveBasin.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate to 1:(10m + 1)

        deal(address(secondaryToken), frontRunner, 10_000_000e6);

        assertEq(groveBasin.convertToAssetValue(1), 1);

        vm.prank(frontRunner);
        secondaryToken.transfer(pocket, 10_000_000e6);

        // Highly inflated exchange rate
        assertEq(groveBasin.convertToAssetValue(1), 10_000_000e18 + 1);

        // Step 3: First depositor deposits 20 million USDC, only gets one share because rounding
        //         error gives them 1 instead of 2 shares, worth 15m USDC

        _deposit(address(secondaryToken), firstDepositor, 20_000_000e6);

        assertEq(groveBasin.shares(firstDepositor), 1);

        // 1 share = 3 million USDC / 2 shares = 1.5 million USDC
        assertEq(groveBasin.convertToAssetValue(1), 15_000_000e18);

        // Step 4: Both users withdraw the max amount of funds they can

        _withdraw(address(secondaryToken), firstDepositor, type(uint256).max);
        _withdraw(address(secondaryToken), frontRunner,    type(uint256).max);

        assertEq(secondaryToken.balanceOf(pocket), 0);

        // Front runner profits 5m USDC, first depositor loses 5m USDC
        assertEq(secondaryToken.balanceOf(firstDepositor), 15_000_000e6);
        assertEq(secondaryToken.balanceOf(frontRunner),    15_000_000e6);
    }

    function _runInflationAttack_useInitialDepositTest() internal {
        assertEq(groveBasin.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate to 1:(10m + 1)

        assertEq(groveBasin.convertToAssetValue(1), 1);

        deal(address(secondaryToken), frontRunner, 10_000_000e6);

        vm.prank(frontRunner);
        secondaryToken.transfer(pocket, 10_000_000e6);

        // Still inflated, but all value is transferred to existing holder, deployer
        assertEq(groveBasin.convertToAssetValue(1), 0.00000000001e18);

        // Step 3: First depositor deposits 20 million USDC, this time rounding is not an issue
        //         so value reflected is much more accurate

        _deposit(address(secondaryToken), firstDepositor, 20_000_000e6);

        assertEq(groveBasin.shares(firstDepositor), 1.999999800000020001e18);

        // Higher amount of initial shares means lower rounding error
        assertEq(groveBasin.convertToAssetValue(1.999999800000020001e18), 19_999_999.999999999996673334e18);

        // Step 4: Both users withdraw the max amount of funds they can

        _withdraw(address(secondaryToken), firstDepositor, type(uint256).max);
        _withdraw(address(secondaryToken), frontRunner,    type(uint256).max);
        _withdraw(address(secondaryToken), deployer,       type(uint256).max);

        // Front runner loses full 10m USDC to the deployer that had all shares at the beginning, first depositor loses nothing (1e-6 USDC)
        assertEq(secondaryToken.balanceOf(firstDepositor), 19_999_999.999999e6);
        assertEq(secondaryToken.balanceOf(frontRunner),    0);
        assertEq(secondaryToken.balanceOf(deployer),       10_000_000.000001e6);
    }

}
