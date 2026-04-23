// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { GroveBasinFactory } from "src/GroveBasinFactory.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinFactoryTests is GroveBasinTestBase {

    GroveBasinFactory public factory;

    uint256 public seedAmount;

    function setUp() public override {
        super.setUp();
        factory    = new GroveBasinFactory();
        seedAmount = 10 ** swapToken.decimals();  // 1e6
    }

    function _mintAndApprove() internal {
        swapToken.mint(address(this), seedAmount);
        swapToken.approve(address(factory), seedAmount);
    }

    function _deploy() internal returns (address) {
        _mintAndApprove();
        return factory.deploy(
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

    function test_deploy() public {
        address newBasin = _deploy();

        GroveBasin basin = GroveBasin(newBasin);

        assertTrue(basin.hasRole(basin.OWNER_ROLE(), owner));
        assertEq(basin.liquidityProvider(), lp);

        assertEq(basin.swapToken(),                   address(swapToken));
        assertEq(basin.collateralToken(),             address(collateralToken));
        assertEq(basin.creditToken(),                 address(creditToken));
        assertEq(address(basin.swapTokenRateProvider()),       address(swapTokenRateProvider));
        assertEq(address(basin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(basin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(basin.totalShares(),      1e18);
        assertEq(basin.shares(address(0)), 1e18);

        assertEq(swapToken.balanceOf(newBasin),         seedAmount);
        assertEq(swapToken.balanceOf(address(factory)), 0);
    }

    function test_deploy_emitsEvent() public {
        _mintAndApprove();

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

    function test_deploy_insufficientSwapTokenBalance() public {
        swapToken.approve(address(factory), seedAmount);

        vm.expectRevert();
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

    function test_deploy_noApproval() public {
        swapToken.mint(address(this), seedAmount);

        vm.expectRevert();
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

    function test_deploy_sharesGoToLp() public {
        address newBasin = _deploy();

        GroveBasin basin = GroveBasin(newBasin);

        assertEq(basin.shares(address(0)),        1e18);
        assertEq(basin.shares(lp),               0);
        assertEq(basin.shares(address(this)),     0);
        assertEq(basin.shares(address(factory)),  0);
        assertEq(basin.shares(owner),             0);
    }

    function test_deploy_liquidityProviderIsSet() public {
        address newBasin = _deploy();

        GroveBasin basin = GroveBasin(newBasin);

        assertEq(basin.liquidityProvider(), lp);
    }

    function test_deploy_multipleDeployments() public {
        address basin1 = _deploy();

        _mintAndApprove();
        address basin2 = factory.deploy(
            bytes32(uint256(1)),
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

        assertEq(GroveBasin(basin1).totalShares(),      1e18);
        assertEq(GroveBasin(basin2).totalShares(),      1e18);
        assertEq(GroveBasin(basin1).shares(address(0)), 1e18);
        assertEq(GroveBasin(basin2).shares(address(0)), 1e18);
    }

    function test_deploy_sameSaltReverts() public {
        _deploy();
        _mintAndApprove();

        vm.expectRevert();
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

}
