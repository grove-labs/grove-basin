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

    function _allTokens() internal view returns (address[] memory tokens) {
        tokens = new address[](3);
        tokens[0] = address(swapToken);
        tokens[1] = address(collateralToken);
        tokens[2] = address(creditToken);
    }

    function _allowedFlags(bool allowSwap, bool allowCollateral, bool allowCredit)
        internal pure returns (bool[] memory allowed)
    {
        allowed = new bool[](3);
        allowed[0] = allowSwap;
        allowed[1] = allowCollateral;
        allowed[2] = allowCredit;
    }

    function _setLp(
        address provider,
        bool    isDepositor,
        bool    allowSwap,
        bool    allowCollateral,
        bool    allowCredit
    )
        internal
    {
        vm.prank(managerAdmin);
        groveBasin.setLiquidityProvider(
            provider,
            isDepositor,
            _allTokens(),
            _allowedFlags(allowSwap, allowCollateral, allowCredit)
        );
    }

    /// @dev Accrues fee shares to the current fee claimer through a swap, so that it holds shares
    ///      it never deposited for.
    function _accrueFeeShares() internal {
        vm.prank(managerAdmin);
        groveBasin.setFeeBounds(0, 500);

        vm.prank(owner);
        groveBasin.setRedemptionFee(100);

        _depositAs(lp, address(collateralToken), lp, 1000e18);

        creditToken.mint(address(this), 100e18);
        creditToken.approve(address(groveBasin), 100e18);
        groveBasin.swapExactIn(address(creditToken), address(collateralToken), 100e18, 0, address(this), 0);
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
        // Use setLiquidityProvider so newLp gets allowances
        _setLp(newLp, true, true, true, true);

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
    /*** setLiquidityProvider                                                                   ***/
    /**********************************************************************************************/

    function test_setLiquidityProvider_allTokensAllowed() public {
        _setLp(newLp, true, true, true, true);

        assertTrue(groveBasin.hasRole(lpRole, newLp));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_setLiquidityProvider_partialTokensAllowed() public {
        _setLp(newLp, true, true, true, false);

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

    function test_setLiquidityProvider_singleTokenAllowed() public {
        _setLp(newLp, true, false, true, false);

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        // Can deposit collateral
        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    function test_setLiquidityProvider_overwritesPreviousAllowances() public {
        _setLp(newLp, true, true, true, true);

        // Every asset is restated on each call, so nothing survives from the previous one
        _setLp(newLp, true, false, true, false);

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp,  address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));
    }

    function test_setLiquidityProvider_receiverOnly() public {
        _setLp(notLp, false, false, true, false);

        assertFalse(groveBasin.hasRole(lpRole, notLp));
        assertTrue(groveBasin.lpAssetAllowed(notLp, address(collateralToken)));

        // The receiver can hold and redeem shares without being able to deposit itself
        _depositAs(lp, address(collateralToken), notLp, 100e18);

        assertEq(groveBasin.shares(notLp), 100e18);

        _expectDepositRejected(notLp);

        vm.prank(notLp);
        assertEq(groveBasin.withdraw(address(collateralToken), notLp, 100e18), 100e18);
    }

    function test_setLiquidityProvider_revokesRoleWhenNotDepositor() public {
        assertTrue(groveBasin.hasRole(lpRole, lp));

        _setLp(lp, false, true, true, true);

        assertFalse(groveBasin.hasRole(lpRole, lp));

        _expectDepositRejected(lp);
    }

    function test_setLiquidityProvider_revertsOnInvalidToken() public {
        address[] memory tokens = _allTokens();
        tokens[2] = makeAddr("invalidToken");

        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        vm.prank(managerAdmin);
        groveBasin.setLiquidityProvider(newLp, true, tokens, _allowedFlags(true, true, true));
    }

    function test_setLiquidityProvider_revertsOnDuplicateToken() public {
        address[] memory tokens = _allTokens();
        tokens[2] = address(swapToken);

        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        vm.prank(managerAdmin);
        groveBasin.setLiquidityProvider(newLp, true, tokens, _allowedFlags(true, true, true));
    }

    function test_setLiquidityProvider_revertsOnUnorderedTokens() public {
        address[] memory tokens = _allTokens();
        tokens[0] = address(collateralToken);
        tokens[1] = address(swapToken);

        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        vm.prank(managerAdmin);
        groveBasin.setLiquidityProvider(newLp, true, tokens, _allowedFlags(true, true, true));
    }

    function test_setLiquidityProvider_revertsOnPartialTokenList() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(swapToken);
        tokens[1] = address(collateralToken);

        bool[] memory allowed = new bool[](2);
        allowed[0] = true;
        allowed[1] = true;

        vm.expectRevert(IGroveBasin.InvalidAssetListLength.selector);
        vm.prank(managerAdmin);
        groveBasin.setLiquidityProvider(newLp, true, tokens, allowed);
    }

    function test_setLiquidityProvider_revertsOnAllowedLengthMismatch() public {
        bool[] memory allowed = new bool[](2);
        allowed[0] = true;
        allowed[1] = true;

        vm.expectRevert(IGroveBasin.InvalidAssetListLength.selector);
        vm.prank(managerAdmin);
        groveBasin.setLiquidityProvider(newLp, true, _allTokens(), allowed);
    }

    function test_setLiquidityProvider_revertsIfNotManagerAdmin() public {
        _expectMissingManagerAdminRole(pauser);
        vm.prank(pauser);
        groveBasin.setLiquidityProvider(newLp, true, _allTokens(), _allowedFlags(true, true, true));
    }

    function test_setLiquidityProvider_defaultBehaviorViaGrantRole() public {
        // Granting the role via grantRole (not setLiquidityProvider) leaves all tokens disallowed
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
        _setLp(newLp, true, true, true, false);

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
        _setLp(newLp, true, true, true, false);

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
        _setLp(newLp, true, true, true, true);

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
        _setLp(newLp, true, false, true, false);

        vm.prank(managerAdmin);
        groveBasin.removeLiquidityProvider(newLp);

        // Re-add with all tokens allowed
        _setLp(newLp, true, true, true, true);

        assertTrue(groveBasin.hasRole(lpRole, newLp));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        assertEq(_depositAs(newLp, address(creditToken), newLp, 100e18), 125e18);
    }

    function test_removeLiquidityProvider_lpKeepsSharesAndCanWithdraw() public {
        _setLp(newLp, true, true, true, true);

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
    /*** removeAssetAllowed                                                                     ***/
    /**********************************************************************************************/

    function test_removeAssetAllowed_byManagerAdmin() public {
        _setLp(newLp, true, true, true, true);

        vm.prank(managerAdmin);
        groveBasin.removeAssetAllowed(newLp);

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        // The role is untouched, only the asset allowances are cleared
        assertTrue(groveBasin.hasRole(lpRole, newLp));
    }

    function test_removeAssetAllowed_byPauser() public {
        _setLp(newLp, true, true, true, true);

        vm.prank(pauser);
        groveBasin.removeAssetAllowed(newLp);

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        assertTrue(groveBasin.hasRole(lpRole, newLp));
    }

    function test_removeAssetAllowed_revertsIfUnauthorized() public {
        vm.expectRevert(IGroveBasin.NotAuthorizedToRemoveAssetAllowed.selector);
        vm.prank(notLp);
        groveBasin.removeAssetAllowed(lp);
    }

    function test_removeAssetAllowed_blocksDepositAndWithdraw() public {
        _setLp(newLp, true, true, true, true);

        _depositAs(newLp, address(collateralToken), newLp, 100e18);
        assertEq(groveBasin.shares(newLp), 100e18);

        vm.prank(pauser);
        groveBasin.removeAssetAllowed(newLp);

        collateralToken.mint(newLp, 100e18);

        vm.startPrank(newLp);
        collateralToken.approve(address(groveBasin), 100e18);

        vm.expectRevert(IGroveBasin.LpTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(collateralToken), newLp, 100e18);

        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(collateralToken), newLp, 100e18);
        vm.stopPrank();
    }

    function test_removeAssetAllowed_isIdempotent() public {
        _setLp(newLp, true, true, false, false);

        vm.startPrank(pauser);
        groveBasin.removeAssetAllowed(newLp);
        groveBasin.removeAssetAllowed(newLp);
        vm.stopPrank();

        assertFalse(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(newLp, address(creditToken)));
    }

    function test_removeAssetAllowed_canBeReallowed() public {
        _setLp(newLp, true, true, true, true);

        vm.prank(pauser);
        groveBasin.removeAssetAllowed(newLp);

        _setLp(newLp, true, true, true, true);

        assertTrue(groveBasin.lpAssetAllowed(newLp, address(swapToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(collateralToken)));
        assertTrue(groveBasin.lpAssetAllowed(newLp, address(creditToken)));

        assertEq(_depositAs(newLp, address(collateralToken), newLp, 100e18), 100e18);
    }

    /**********************************************************************************************/
    /*** Asset allowlist gates withdrawals                                                      ***/
    /**********************************************************************************************/

    function test_withdraw_assetNotAllowed() public {
        _setLp(newLp, true, false, true, false);

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

        _setLp(lp, true, true, false, true);

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

        _setLp(notLp, false, false, true, false);

        _depositAs(lp, address(collateralToken), notLp, 100e18);

        assertTrue(groveBasin.lpAssetAllowed(notLp,  address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(notLp, address(creditToken)));

        vm.prank(notLp);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(creditToken), notLp, 1e18);

        vm.prank(notLp);
        assertEq(groveBasin.withdraw(address(collateralToken), notLp, 100e18), 100e18);
    }

    function test_setFeeClaimer_doesNotPermissionClaimer() public {
        address feeClaimer = makeAddr("feeClaimer");

        vm.prank(managerAdmin);
        groveBasin.setFeeClaimer(feeClaimer);

        // setFeeClaimer sets no permissions, so the claimer accrues shares it cannot withdraw until
        // it is permissioned through setLiquidityProvider
        assertFalse(groveBasin.lpAssetAllowed(feeClaimer, address(swapToken)));
        assertFalse(groveBasin.lpAssetAllowed(feeClaimer, address(collateralToken)));
        assertFalse(groveBasin.lpAssetAllowed(feeClaimer, address(creditToken)));

        assertFalse(groveBasin.hasRole(lpRole, feeClaimer));

        _accrueFeeShares();

        assertGt(groveBasin.shares(feeClaimer), 0);

        vm.prank(feeClaimer);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(collateralToken), feeClaimer, 100e18);

        _setLp(feeClaimer, false, true, true, true);

        vm.prank(feeClaimer);
        assertGt(groveBasin.withdraw(address(collateralToken), feeClaimer, 100e18), 0);
    }

    function test_setFeeClaimer_leavesLiquidityProviderRoleUntouched() public {
        _setLp(newLp, true, true, true, true);

        assertTrue(groveBasin.hasRole(lpRole, newLp));

        vm.prank(managerAdmin);
        groveBasin.setFeeClaimer(newLp);

        // A claimer that can also deposit could convert between assets through deposit and withdraw
        // without paying the swap fee, so it is on the manager admin to drop the role
        assertTrue(groveBasin.hasRole(lpRole, newLp));

        _setLp(newLp, false, true, true, true);

        assertFalse(groveBasin.hasRole(lpRole, newLp));

        collateralToken.mint(newLp, 100e18);

        vm.startPrank(newLp);
        collateralToken.approve(address(groveBasin), 100e18);
        vm.expectRevert(IGroveBasin.NotLiquidityProvider.selector);
        groveBasin.deposit(address(collateralToken), newLp, 100e18);
        vm.stopPrank();
    }

    function test_withdraw_feeClaimerUsesAllowlist() public {
        address feeClaimer = makeAddr("feeClaimer");

        vm.prank(managerAdmin);
        groveBasin.setFeeClaimer(feeClaimer);

        _setLp(feeClaimer, false, true, true, true);

        _accrueFeeShares();

        assertGt(groveBasin.shares(feeClaimer), 0);
        assertTrue(groveBasin.lpAssetAllowed(feeClaimer, address(creditToken)));

        vm.prank(feeClaimer);
        assertGt(groveBasin.withdraw(address(creditToken), feeClaimer, 100e18), 0);
    }

    function test_withdraw_feeClaimerDisallowedAsset() public {
        address feeClaimer = makeAddr("feeClaimer");

        vm.prank(managerAdmin);
        groveBasin.setFeeClaimer(feeClaimer);

        _setLp(feeClaimer, false, true, true, true);

        _accrueFeeShares();

        // The fee claimer carries no carve-out, so revoking its credit allowance blocks it exactly
        // as it would any other shareholder
        _setLp(feeClaimer, false, true, true, false);

        vm.prank(feeClaimer);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(creditToken), feeClaimer, 1e18);

        vm.prank(feeClaimer);
        assertGt(groveBasin.withdraw(address(collateralToken), feeClaimer, 100e18), 0);
    }

    function test_withdraw_previousFeeClaimerKeepsAllowances() public {
        address oldClaimer = makeAddr("oldFeeClaimer");
        address newClaimer = makeAddr("newFeeClaimer");

        vm.prank(managerAdmin);
        groveBasin.setFeeClaimer(oldClaimer);

        _setLp(oldClaimer, false, true, true, true);

        _accrueFeeShares();

        uint256 accruedShares = groveBasin.shares(oldClaimer);

        assertGt(accruedShares, 0);

        vm.prank(managerAdmin);
        groveBasin.setFeeClaimer(newClaimer);

        assertEq(groveBasin.shares(oldClaimer), accruedShares);
        assertTrue(groveBasin.lpAssetAllowed(oldClaimer, address(collateralToken)));

        vm.prank(oldClaimer);
        assertGt(groveBasin.withdraw(address(collateralToken), oldClaimer, 100e18), 0);
    }

    /**********************************************************************************************/
    /*** Asset allowlist does not block other allowed tokens                                    ***/
    /**********************************************************************************************/

    function test_depositAllowed_partialAllowance_canStillDepositAllowedToken() public {
        _setLp(newLp, true, true, false, false);

        // Swap token deposit succeeds
        assertEq(_depositAs(newLp, address(swapToken), newLp, 100e6), 100e18);
    }

    function test_depositAllowed_disallowedToken_cannotWithdrawIt() public {
        // First, add LP with all tokens allowed and deposit credit
        _setLp(newLp, true, true, true, true);

        _depositAs(newLp, address(creditToken), newLp, 100e18);
        assertEq(groveBasin.shares(newLp), 125e18);

        // Now disallow credit
        _setLp(newLp, true, true, true, false);

        // Credit token withdrawals are blocked, leaving the position redeemable in the other assets
        vm.prank(newLp);
        vm.expectRevert(IGroveBasin.LpTokenWithdrawNotAllowed.selector);
        groveBasin.withdraw(address(creditToken), newLp, 100e18);

        _depositAs(lp, address(collateralToken), lp, 125e18);

        vm.prank(newLp);
        assertEq(groveBasin.withdraw(address(collateralToken), newLp, 125e18), 125e18);
    }

    function test_setLiquidityProvider_enablesDeposit() public {
        // Add LP with only collateral allowed (credit not allowed)
        _setLp(newLp, true, false, true, false);

        // Confirm credit deposit blocked
        creditToken.mint(newLp, 100e18);
        vm.startPrank(newLp);
        creditToken.approve(address(groveBasin), 100e18);
        vm.expectRevert(IGroveBasin.LpTokenDepositNotAllowed.selector);
        groveBasin.deposit(address(creditToken), newLp, 100e18);
        vm.stopPrank();

        // Allow credit
        _setLp(newLp, true, false, true, true);

        // Deposit now succeeds
        assertEq(_depositAs(newLp, address(creditToken), newLp, 100e18), 125e18);
    }

}
