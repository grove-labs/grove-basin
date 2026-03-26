// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract ConstructorSeedDepositTests is GroveBasinTestBase {

    uint256 public seedAmount;

    function setUp() public override {
        super.setUp();
        seedAmount = 10 ** swapToken.decimals();  // 1e6
    }

    function _deploy() internal returns (GroveBasin) {
        swapToken.mint(address(this), seedAmount);
        return GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));
    }

    function test_constructor_liquidityProviderIsSet() public {
        GroveBasin newGroveBasin = _deploy();
        assertEq(newGroveBasin.liquidityProvider(), lp);
    }

    function test_deploy_seededAfterDeploy() public {
        GroveBasin newGroveBasin = _deploy();

        assertEq(newGroveBasin.totalShares(),      1e18);
        assertEq(newGroveBasin.shares(address(0)), 1e18);

        assertEq(swapToken.balanceOf(address(newGroveBasin)), seedAmount);
    }

    function test_deploy_lpCanDepositAfterSeed() public {
        GroveBasin newGroveBasin = _deploy();

        swapToken.mint(lp, 10e6);
        vm.startPrank(lp);
        swapToken.approve(address(newGroveBasin), 10e6);
        uint256 newShares = newGroveBasin.deposit(address(swapToken), lp, 10e6);
        vm.stopPrank();

        assertEq(newShares, 10e18);
        assertEq(newGroveBasin.totalShares(), 11e18);
        assertEq(newGroveBasin.shares(lp),    10e18);
    }

}
