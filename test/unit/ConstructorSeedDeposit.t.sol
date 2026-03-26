// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract ConstructorSeedDepositTests is GroveBasinTestBase {

    function test_constructor_liquidityProviderIsSet() public {
        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        assertEq(newGroveBasin.liquidityProvider(), lp);
    }

    function test_deploy_emptyAfterDeploy() public {
        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        assertEq(newGroveBasin.totalShares(),      0);
        assertEq(newGroveBasin.shares(address(0)), 0);
        assertEq(newGroveBasin.totalAssets(),       0);

        assertEq(swapToken.balanceOf(address(newGroveBasin)), 0);
    }

    function test_deploy_lpCanDeposit() public {
        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        swapToken.mint(lp, 10e6);
        vm.startPrank(lp);
        swapToken.approve(address(newGroveBasin), 10e6);
        uint256 newShares = newGroveBasin.deposit(address(swapToken), lp, 10e6);
        vm.stopPrank();

        assertEq(newShares, 10e18);
        assertEq(newGroveBasin.totalShares(), 10e18);
        assertEq(newGroveBasin.shares(lp),    10e18);
    }

}
