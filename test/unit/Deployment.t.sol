// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinDeployTests is GroveBasinTestBase {

    function test_deploy() public {
        uint256 seedAmount = 10 ** swapToken.decimals();
        swapToken.mint(address(this), seedAmount);

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

        assertEq(swapToken.balanceOf(address(newGroveBasin)), seedAmount);

        assertEq(newGroveBasin.totalShares(),      1e18);
        assertEq(newGroveBasin.shares(address(0)), 1e18);
    }

}
