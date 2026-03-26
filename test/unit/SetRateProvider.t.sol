// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockRateProvider }  from "test/mocks/MockRateProvider.sol";

contract GroveBasinSetRateProviderFailureTests is GroveBasinTestBase {

    function test_setRateProvider_unauthorized() public {
        address newProvider = address(new MockRateProvider());
        MockRateProvider(newProvider).__setConversionRate(1e27);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        groveBasin.setRateProvider(address(swapToken), newProvider);
    }

    function test_setRateProvider_invalidRateProvider() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidRateProvider.selector);
        groveBasin.setRateProvider(address(swapToken), address(0));
    }

    function test_setRateProvider_rateProviderReturnsZero() public {
        address newProvider = address(new MockRateProvider());

        vm.prank(owner);
        vm.expectRevert(IGroveBasin.RateProviderReturnsZero.selector);
        groveBasin.setRateProvider(address(swapToken), newProvider);
    }

    function test_setRateProvider_invalidToken() public {
        address newProvider = address(new MockRateProvider());
        MockRateProvider(newProvider).__setConversionRate(1e27);

        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidToken.selector);
        groveBasin.setRateProvider(makeAddr("random"), newProvider);
    }

}

contract GroveBasinSetRateProviderSuccessTests is GroveBasinTestBase {

    event RateProviderSet(address indexed token, address indexed oldRateProvider, address indexed newRateProvider);

    function test_setRateProvider_swapToken() public {
        address oldProvider          = groveBasin.swapTokenRateProvider();
        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(1e27);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit RateProviderSet(address(swapToken), oldProvider, address(newProvider));
        groveBasin.setRateProvider(address(swapToken), address(newProvider));

        assertEq(groveBasin.swapTokenRateProvider(), address(newProvider));
    }

    function test_setRateProvider_collateralToken() public {
        address oldProvider          = groveBasin.collateralTokenRateProvider();
        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(1e27);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit RateProviderSet(address(collateralToken), oldProvider, address(newProvider));
        groveBasin.setRateProvider(address(collateralToken), address(newProvider));

        assertEq(groveBasin.collateralTokenRateProvider(), address(newProvider));
    }

    function test_setRateProvider_creditToken() public {
        address oldProvider       = groveBasin.creditTokenRateProvider();
        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(1.25e27);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit RateProviderSet(address(creditToken), oldProvider, address(newProvider));
        groveBasin.setRateProvider(address(creditToken), address(newProvider));

        assertEq(groveBasin.creditTokenRateProvider(), address(newProvider));
    }

    function test_setRateProvider_functionalAfterUpdate() public {
        _deposit(address(swapToken), makeAddr("depositor"), 1000e6);

        MockRateProvider newProvider = new MockRateProvider();
        newProvider.__setConversionRate(2e27);

        vm.prank(owner);
        groveBasin.setRateProvider(address(creditToken), address(newProvider));

        assertEq(groveBasin.creditTokenRateProvider(), address(newProvider));

        uint256 totalAssets = groveBasin.totalAssets();
        assertGt(totalAssets, 0);
    }

}
