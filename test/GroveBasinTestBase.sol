// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract GroveBasinTestBase is Test {

    address public owner  = makeAddr("owner");
    address public pocket = makeAddr("pocket");

    GroveBasin public groveBasin;

    MockERC20 public swapToken;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    IRateProviderLike public swapTokenRateProvider;     // Can be overridden using same interface
    IRateProviderLike public collateralTokenRateProvider;  // Can be overridden using same interface
    IRateProviderLike public creditTokenRateProvider;      // Can be overridden by ssrOracle using same interface

    MockRateProvider public mockSwapTokenRateProvider;   // Interface used for mocking
    MockRateProvider public mockCollateralTokenRateProvider;  // Interface used for mocking
    MockRateProvider public mockCreditTokenRateProvider;      // Interface used for mocking

    modifier assertAtomicGroveBasinValueDoesNotChange {
        uint256 beforeValue = _getGroveBasinValue();
        _;
        assertEq(_getGroveBasinValue(), beforeValue);
    }

    // 1,000,000,000,000 of each token
    uint256 public constant COLLATERAL_TOKEN_MAX = 1e30;
    uint256 public constant CREDIT_TOKEN_MAX     = 1e30;
    uint256 public constant SWAP_TOKEN_MAX  = 1e18;

    function setUp() public virtual {
        swapToken  = new MockERC20("swapToken",  "swapToken",  6);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);

        mockSwapTokenRateProvider  = new MockRateProvider();
        mockCollateralTokenRateProvider = new MockRateProvider();
        mockCreditTokenRateProvider     = new MockRateProvider();

        // Swap token (USDC) is priced at $1 by default
        mockSwapTokenRateProvider.__setConversionRate(1e27);

        // Collateral token is priced at $1 by default
        mockCollateralTokenRateProvider.__setConversionRate(1e27);

        // NOTE: Using 1.25 for easy two way conversions
        mockCreditTokenRateProvider.__setConversionRate(1.25e27);

        swapTokenRateProvider  = IRateProviderLike(address(mockSwapTokenRateProvider));
        collateralTokenRateProvider = IRateProviderLike(address(mockCollateralTokenRateProvider));
        creditTokenRateProvider     = IRateProviderLike(address(mockCreditTokenRateProvider));

        groveBasin = new GroveBasin(owner, address(swapToken), address(collateralToken), address(creditToken), address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider));

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(pocket);
        vm.stopPrank();

        vm.prank(pocket);
        swapToken.approve(address(groveBasin), type(uint256).max);

        vm.label(address(swapToken),  "swapToken");
        vm.label(address(collateralToken), "collateralToken");
        vm.label(address(creditToken),     "creditToken");
    }

    function _getGroveBasinValue() internal view returns (uint256) {
        return (creditToken.balanceOf(address(groveBasin)) * creditTokenRateProvider.getConversionRate() / 1e27)
            + (swapToken.balanceOf(groveBasin.pocket()) * swapTokenRateProvider.getConversionRate() / 1e15)
            + (collateralToken.balanceOf(address(groveBasin)) * collateralTokenRateProvider.getConversionRate() / 1e27);
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        _deposit(asset, user, user, amount);
    }

    function _deposit(address asset, address user, address receiver, uint256 amount) internal {
        vm.startPrank(user);
        MockERC20(asset).mint(user, amount);
        MockERC20(asset).approve(address(groveBasin), amount);
        groveBasin.deposit(asset, receiver, amount);
        vm.stopPrank();
    }

    function _withdraw(address asset, address user, uint256 amount) internal {
        _withdraw(asset, user, user, amount);
    }

    function _withdraw(address asset, address user, address receiver, uint256 amount) internal {
        vm.prank(user);
        groveBasin.withdraw(asset, receiver, amount);
        vm.stopPrank();
    }

}
