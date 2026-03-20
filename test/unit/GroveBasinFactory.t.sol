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
        deal(address(swapToken), address(this), 1e6);
        swapToken.approve(address(factory), 1e6);

        address newBasin = factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin basin = GroveBasin(newBasin);

        assertTrue(basin.hasRole(basin.OWNER_ROLE(), owner));

        assertEq(address(basin.swapToken()),                   address(swapToken));
        assertEq(address(basin.collateralToken()),             address(collateralToken));
        assertEq(address(basin.creditToken()),                 address(creditToken));
        assertEq(address(basin.swapTokenRateProvider()),       address(swapTokenRateProvider));
        assertEq(address(basin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(basin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(basin.totalShares(),      1e18);
        assertEq(basin.shares(address(0)), 1e18);
        assertEq(basin.totalAssets(),       1e18);

        assertEq(swapToken.balanceOf(newBasin),       1e6);
        assertEq(swapToken.balanceOf(address(this)),   0);
        assertEq(swapToken.balanceOf(address(factory)), 0);
    }

    function test_deploy_emitsEvent() public {
        deal(address(swapToken), address(this), 1e6);
        swapToken.approve(address(factory), 1e6);

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
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );
    }

    function test_deploy_insufficientSwapTokenBalance() public {
        swapToken.approve(address(factory), 1e6);

        vm.expectRevert();
        factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );
    }

    function test_deploy_noApproval() public {
        deal(address(swapToken), address(this), 1e6);

        vm.expectRevert();
        factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );
    }

    function test_deploy_seedSharesPermanentlyLocked() public {
        deal(address(swapToken), address(this), 1e6);
        swapToken.approve(address(factory), 1e6);

        address newBasin = factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin basin = GroveBasin(newBasin);

        assertEq(basin.shares(address(0)),        1e18);
        assertEq(basin.shares(address(this)),     0);
        assertEq(basin.shares(address(factory)),  0);
        assertEq(basin.shares(owner),             0);
    }

    function test_deploy_callerDoesNotRetainLpRole() public {
        deal(address(swapToken), address(this), 1e6);
        swapToken.approve(address(factory), 1e6);

        address newBasin = factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin basin = GroveBasin(newBasin);

        // The factory gets LP role (as msg.sender to constructor), not the caller
        assertTrue(basin.hasRole(basin.LIQUIDITY_PROVIDER_ROLE(), address(factory)));
        assertFalse(basin.hasRole(basin.LIQUIDITY_PROVIDER_ROLE(), address(this)));
    }

    function test_deploy_multipleDeployments() public {
        deal(address(swapToken), address(this), 2e6);
        swapToken.approve(address(factory), 2e6);

        address basin1 = factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        address basin2 = factory.deploy(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertTrue(basin1 != basin2);

        assertEq(GroveBasin(basin1).totalShares(), 1e18);
        assertEq(GroveBasin(basin2).totalShares(), 1e18);
    }

}
