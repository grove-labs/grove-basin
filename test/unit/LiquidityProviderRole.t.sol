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

        // Raw grantRole does not set allowances, so deposits fail
        collateralToken.mint(newLp, 100e18);
        vm.startPrank(newLp);
        collateralToken.approve(address(groveBasin), 100e18);
        vm.expectRevert(IGroveBasin.LpTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(collateralToken), newLp, 100e18);
        vm.stopPrank();
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

        // lp retains its allowances from construction, so deposits succeed after re-grant
        assertEq(_depositAs(lp, address(collateralToken), lp, 100e18), 100e18);
    }

    function test_pauser_freezeLiquidityProvider() public {
        vm.prank(pauser);
        groveBasin.revokeRole(lpRole, lp);

        assertFalse(groveBasin.hasRole(lpRole, lp));

        _expectDepositRejected(lp);
    }

    function test_pauser_freezeLiquidityProvider_doesNotFreezeOthers() public {
        // Use addLiquidityProvider so newLp gets allowances
        address[] memory allowed = new address[](3);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);
        allowed[2] = address(creditToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

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
        // The receiver holds no role, only the allowance needed to receive and redeem the asset
        _allowAllAssets(notLp);

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

    function test_withdraw_revertsWhenGloballyPaused() public {
        _depositAs(lp, address(collateralToken), lp, 100e18);

        vm.prank(pauser);
        groveBasin.setPaused(bytes4(0));

        vm.prank(lp);
        vm.expectRevert(IGroveBasin.Paused.selector);
        groveBasin.withdraw(address(collateralToken), lp, 100e18);
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

    /**********************************************************************************************/
    /*** addLiquidityProvider                                                                   ***/
    /**********************************************************************************************/

    function test_addLiquidityProvider_allTokensAllowed() public {
        address[] memory allowed = new address[](3);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);
        allowed[2] = address(creditToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        assertTrue(groveBasin.hasRole(lpRole, newLp));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_addLiquidityProvider_partialTokensAllowed() public {
        address[] memory allowed = new address[](2);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        assertTrue(groveBasin.hasRole(lpRole, newLp));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        // Can deposit allowed tokens
        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);

        // Cannot deposit disallowed token
        creditToken.mint(newLp, 100e18);
        vm.startPrank(newLp);
        creditToken.approve(address(groveBasin), 100e18);
        vm.expectRevert(IGroveBasin.LpTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(creditToken), newLp, 100e18);
        vm.stopPrank();
    }

    function test_addLiquidityProvider_singleTokenAllowed() public {
        address[] memory allowed = new address[](1);
        allowed[0] = address(collateralToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        // Can deposit collateral
        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_addLiquidityProvider_revertsOnInvalidToken() public {
        address[] memory allowed = new address[](1);
        allowed[0] = makeAddr("invalidToken");

        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);
    }

    function test_addLiquidityProvider_revertsOnZeroAddress() public {
        address[] memory allowed = new address[](0);

        vm.expectRevert(IGroveBasin.InvalidLiquidityProvider.selector);
        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(address(0), allowed);
    }

    function test_addLiquidityProvider_revertsIfNotManagerAdmin() public {
        address[] memory allowed = new address[](0);

        _expectMissingManagerAdminRole(pauser);
        vm.prank(pauser);
        groveBasin.addLiquidityProvider(newLp, allowed);
    }

    function test_addLiquidityProvider_defaultBehaviorViaGrantRole() public {
        // Granting the role via grantRole (not addLiquidityProvider) leaves all tokens disallowed
        vm.prank(managerAdmin);
        groveBasin.grantRole(lpRole, newLp);

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        // Verify deposits fail for all three tokens
        collateralToken.mint(newLp, 100e18);
        vm.startPrank(newLp);
        collateralToken.approve(address(groveBasin), 100e18);
        vm.expectRevert(IGroveBasin.LpTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(collateralToken), newLp, 100e18);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** removeLiquidityProvider                                                                ***/
    /**********************************************************************************************/

    function test_removeLiquidityProvider_byManagerAdmin() public {
        address[] memory allowed = new address[](2);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        assertTrue(groveBasin.hasRole(lpRole, newLp));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));

        vm.prank(managerAdmin);
        groveBasin.removeLiquidityProvider(newLp);

        assertFalse(groveBasin.hasRole(lpRole, newLp));
        // Allowances preserved so LP can still withdraw
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
    }

    function test_removeLiquidityProvider_byPauser() public {
        address[] memory allowed = new address[](2);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        vm.prank(pauser);
        groveBasin.removeLiquidityProvider(newLp);

        assertFalse(groveBasin.hasRole(lpRole, newLp));
        // Allowances preserved
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
    }

    function test_removeLiquidityProvider_revertsIfUnauthorized() public {
        vm.expectRevert(IGroveBasin.NotAuthorizedToRemoveLp.selector);
        vm.prank(notLp);
        groveBasin.removeLiquidityProvider(lp);
    }

    function test_removeLiquidityProvider_preservesAllowances() public {
        address[] memory allowed = new address[](3);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);
        allowed[2] = address(creditToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        vm.prank(managerAdmin);
        groveBasin.removeLiquidityProvider(newLp);

        // Allowances preserved so the removed LP can still withdraw existing positions
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));
    }

    function test_removeLiquidityProvider_canBeReadded() public {
        address[] memory allowed = new address[](1);
        allowed[0] = address(collateralToken);

        vm.startPrank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);
        groveBasin.removeLiquidityProvider(newLp);

        // Re-add with all tokens allowed
        address[] memory allAllowed = new address[](3);
        allAllowed[0] = address(swapToken);
        allAllowed[1] = address(collateralToken);
        allAllowed[2] = address(creditToken);
        groveBasin.addLiquidityProvider(newLp, allAllowed);
        vm.stopPrank();

        assertTrue(groveBasin.hasRole(lpRole, newLp));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        assertEq(_depositAs(newLp, address(creditToken), newLp, 100e18), 125e18);
    }

    function test_removeLiquidityProvider_lpKeepsSharesAndCanWithdraw() public {
        address[] memory allowed = new address[](3);
        allowed[0] = address(swapToken);
        allowed[1] = address(collateralToken);
        allowed[2] = address(creditToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        _depositAs(newLp, address(collateralToken), newLp, 100e18);
        assertEq(groveBasin.shares(newLp), 100e18);

        vm.prank(managerAdmin);
        groveBasin.removeLiquidityProvider(newLp);

        // LP can still withdraw because allowances are preserved on removal
        vm.prank(newLp);
        uint256 withdrawn = groveBasin.withdraw(address(collateralToken), newLp, 100e18);

        assertEq(withdrawn, 100e18);
        assertEq(groveBasin.shares(newLp), 0);
    }

    /**********************************************************************************************/
    /*** Asset allowlist gates withdrawals                                                      ***/
    /**********************************************************************************************/

    function test_withdraw_assetNotAllowed() public {
        address[] memory allowed = new address[](1);
        allowed[0] = address(collateralToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        _depositAs(newLp, address(collateralToken), newLp, 100e18);

        // lp seeds creditToken liquidity so only the allowlist can block the withdrawal
        _depositAs(lp, address(creditToken), lp, 100e18);

        vm.prank(newLp);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(creditToken), newLp, 1e18);

        // The allowed asset can still be withdrawn
        vm.prank(newLp);
        assertEq(groveBasin.withdraw(address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_withdraw_assetDisallowedAfterDepositing() public {
        _depositAs(lp, address(collateralToken), lp, 100e18);

        address[] memory tokens = new address[](1);
        tokens[0] = address(collateralToken);
        bool[] memory flags = new bool[](1);
        flags[0] = false;

        vm.prank(managerAdmin);
        groveBasin.setLpAssetAllowed(lp, tokens, flags);

        vm.prank(lp);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(collateralToken), lp, 100e18);
    }

    function test_deposit_receiverNotAllowed() public {
        assertFalse(groveBasin.lpAssetAllowed(notLp, address(collateralToken)));

        collateralToken.mint(lp, 100e18);

        vm.startPrank(lp);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(IGroveBasin.ReceiverTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(collateralToken), notLp, 100e18);
        vm.stopPrank();
    }

    function test_withdraw_receiverAllowedAssetsOnly() public {
        // lp seeds creditToken liquidity so only the allowlist can block the withdrawal
        _depositAs(lp, address(creditToken), lp, 100e18);

        address[] memory tokens = new address[](1);
        tokens[0] = address(collateralToken);
        bool[] memory flags = new bool[](1);
        flags[0] = true;

        vm.prank(managerAdmin);
        groveBasin.setLpAssetAllowed(notLp, tokens, flags);

        _depositAs(lp, address(collateralToken), notLp, 100e18);

        assertTrue(groveBasin.lpAssetAllowed(notLp,  address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(notLp, address(creditToken)));

        vm.prank(notLp);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(creditToken), notLp, 1e18);

        vm.prank(notLp);
        assertEq(groveBasin.withdraw(address(collateralToken), notLp, 100e18), 100e18);
    }

    function test_withdraw_feeClaimerExemptFromAllowlist() public {
        address feeClaimer = makeAddr("feeClaimer");

        vm.startPrank(managerAdmin);
        groveBasin.setFeeClaimer(feeClaimer);
        groveBasin.setFeeBounds(0, 500);
        vm.stopPrank();

        vm.prank(owner);
        groveBasin.setRedemptionFee(100);

        _depositAs(lp, address(collateralToken), lp, 1000e18);

        // Swap in creditToken so that the fee claimer accrues shares without ever depositing
        creditToken.mint(address(this), 100e18);
        creditToken.approve(address(groveBasin), 100e18);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 100e18, 0, address(this), 0);

        assertGt(groveBasin.shares(feeClaimer),                       0);
        assertFalse(groveBasin.lpAssetAllowed(feeClaimer, address(creditToken)));

        vm.prank(feeClaimer);
        assertGt(groveBasin.withdraw(address(creditToken), feeClaimer, 100e18), 0);
    }

    /**********************************************************************************************/
    /*** Asset allowlist does not block other allowed tokens                                    ***/
    /**********************************************************************************************/

    function test_depositAllowed_partialAllowance_canStillDepositAllowedToken() public {
        address[] memory allowed = new address[](1);
        allowed[0] = address(swapToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        // Swap token deposit succeeds
        assertEq(_depositAs(newLp, address(swapToken), newLp, 100e6), 100e18);
    }

    function test_depositAllowed_disallowedToken_cannotWithdrawIt() public {
        // First, add LP with all tokens allowed and deposit credit
        address[] memory allAllowed = new address[](3);
        allAllowed[0] = address(swapToken);
        allAllowed[1] = address(collateralToken);
        allAllowed[2] = address(creditToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allAllowed);

        _depositAs(newLp, address(creditToken), newLp, 100e18);
        assertEq(groveBasin.shares(newLp), 125e18);

        // Now disallow credit
        address[] memory tokens = new address[](1);
        tokens[0] = address(creditToken);
        bool[] memory flags = new bool[](1);
        flags[0] = false;

        vm.prank(managerAdmin);
        groveBasin.setLpAssetAllowed(newLp, tokens, flags);

        // Credit token withdrawals are blocked, leaving the position redeemable in the other assets
        vm.prank(newLp);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(creditToken), newLp, 100e18);

        _depositAs(lp, address(collateralToken), lp, 125e18);

        vm.prank(newLp);
        assertEq(groveBasin.withdraw(address(collateralToken), newLp, 125e18), 125e18);
    }

    function test_setLpAssetAllowed_enablesDeposit() public {
        // Add LP with only collateral allowed (credit not allowed)
        address[] memory allowed = new address[](1);
        allowed[0] = address(collateralToken);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        // Confirm credit deposit blocked
        creditToken.mint(newLp, 100e18);
        vm.startPrank(newLp);
        creditToken.approve(address(groveBasin), 100e18);
        vm.expectRevert(IGroveBasin.LpTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(creditToken), newLp, 100e18);
        vm.stopPrank();

        // Allow credit
        address[] memory tokens = new address[](1);
        tokens[0] = address(creditToken);
        bool[] memory flags = new bool[](1);
        flags[0] = true;

        vm.prank(managerAdmin);
        groveBasin.setLpAssetAllowed(newLp, tokens, flags);

        // Deposit now succeeds
        assertEq(_depositAs(newLp, address(creditToken), newLp, 100e18), 125e18);
    }

    function test_setLpAssetAllowed_arrayLengthMismatch() public {
        address[] memory allowed = new address[](0);

        vm.prank(managerAdmin);
        groveBasin.addLiquidityProvider(newLp, allowed);

        address[] memory tokens = new address[](2);
        tokens[0] = address(collateralToken);
        tokens[1] = address(creditToken);

        bool[] memory flags = new bool[](1);
        flags[0] = true;

        vm.prank(managerAdmin);
        vm.expectRevert(IGroveBasin.ArrayLengthMismatch.selector);
        groveBasin.setLpAssetAllowed(newLp, tokens, flags);
    }

}
