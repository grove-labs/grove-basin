// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinDeployTests is GroveBasinTestBase {

    function test_deploy() public {
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

        assertTrue(newGroveBasin.hasRole(newGroveBasin.OWNER_ROLE(), owner));
        assertEq(newGroveBasin.liquidityProvider(), lp);
        
        assertEq(newGroveBasin.OWNER_ROLE(), newGroveBasin.DEFAULT_ADMIN_ROLE());

        assertEq(newGroveBasin.swapToken(),                   address(swapToken));
        assertEq(newGroveBasin.collateralToken(),             address(collateralToken));
        assertEq(newGroveBasin.creditToken(),                 address(creditToken));
        assertEq(address(newGroveBasin.swapTokenRateProvider()),       address(swapTokenRateProvider));
        assertEq(address(newGroveBasin.collateralTokenRateProvider()), address(collateralTokenRateProvider));
        assertEq(address(newGroveBasin.creditTokenRateProvider()),     address(creditTokenRateProvider));

        assertEq(swapToken.balanceOf(address(newGroveBasin)), 0);

        assertEq(newGroveBasin.totalAssets(),      0);
        assertEq(newGroveBasin.totalShares(),      0);
        assertEq(newGroveBasin.shares(address(0)), 0);
    }

}
