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
    /*** PAUSED_DEPOSIT_CREDIT                                                                  ***/
    /**********************************************************************************************/

    function _pauseDepositCredit() internal {
        bytes32 pauserRole = groveBasin.PAUSER_ROLE();
        bytes4  key        = groveBasin.PAUSED_DEPOSIT_CREDIT();

        vm.startPrank(owner);
        groveBasin.grantRole(pauserRole, owner);
        groveBasin.setPaused(key, true);
        vm.stopPrank();
    }

    function test_deposit_creditToken_paused() public {
        _pauseDepositCredit();

        creditToken.mint(lp, 100e18);
        vm.startPrank(lp);
        creditToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.deposit(address(creditToken), lp, 100e18);
        vm.stopPrank();
    }

    function test_previewDeposit_creditToken_paused() public {
        _pauseDepositCredit();

        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.previewDeposit(address(creditToken), 100e18);
    }

    function test_previewDeposit_swapToken_whenCreditDepositPaused() public {
        _pauseDepositCredit();

        uint256 shares = groveBasin.previewDeposit(address(swapToken), 100e6);
        assertEq(shares, 100e18);
    }

    function test_previewDeposit_collateralToken_whenCreditDepositPaused() public {
        _pauseDepositCredit();

        uint256 shares = groveBasin.previewDeposit(address(collateralToken), 100e18);
        assertEq(shares, 100e18);
    }

    function test_deposit_swapToken_whenCreditDepositPaused() public {
        _pauseDepositCredit();

        swapToken.mint(lp, 100e6);
        vm.startPrank(lp);
        swapToken.approve(address(groveBasin), 100e6);
        uint256 shares = groveBasin.deposit(address(swapToken), lp, 100e6);
        vm.stopPrank();

        assertEq(shares, 100e18);
    }

    function test_deposit_collateralToken_whenCreditDepositPaused() public {
        _pauseDepositCredit();

        collateralToken.mint(lp, 100e18);
        vm.startPrank(lp);
        collateralToken.approve(address(groveBasin), 100e18);
        uint256 shares = groveBasin.deposit(address(collateralToken), lp, 100e18);
        vm.stopPrank();

        assertEq(shares, 100e18);
    }

    function test_deposit_creditToken_unpaused() public {
        bytes4 key = groveBasin.PAUSED_DEPOSIT_CREDIT();

        _pauseDepositCredit();

        vm.prank(owner);
        groveBasin.setPaused(key, false);

        creditToken.mint(lp, 100e18);
        vm.startPrank(lp);
        creditToken.approve(address(groveBasin), 100e18);
        uint256 shares = groveBasin.deposit(address(creditToken), lp, 100e18);
        vm.stopPrank();

        assertEq(shares, 125e18);
    }

}
