// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinLiquidityProviderRoleTests is GroveBasinTestBase {

    address lp    = makeAddr("lp");
    address notLp = makeAddr("notLp");

    function setUp() public override {
        super.setUp();

        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, lp);
    }

    /**********************************************************************************************/
    /*** LIQUIDITY_PROVIDER_ROLE gating                                                         ***/
    /**********************************************************************************************/

    function test_deposit_unauthorized() public {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        collateralToken.mint(notLp, 100e18);
        vm.startPrank(notLp);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                notLp,
                lpRole
            )
        );
        groveBasin.deposit(address(collateralToken), notLp, 100e18);
        vm.stopPrank();
    }

    function test_deposit_authorized() public {
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

    function test_setCreditTokenDepositsDisabled_notOwner() public {
        bytes32 ownerRole = groveBasin.OWNER_ROLE();
        vm.prank(lp);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                lp,
                ownerRole
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

        vm.expectRevert("GroveBasin/creditToken-deposits-disabled");
        groveBasin.deposit(address(creditToken), lp, 100e18);
        vm.stopPrank();
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
