// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract ConstructorSeedDepositTests is GroveBasinTestBase {

    function test_constructor_grantsLpRoleToDeployer() public {
        deal(address(swapToken), address(this), 1e6);

        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        assertTrue(newGroveBasin.hasRole(newGroveBasin.LIQUIDITY_PROVIDER_ROLE(), address(this)));
    }

    function test_constructor_lpRoleAdminIsOwner() public {
        deal(address(swapToken), address(this), 1e6);

        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        bytes32 lpRole    = newGroveBasin.LIQUIDITY_PROVIDER_ROLE();
        bytes32 adminRole = newGroveBasin.getRoleAdmin(lpRole);

        assertEq(adminRole, newGroveBasin.MANAGER_ADMIN_ROLE());
    }

    function test_deploy_seedShareDeposit() public {
        deal(address(swapToken), address(this), 1e6);

        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        assertEq(newGroveBasin.totalShares(),      1e18);
        assertEq(newGroveBasin.shares(address(0)), 1e18);
        assertEq(newGroveBasin.totalAssets(),      1e18);

        assertEq(swapToken.balanceOf(address(newGroveBasin)), 1e6);
        assertEq(swapToken.balanceOf(address(this)),          0);
    }

    function test_deploy_seedShareDeposit_permanentlyLocked() public {
        deal(address(swapToken), address(this), 1e6);

        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        // Seed shares belong to address(0), permanently locked
        assertEq(newGroveBasin.shares(address(0)), 1e18);

        // No one else holds the seed shares
        assertEq(newGroveBasin.shares(address(this)), 0);
        assertEq(newGroveBasin.shares(owner),         0);
    }

    function test_deploy_depositAfterSeed() public {
        deal(address(swapToken), address(this), 1e6);

        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        ));

        // Deployer has LP role, can deposit more
        swapToken.mint(address(this), 10e6);
        swapToken.approve(address(newGroveBasin), 10e6);

        uint256 newShares = newGroveBasin.deposit(address(swapToken), address(this), 10e6);

        assertEq(newShares, 10e18);
        assertEq(newGroveBasin.totalShares(),         11e18);
        assertEq(newGroveBasin.shares(address(this)), 10e18);
        assertEq(newGroveBasin.shares(address(0)),    1e18);
    }

}
