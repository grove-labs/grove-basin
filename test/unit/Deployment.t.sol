// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract PSMDeployTests is GroveBasinTestBase {

    function test_deploy() public {
        deal(address(usdc), address(this), 1e6);

        GroveBasin newPsm = GroveBasin(GroveBasinDeploy.deploy(
            address(owner),
            address(usdc),
            address(usds),
            address(creditToken),
            address(creditTokenRateProvider)
        ));

        assertEq(address(newPsm.owner()),        address(owner));
        assertEq(address(newPsm.usdc()),         address(usdc));
        assertEq(address(newPsm.usds()),         address(usds));
        assertEq(address(newPsm.creditToken()),        address(creditToken));
        assertEq(address(newPsm.creditTokenRateProvider()), address(creditTokenRateProvider));

        assertEq(usdc.allowance(address(this), address(newPsm)), 0);

        assertEq(usdc.balanceOf(address(this)),   0);
        assertEq(usdc.balanceOf(address(newPsm)), 1e6);

        assertEq(newPsm.totalAssets(),         1e18);
        assertEq(newPsm.totalShares(),         1e18);
        assertEq(newPsm.shares(address(this)), 0);
        assertEq(newPsm.shares(address(0)),    1e18);
    }

}
