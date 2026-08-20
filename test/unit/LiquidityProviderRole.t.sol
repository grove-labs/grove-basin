// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinLiquidityProviderRoleTests is GroveBasinTestBase {

    address notLp        = makeAddr("notLp");
    address newLp        = makeAddr("newLp");
    address managerAdmin = makeAddr("managerAdmin");
    address manager      = makeAddr("manager");
    address pauser       = makeAddr("pauser");

    bytes32 lpRole;
    bytes32 managerAdminRole;

    function setUp() public override {
        super.setUp();

        lpRole           = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();

        vm.startPrank(owner);
        groveBasin.grantRole(managerAdminRole,          managerAdmin);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(),  pauser);
        vm.stopPrank();
    }

    function _depositAs(address depositor, address asset, address receiver, uint256 amount)
        internal returns (uint256 newShares)
    {
        MockERC20(asset).mint(depositor, amount);

        vm.startPrank(depositor);
        MockERC20(asset).approve(address(groveBasin), amount);
        newShares = groveBasin.deposit(asset, receiver, amount);
        vm.stopPrank();
    }

    function _expectMissingManagerAdminRole(address account) internal {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                account,
                managerAdminRole
            )
        );
    }

    function _expectDepositRejected(address depositor) internal {
        collateralToken.mint(depositor, 100e18);

        vm.startPrank(depositor);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(IGroveBasin.NotLiquidityProvider.selector);
        groveBasin.deposit(address(collateralToken), depositor, 100e18);
        vm.stopPrank();
    }

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
        groveBasin.setPaused(key);
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
        groveBasin.setUnpaused(key);

        creditToken.mint(lp, 100e18);
        vm.startPrank(lp);
        creditToken.approve(address(groveBasin), 100e18);
        uint256 shares = groveBasin.deposit(address(creditToken), lp, 100e18);
        vm.stopPrank();

        assertEq(shares, 125e18);
    }

    /**********************************************************************************************/
    /*** LIQUIDITY_PROVIDER_ROLE administration                                                 ***/
    /**********************************************************************************************/

    function test_liquidityProviderRole_adminIsManagerAdmin() public view {
        assertEq(groveBasin.getRoleAdmin(lpRole), managerAdminRole);
    }

    function test_constructor_grantsLiquidityProviderRole() public view {
        assertTrue(groveBasin.hasRole(lpRole, lp));
    }

    function test_managerAdmin_grantLiquidityProviderRole() public {
        assertFalse(groveBasin.hasRole(lpRole, newLp));

        vm.prank(managerAdmin);
        groveBasin.grantRole(lpRole, newLp);

        assertTrue(groveBasin.hasRole(lpRole, newLp));

        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_managerAdmin_revokeLiquidityProviderRole() public {
        vm.prank(managerAdmin);
        groveBasin.revokeRole(lpRole, lp);

        assertFalse(groveBasin.hasRole(lpRole, lp));

        _expectDepositRejected(lp);
    }

    function test_managerAdmin_regrantLiquidityProviderRoleAfterFreeze() public {
        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        vm.prank(managerAdmin);
        groveBasin.grantRole(lpRole, lp);

        assertEq(_depositAs(lp, address(collateralToken), lp, 100e18), 100e18);
    }

    function test_pauser_freezeLiquidityProvider() public {
        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        assertFalse(groveBasin.hasRole(lpRole, lp));

        _expectDepositRejected(lp);
    }

    function test_pauser_freezeLiquidityProvider_doesNotFreezeOthers() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(lpRole, newLp);

        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        assertFalse(groveBasin.hasRole(lpRole, lp));
        assertTrue(groveBasin.hasRole(lpRole, newLp));

        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_pauser_cannotGrantLiquidityProviderRole() public {
        _expectMissingManagerAdminRole(pauser);
        vm.prank(pauser);
        groveBasin.grantRole(lpRole, newLp);
    }

    function test_manager_cannotGrantLiquidityProviderRole() public {
        _expectMissingManagerAdminRole(manager);
        vm.prank(manager);
        groveBasin.grantRole(lpRole, newLp);
    }

    function test_manager_cannotRevokeLiquidityProviderRole() public {
        _expectMissingManagerAdminRole(manager);
        vm.prank(manager);
        groveBasin.revokeRole(lpRole, lp);
    }

    function test_liquidityProvider_cannotGrantLiquidityProviderRole() public {
        _expectMissingManagerAdminRole(lp);
        vm.prank(lp);
        groveBasin.grantRole(lpRole, newLp);
    }

    function test_unauthorized_cannotRevokeLiquidityProviderRole() public {
        _expectMissingManagerAdminRole(notLp);
        vm.prank(notLp);
        groveBasin.revokeRole(lpRole, lp);
    }

    /**********************************************************************************************/
    /*** Frozen liquidity providers keep access to their funds                                  ***/
    /**********************************************************************************************/

    function test_freeze_liquidityProviderKeepsSharesAndCanWithdraw() public {
        _depositAs(lp, address(collateralToken), lp, 100e18);

        uint256 sharesBefore = groveBasin.shares(lp);

        assertEq(sharesBefore, 100e18);

        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        assertFalse(groveBasin.hasRole(lpRole, lp));
        assertEq(groveBasin.shares(lp), sharesBefore);

        vm.prank(lp);
        uint256 withdrawn = groveBasin.withdraw(address(collateralToken), lp, 100e18);

        assertEq(withdrawn,                     100e18);
        assertEq(collateralToken.balanceOf(lp), 100e18);
        assertEq(groveBasin.shares(lp),         0);
    }

    function test_freeze_liquidityProviderCanWithdrawEveryAsset() public {
        _depositAs(lp, address(swapToken),       lp, 100e6);
        _depositAs(lp, address(collateralToken), lp, 100e18);
        _depositAs(lp, address(creditToken),     lp, 80e18);

        assertEq(groveBasin.shares(lp), 300e18);

        vm.prank(managerAdmin);
        groveBasin.revokeRole(lpRole, lp);

        vm.startPrank(lp);
        assertEq(groveBasin.withdraw(address(swapToken),       lp, 100e6),  100e6);
        assertEq(groveBasin.withdraw(address(collateralToken), lp, 100e18), 100e18);
        assertEq(groveBasin.withdraw(address(creditToken),     lp, 80e18),  80e18);
        vm.stopPrank();

        assertEq(groveBasin.shares(lp), 0);

        assertEq(swapToken.balanceOf(lp),       100e6);
        assertEq(collateralToken.balanceOf(lp), 100e18);
        assertEq(creditToken.balanceOf(lp),     80e18);
    }

    function test_freeze_liquidityProviderCanWithdrawToAnotherReceiver() public {
        _depositAs(lp, address(collateralToken), lp, 100e18);

        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        vm.prank(lp);
        groveBasin.withdraw(address(collateralToken), notLp, 100e18);

        assertEq(collateralToken.balanceOf(notLp), 100e18);
        assertEq(collateralToken.balanceOf(lp),    0);
        assertEq(groveBasin.shares(lp),            0);
    }

    function test_freeze_shareholderThatNeverHeldTheRoleKeepsAccess() public {
        _depositAs(lp, address(collateralToken), notLp, 100e18);

        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        assertFalse(groveBasin.hasRole(lpRole, notLp));
        assertEq(groveBasin.shares(notLp), 100e18);

        vm.prank(notLp);
        groveBasin.withdraw(address(collateralToken), notLp, 100e18);

        assertEq(collateralToken.balanceOf(notLp), 100e18);
        assertEq(groveBasin.shares(notLp),         0);
    }

    function test_freeze_liquidityProviderCanWithdrawWhileDepositsArePaused() public {
        _depositAs(lp, address(collateralToken), lp, 100e18);

        vm.prank(pauser);
        groveBasin.setPaused(groveBasin.deposit.selector);

        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        vm.prank(lp);
        groveBasin.withdraw(address(collateralToken), lp, 100e18);

        assertEq(collateralToken.balanceOf(lp), 100e18);
        assertEq(groveBasin.shares(lp),         0);
    }

    function testFuzz_freeze_liquidityProviderCanWithdrawFullPosition(uint256 amount) public {
        amount = _bound(amount, 1e18, COLLATERAL_TOKEN_MAX);

        _depositAs(lp, address(collateralToken), lp, amount);

        vm.prank(managerAdmin);
        groveBasin.revokeRole(lpRole, lp);

        vm.prank(lp);
        uint256 withdrawn = groveBasin.withdraw(address(collateralToken), lp, amount);

        assertEq(withdrawn,                     amount);
        assertEq(collateralToken.balanceOf(lp), amount);
        assertEq(groveBasin.shares(lp),         0);
    }

}
