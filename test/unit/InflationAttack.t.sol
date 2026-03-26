// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract InflationAttackTests is GroveBasinTestBase {

    address firstDepositor = makeAddr("firstDepositor");
    address frontRunner    = makeAddr("frontRunner");
    address deployer       = makeAddr("deployer");

    function test_inflationAttack_noInitialDeposit_creditToken() public {
        // Front runner deposits 1 creditToken to get 1 share
        _deposit(address(creditToken), frontRunner, 1);

        _runInflationAttack_noInitialDepositTest();
    }

    function test_inflationAttack_noInitialDeposit_collateralToken() public {
        // Front runner deposits 1 collateralToken to get 1 share
        _deposit(address(collateralToken), frontRunner, 1);

        _runInflationAttack_noInitialDepositTest();
    }

    function test_inflationAttack_useInitialDeposit_creditToken() public {
        _deposit(address(creditToken), address(deployer), 0.8e18);  // 1e18 shares

        // Front runner deposits 1 creditToken to get 1 share
        _deposit(address(creditToken), frontRunner, 1);

        _runInflationAttack_mitigatedByDeployerTest();
    }

    function test_inflationAttack_useInitialDeposit_collateralToken() public {
        _deposit(address(collateralToken), address(deployer), 1e18);  // 1e18 shares

        // Front runner deposits 1 collateralToken to get 1 share
        _deposit(address(collateralToken), frontRunner, 1);

        _runInflationAttack_mitigatedByDeployerTest();
    }

    function _runInflationAttack_noInitialDepositTest() internal {
        // Front runner has 1 share, no other deposits exist
        assertEq(groveBasin.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate
        deal(address(swapToken), frontRunner, 10_000_000e6);

        assertEq(groveBasin.convertToAssetValue(1), 1);

        vm.prank(frontRunner);
        swapToken.transfer(pocket, 10_000_000e6);

        // With only 1 share, the front runner's share is now worth the entire pool
        uint256 frontRunnerShareValue = groveBasin.convertToAssetValue(1);
        assertGt(frontRunnerShareValue, 0);

        // Step 3: First depositor deposits 20M USDC
        _deposit(address(swapToken), firstDepositor, 20_000_000e6);

        // First depositor gets shares based on the inflated pool
        uint256 firstDepositorShares = groveBasin.shares(firstDepositor);
        assertGt(firstDepositorShares, 0);

        // Step 4: Both users withdraw the max amount of funds they can
        _withdraw(address(swapToken), firstDepositor, type(uint256).max);
        _withdraw(address(swapToken), frontRunner,    type(uint256).max);

        // Without a seed deposit to dilute the attacker, the inflation attack is
        // partially effective. The first depositor loses value to the front runner.
        // This is mitigated when the deployer makes a sufficiently large initial deposit.
        uint256 firstDepositorBalance = swapToken.balanceOf(firstDepositor);
        uint256 frontRunnerBalance    = swapToken.balanceOf(frontRunner);

        // Both get a share of the pool
        assertGt(firstDepositorBalance, 0);
        assertGt(frontRunnerBalance,    0);

        // Total withdrawn equals total in pool
        assertEq(firstDepositorBalance + frontRunnerBalance, 30_000_000e6);
    }

    function _runInflationAttack_mitigatedByDeployerTest() internal {
        // Front runner has 1 share, deployer has 1e18 shares
        assertEq(groveBasin.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate
        assertEq(groveBasin.convertToAssetValue(1), 1);

        deal(address(swapToken), frontRunner, 10_000_000e6);

        vm.prank(frontRunner);
        swapToken.transfer(pocket, 10_000_000e6);

        // Value is transferred to existing holders (deployer)
        uint256 frontRunnerShareValue = groveBasin.convertToAssetValue(1);
        assertLt(frontRunnerShareValue, 1e18);  // Less than $1

        // Step 3: First depositor deposits 20M USDC - gets accurate shares
        _deposit(address(swapToken), firstDepositor, 20_000_000e6);

        // First depositor gets meaningful shares
        assertGt(groveBasin.shares(firstDepositor), 1e18);

        // Higher amount of initial shares means lower rounding error
        uint256 firstDepositorValue = groveBasin.convertToAssetValue(groveBasin.shares(firstDepositor));
        assertApproxEqRel(firstDepositorValue, 20_000_000e18, 0.0001e18); // Within 0.01%

        // Step 4: All users withdraw
        _withdraw(address(swapToken), firstDepositor, type(uint256).max);
        _withdraw(address(swapToken), frontRunner,    type(uint256).max);
        _withdraw(address(swapToken), deployer,       type(uint256).max);

        // Front runner loses all donated funds to deployer
        assertEq(swapToken.balanceOf(frontRunner), 0);

        // First depositor gets almost all their money back
        assertApproxEqRel(swapToken.balanceOf(firstDepositor), 20_000_000e6, 0.0001e18);

        // Deployer captures a portion of the front runner's donated funds
        assertGt(swapToken.balanceOf(deployer), 0);
    }

}
