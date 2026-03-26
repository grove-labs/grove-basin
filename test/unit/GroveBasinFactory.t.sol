// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { GroveBasinFactory } from "src/GroveBasinFactory.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinFactoryTests is GroveBasinTestBase {

    GroveBasinFactory public factory;

    function setUp() public override {
        super.setUp();
        factory = new GroveBasinFactory();
    }

    function test_deploy() public {
        address newBasin = factory.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin basin = GroveBasin(newBasin);

        assertTrue(basin.hasRole(basin.OWNER_ROLE(), owner));
        assertEq(basin.liquidityProvider(), lp);

        assertEq(basin.swapToken(),                   address(swapToken));
        assertEq(basin.collateralToken(),             address(collateralToken));
        assertEq(basin.creditToken(),                 address(creditToken));
        assertEq(address(basin.swapTokenRateProvider()),       address(swapTokenRateProvider));
        assertEq(address(basin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(basin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(basin.totalShares(),      0);
        assertEq(basin.shares(address(0)), 0);
        assertEq(basin.totalAssets(),       0);

        assertEq(swapToken.balanceOf(newBasin), 0);
    }

    function test_deploy_emitsEvent() public {
        vm.expectEmit(false, true, false, true);
        emit GroveBasinFactory.GroveBasinDeployed(
            address(0),
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken)
        );

        factory.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );
    }

    function test_deploy_noSharesAfterDeploy() public {
        address newBasin = factory.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin basin = GroveBasin(newBasin);

        assertEq(basin.shares(address(0)),        0);
        assertEq(basin.shares(address(this)),     0);
        assertEq(basin.shares(address(factory)),  0);
        assertEq(basin.shares(owner),             0);
    }

    function test_deploy_liquidityProviderIsSet() public {
        address newBasin = factory.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin basin = GroveBasin(newBasin);

        assertEq(basin.liquidityProvider(), lp);
    }

    function test_deploy_multipleDeployments() public {
        address basin1 = factory.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        address basin2 = factory.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertTrue(basin1 != basin2);

        assertEq(GroveBasin(basin1).totalShares(), 0);
        assertEq(GroveBasin(basin2).totalShares(), 0);
    }

}
