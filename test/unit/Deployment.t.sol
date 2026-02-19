// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinDeployTests is GroveBasinTestBase {

    function test_deploy() public {
        deal(address(secondaryToken), address(this), 1e6);

        GroveBasin newGroveBasin = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(secondaryToken),
            address(collateralToken),
            address(creditToken),
            address(creditTokenRateProvider)
        ));

        assertEq(address(newGroveBasin.owner()),                   address(owner));
        assertEq(address(newGroveBasin.secondaryToken()),                    address(secondaryToken));
        assertEq(address(newGroveBasin.collateralToken()),         address(collateralToken));
        assertEq(address(newGroveBasin.creditToken()),             address(creditToken));
        assertEq(address(newGroveBasin.creditTokenRateProvider()), address(creditTokenRateProvider));

        assertEq(secondaryToken.allowance(address(this), address(newGroveBasin)), 0);

        assertEq(secondaryToken.balanceOf(address(this)),   0);
        assertEq(secondaryToken.balanceOf(address(newGroveBasin)), 1e6);

        assertEq(newGroveBasin.totalAssets(),         1e18);
        assertEq(newGroveBasin.totalShares(),         1e18);
        assertEq(newGroveBasin.shares(address(this)), 0);
        assertEq(newGroveBasin.shares(address(0)),    1e18);
    }

}
