// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract GroveBasinDeployForkTest is Test {

    address public owner = makeAddr("owner");
    address public lp    = makeAddr("liquidityProvider");

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 24_522_338);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1e27);
    }

    function test_deploy_withActualUSDT() public {
        address groveBasinAddress = GroveBasinDeploy.deploy(
            owner,
            lp,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertTrue(groveBasinAddress != address(0));

        GroveBasin groveBasin = GroveBasin(groveBasinAddress);

        assertEq(groveBasin.swapToken(),       Ethereum.USDT);
        assertEq(groveBasin.collateralToken(), Ethereum.USDC);
        assertEq(groveBasin.creditToken(),     Ethereum.USDS);
        assertEq(groveBasin.liquidityProvider(),        lp);
        assertEq(groveBasin.totalAssets(),              0);
        assertEq(groveBasin.totalShares(),              0);
    }

    function test_deploy_multipleDeployments() public {
        address groveBasin1 = GroveBasinDeploy.deploy(
            owner,
            lp,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        MockRateProvider swapTokenRateProvider2       = new MockRateProvider();
        MockRateProvider collateralTokenRateProvider2 = new MockRateProvider();
        MockRateProvider creditTokenRateProvider2     = new MockRateProvider();

        swapTokenRateProvider2.__setConversionRate(1e27);
        collateralTokenRateProvider2.__setConversionRate(1e27);
        creditTokenRateProvider2.__setConversionRate(1e27);

        address groveBasin2 = GroveBasinDeploy.deploy(
            owner,
            lp,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider2),
            address(collateralTokenRateProvider2),
            address(creditTokenRateProvider2)
        );

        assertTrue(groveBasin1 != groveBasin2);
        assertEq(GroveBasin(groveBasin1).totalAssets(), 0);
        assertEq(GroveBasin(groveBasin2).totalAssets(), 0);
    }

    function test_deploy_noTokensTransferred() public {
        deal(Ethereum.USDT, address(this), 10e6);

        uint256 balanceBefore = IERC20(Ethereum.USDT).balanceOf(address(this));

        address groveBasinAddress = GroveBasinDeploy.deploy(
            owner,
            lp,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertEq(IERC20(Ethereum.USDT).balanceOf(address(this)),    balanceBefore);
        assertEq(IERC20(Ethereum.USDT).balanceOf(groveBasinAddress), 0);
    }

}
