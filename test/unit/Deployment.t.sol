// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinDeployTests is GroveBasinTestBase {

    function test_deploy() public {
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

        assertTrue(newGroveBasin.hasRole(newGroveBasin.DEFAULT_ADMIN_ROLE(), owner));
        
        assertEq(address(newGroveBasin.swapToken()),              address(swapToken));
        assertEq(address(newGroveBasin.collateralToken()),             address(collateralToken));
        assertEq(address(newGroveBasin.creditToken()),                 address(creditToken));
        assertEq(address(newGroveBasin.swapTokenRateProvider()),  address(swapTokenRateProvider));
        assertEq(address(newGroveBasin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(newGroveBasin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(swapToken.allowance(address(this), address(newGroveBasin)), 0);

        assertEq(swapToken.balanceOf(address(this)),   0);
        assertEq(swapToken.balanceOf(address(newGroveBasin)), 1e6);

        assertEq(newGroveBasin.totalAssets(),         1e18);
        assertEq(newGroveBasin.totalShares(),         1e18);
        assertEq(newGroveBasin.shares(address(this)), 0);
        assertEq(newGroveBasin.shares(address(0)),    1e18);
    }

}
