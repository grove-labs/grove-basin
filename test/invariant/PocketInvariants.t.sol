// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }       from "src/GroveBasin.sol";
import { UsdsUsdcPocket }   from "src/UsdsUsdcPocket.sol";
import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockPSM }          from "test/mocks/MockPSM.sol";

import { LpHandler }      from "test/invariant/handlers/LpHandler.sol";
import { SwapperHandler } from "test/invariant/handlers/SwapperHandler.sol";

contract PocketInvariantTest is Test {

    address public owner = makeAddr("owner");
    address BURN_ADDRESS   = address(0);

    GroveBasin     public groveBasin;
    UsdsUsdcPocket public pocket;

    MockERC20 public swapToken;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockERC20 public usds;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockPSM public psm;

    LpHandler      public lpHandler;
    SwapperHandler public swapperHandler;

    function setUp() public {
        swapToken       = new MockERC20("swapToken",       "swapToken",       6);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);

        usds = new MockERC20("USDS", "USDS", 18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        psm = new MockPSM(address(usds), address(swapToken));

        usds.mint(address(psm), type(uint128).max);
        swapToken.mint(address(psm), type(uint128).max);

        pocket = new UsdsUsdcPocket(
            address(groveBasin),
            address(swapToken),
            address(usds),
            address(psm)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();

        // Seed pool with initial deposit (1e18 of value)
        collateralToken.mint(address(this), 1e18);
        collateralToken.approve(address(groveBasin), 1e18);
        groveBasin.deposit(address(collateralToken), BURN_ADDRESS, 1e18);

        lpHandler      = new LpHandler(groveBasin, swapToken, collateralToken, creditToken, 3);
        swapperHandler = new SwapperHandler(groveBasin, swapToken, collateralToken, creditToken, 3);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));

        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
    }

    // Total shares == sum of all individual shares
    function invariant_A_totalSharesEquality() public view {
        uint256 lpShares = groveBasin.shares(BURN_ADDRESS);

        for (uint256 i = 0; i < 3; i++) {
            lpShares += groveBasin.shares(lpHandler.lps(i));
        }

        assertEq(lpShares, groveBasin.totalShares());
    }

    // Total assets ~= asset value of total shares
    function invariant_B_totalAssetsConsistency() public view {
        assertApproxEqAbs(
            groveBasin.totalAssets(),
            groveBasin.convertToAssetValue(groveBasin.totalShares()),
            4
        );
    }

    // Sum of individual LP asset values ~= total assets
    function invariant_C_lpValueSumsToTotal() public view {
        uint256 lpAssetValue = groveBasin.convertToAssetValue(groveBasin.shares(BURN_ADDRESS));

        for (uint256 i = 0; i < 3; i++) {
            lpAssetValue += groveBasin.convertToAssetValue(groveBasin.shares(lpHandler.lps(i)));
        }

        assertApproxEqAbs(lpAssetValue, groveBasin.totalAssets(), 4);
    }

    // Pocket is always the UsdsUsdcPocket
    function invariant_D_pocketIsSet() public view {
        assertEq(groveBasin.pocket(), address(pocket));
    }

}
