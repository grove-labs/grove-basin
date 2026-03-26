// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract GroveBasinDeployForkTest is Test {

    address public owner = makeAddr("owner");

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
        // Get some USDT to this contract to fund the initial deposit
        deal(Ethereum.USDT, address(this), 1e6);

        // Verify initial balance
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(this)), 1e6);

        // Deploy using the library
        address groveBasinAddress = GroveBasinDeploy.deploy(
            owner,
            makeAddr("liquidityProvider"),
            Ethereum.USDT,  // swapToken - actual mainnet USDT
            Ethereum.USDC,  // collateralToken
            Ethereum.USDS,  // creditToken
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        // Verify GroveBasin was deployed
        assertTrue(groveBasinAddress != address(0));

        GroveBasin groveBasin = GroveBasin(groveBasinAddress);

        // Verify initialization worked correctly
        assertEq(groveBasin.swapToken(),       Ethereum.USDT);
        assertEq(groveBasin.collateralToken(), Ethereum.USDC);
        assertEq(groveBasin.creditToken(),     Ethereum.USDS);

        // Verify the safeApprove worked by checking that deposit executed successfully
        // The library does: safeApprove(1e6) then deposit(1e6)
        // This means the deployer's USDT was transferred from this contract
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(this)), 0);

        // The USDT should now be held by the GroveBasin contract
        // (since no pocket is configured during deployment)
        assertEq(IERC20(Ethereum.USDT).balanceOf(groveBasinAddress), 1e6);

        // Verify that totalAssets reflects the deposited value
        // With 1:1 rate, 1e6 USDT (6 decimals) = 1e18 in value (18 decimals)
        assertEq(groveBasin.totalAssets(), 1e18);
    }

    function test_deploy_safeApproveResetsAllowance() public {
        // Get some USDT to this contract
        deal(Ethereum.USDT, address(this), 1e6);

        // First, manually set a non-zero allowance to an arbitrary address
        // This simulates the scenario where USDT's approve might fail
        address dummySpender = makeAddr("dummySpender");
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), dummySpender, 1e6);
        assertEq(IERC20(Ethereum.USDT).allowance(address(this), dummySpender), 1e6);

        // Deploy - this should work even though we're using actual USDT
        // The safeApprove in GroveBasinDeploy should handle USDT's quirks
        address groveBasinAddress = GroveBasinDeploy.deploy(
            owner,
            makeAddr("liquidityProvider"),
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin groveBasin = GroveBasin(groveBasinAddress);

        // Verify the deployment and deposit succeeded
        assertEq(IERC20(Ethereum.USDT).balanceOf(groveBasinAddress), 1e6);
        assertEq(groveBasin.totalAssets(), 1e18);

        // Verify allowance was consumed (should be 0 after deposit)
        assertEq(IERC20(Ethereum.USDT).allowance(address(this), groveBasinAddress), 0);
    }

    function test_deploy_multipleDeployments() public {
        // Test that we can deploy multiple times without approval issues
        deal(Ethereum.USDT, address(this), 10e6);

        // First deployment
        address groveBasin1 = GroveBasinDeploy.deploy(
            owner,
            makeAddr("liquidityProvider"),
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertEq(IERC20(Ethereum.USDT).balanceOf(groveBasin1), 1e6);

        // Second deployment - should work even though we're reusing USDT
        MockRateProvider swapTokenRateProvider2       = new MockRateProvider();
        MockRateProvider collateralTokenRateProvider2 = new MockRateProvider();
        MockRateProvider creditTokenRateProvider2     = new MockRateProvider();

        swapTokenRateProvider2.__setConversionRate(1e27);
        collateralTokenRateProvider2.__setConversionRate(1e27);
        creditTokenRateProvider2.__setConversionRate(1e27);

        address groveBasin2 = GroveBasinDeploy.deploy(
            owner,
            makeAddr("liquidityProvider"),
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider2),
            address(collateralTokenRateProvider2),
            address(creditTokenRateProvider2)
        );

        assertEq(IERC20(Ethereum.USDT).balanceOf(groveBasin2), 1e6);

        // Verify both deployments are independent
        assertTrue(groveBasin1 != groveBasin2);
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(this)), 8e6); // 10 - 1 - 1
    }

    function testFuzz_deploy_variousAmounts(uint256 depositAmount) public {
        // Bound the amount to reasonable values (1e6 minimum needed for deploy, up to 1M USDT)
        depositAmount = bound(depositAmount, 1e6, 1_000_000e6);

        // Give this contract the USDT
        deal(Ethereum.USDT, address(this), depositAmount);

        // Deploy - the library always deposits exactly 1e6
        address groveBasinAddress = GroveBasinDeploy.deploy(
            owner,
            makeAddr("liquidityProvider"),
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        GroveBasin groveBasin = GroveBasin(groveBasinAddress);

        // Verify the 1e6 USDT was deposited
        assertEq(IERC20(Ethereum.USDT).balanceOf(groveBasinAddress), 1e6);
        assertEq(groveBasin.totalAssets(), 1e18);

        // Verify the remaining balance stayed with the test contract
        assertEq(IERC20(Ethereum.USDT).balanceOf(address(this)), depositAmount - 1e6);
    }

}
