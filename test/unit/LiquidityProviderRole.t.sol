// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinLiquidityProviderRoleTests is GroveBasinTestBase {

    address notLp = makeAddr("notLp");

    /**********************************************************************************************/
    /*** liquidityProvider gating                                                               ***/
    /**********************************************************************************************/

    function test_deposit_notLiquidityProvider() public {
        collateralToken.mint(notLp, 100e18);
        vm.startPrank(notLp);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(IGroveBasin.NotLiquidityProvider.selector);
        groveBasin.deposit(address(collateralToken), notLp, 100e18);
        vm.stopPrank();
    }

    function test_deposit_asLiquidityProvider() public {
        collateralToken.mint(lp, 100e18);
        vm.startPrank(lp);
        collateralToken.approve(address(groveBasin), 100e18);
        uint256 shares = groveBasin.deposit(address(collateralToken), lp, 100e18);
        vm.stopPrank();

        assertEq(shares, 100e18);
    }

    /**********************************************************************************************/
    /*** creditTokenDepositsDisabled                                                            ***/
    /**********************************************************************************************/

    function test_setCreditTokenDepositsDisabled_notManagerAdmin() public {
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();
        vm.prank(notLp);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                notLp,
                managerAdminRole
            )
        );
        groveBasin.setCreditTokenDepositsDisabled(true);
    }

    function test_setCreditTokenDepositsDisabled() public {
        assertFalse(groveBasin.creditTokenDepositsDisabled());

        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        assertTrue(groveBasin.creditTokenDepositsDisabled());

        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(false);

        assertFalse(groveBasin.creditTokenDepositsDisabled());
    }

    function test_deposit_creditToken_disabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        creditToken.mint(lp, 100e18);
        vm.startPrank(lp);
        creditToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(IGroveBasin.CreditDepositsDisabled.selector);
        groveBasin.deposit(address(creditToken), lp, 100e18);
        vm.stopPrank();
    }

    function test_previewDeposit_creditToken_disabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        vm.expectRevert(IGroveBasin.CreditDepositsDisabled.selector);
        groveBasin.previewDeposit(address(creditToken), 100e18);
    }

    function test_previewDeposit_swapToken_whenCreditTokenDisabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        uint256 shares = groveBasin.previewDeposit(address(swapToken), 100e6);
        assertEq(shares, 100e18);
    }

    function test_previewDeposit_collateralToken_whenCreditTokenDisabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        uint256 shares = groveBasin.previewDeposit(address(collateralToken), 100e18);
        assertEq(shares, 100e18);
    }

    function test_deposit_swapToken_whenCreditTokenDisabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        swapToken.mint(lp, 100e6);
        vm.startPrank(lp);
        swapToken.approve(address(groveBasin), 100e6);
        uint256 shares = groveBasin.deposit(address(swapToken), lp, 100e6);
        vm.stopPrank();

        assertEq(shares, 100e18);
    }

    function test_deposit_collateralToken_whenCreditTokenDisabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        collateralToken.mint(lp, 100e18);
        vm.startPrank(lp);
        collateralToken.approve(address(groveBasin), 100e18);
        uint256 shares = groveBasin.deposit(address(collateralToken), lp, 100e18);
        vm.stopPrank();

        assertEq(shares, 100e18);
    }

    function test_deposit_creditToken_reenabled() public {
        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(true);

        vm.prank(owner);
        groveBasin.setCreditTokenDepositsDisabled(false);

        creditToken.mint(lp, 100e18);
        vm.startPrank(lp);
        creditToken.approve(address(groveBasin), 100e18);
        uint256 shares = groveBasin.deposit(address(creditToken), lp, 100e18);
        vm.stopPrank();

        assertEq(shares, 125e18);
    }

}
