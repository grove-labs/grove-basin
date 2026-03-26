// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

abstract contract ForkTestBase is Test {

    address public owner  = makeAddr("owner");
    address public lp     = makeAddr("liquidityProvider");
    address public pocket;

    GroveBasin public groveBasin;

    IERC20 public swapToken;
    IERC20 public collateralToken;
    IERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        _initTokens();
        _initRateProviders();

        groveBasin = new GroveBasin(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);
        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        if (pocket != address(0)) {
            groveBasin.setPocket(pocket);
        } else {
            pocket = address(groveBasin);
        }
        vm.stopPrank();

        if (pocket != address(groveBasin)) {
            vm.prank(pocket);
            swapToken.approve(address(groveBasin), type(uint256).max);
        }

        _postDeploy();

        vm.label(address(swapToken),        "swapToken");
        vm.label(address(collateralToken),  "collateralToken");
        vm.label(address(creditToken),      "creditToken");
        vm.label(address(groveBasin),       "groveBasin");
    }

    /**********************************************************************************************/
    /*** Abstract hooks for subclasses                                                          ***/
    /**********************************************************************************************/

    function _initTokens() internal virtual;

    function _initRateProviders() internal virtual;

    // Called after GroveBasin is deployed and configured. Use for allowlisting, etc.
    function _postDeploy() internal virtual {}

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _dealToken(address token, address to, uint256 amount) internal virtual {
        deal(token, to, amount);
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        _deposit(asset, user, user, amount);
    }

    function _deposit(address asset, address user, address receiver, uint256 amount) internal {
        address lp_ = groveBasin.liquidityProvider();
        _dealToken(asset, lp_, amount);
        vm.startPrank(lp_);
        IERC20(asset).approve(address(groveBasin), amount);
        groveBasin.deposit(asset, receiver, amount);
        vm.stopPrank();
    }

    function _withdraw(address asset, address user, uint256 amount) internal {
        _withdraw(asset, user, user, amount);
    }

    function _withdraw(address asset, address user, address receiver, uint256 amount) internal {
        vm.prank(user);
        groveBasin.withdraw(asset, receiver, amount);
    }

    function _getBlock() internal virtual view returns (uint256) {
        return 24_522_338; // Feb 23, 2026
    }
}
