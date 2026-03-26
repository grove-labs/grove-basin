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
        uint256 seedAmount = 10 ** swapToken.decimals();

        deal(address(swapToken), address(this), seedAmount);
        swapToken.approve(address(factory), seedAmount);

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

        assertEq(basin.swapToken(),                   address(swapToken));
        assertEq(basin.collateralToken(),             address(collateralToken));
        assertEq(basin.creditToken(),                 address(creditToken));
        assertEq(address(basin.swapTokenRateProvider()),       address(swapTokenRateProvider));
        assertEq(address(basin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(basin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(basin.totalShares(),      1e18);
        assertEq(basin.shares(address(0)), 1e18);
        assertEq(basin.totalAssets(),       1e18);

        assertEq(swapToken.balanceOf(newBasin),         seedAmount);
        assertEq(swapToken.balanceOf(address(this)),    0);
        assertEq(swapToken.balanceOf(address(factory)), 0);
    }

    function test_deploy_emitsEvent() public {
        uint256 seedAmount = 10 ** swapToken.decimals();

        deal(address(swapToken), address(this), seedAmount);
        swapToken.approve(address(factory), seedAmount);

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
        uint256 seedAmount = 10 ** swapToken.decimals();

        swapToken.approve(address(factory), seedAmount);

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
        uint256 seedAmount = 10 ** swapToken.decimals();

        deal(address(swapToken), address(this), seedAmount);

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
        uint256 seedAmount = 10 ** swapToken.decimals();

        deal(address(swapToken), address(this), seedAmount);
        swapToken.approve(address(factory), seedAmount);

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
        uint256 seedAmount = 10 ** swapToken.decimals();

        deal(address(swapToken), address(this), seedAmount);
        swapToken.approve(address(factory), seedAmount);

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
        uint256 seedAmount = 10 ** swapToken.decimals();

        deal(address(swapToken), address(this), seedAmount * 2);
        swapToken.approve(address(factory), seedAmount * 2);

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
