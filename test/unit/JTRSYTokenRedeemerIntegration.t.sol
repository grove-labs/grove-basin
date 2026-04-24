// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { JTRSYTokenRedeemer } from "src/redeemers/JTRSYTokenRedeemer.sol";
import { IGroveBasin }        from "src/interfaces/IGroveBasin.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockAsyncVault }     from "test/mocks/MockAsyncVault.sol";

/**********************************************************************************************/
/*** Redeemer role management tests                                                         ***/
/**********************************************************************************************/

contract RedeemerRoleManagementTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));
    }

    function test_addTokenRedeemer() public {
        bytes32 redeemerRole = groveBasin.REDEEMER_CONTRACT_ROLE();

        vm.prank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));

        assertTrue(groveBasin.hasRole(redeemerRole, address(redeemer)));
    }

    function test_addTokenRedeemer_emitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit IGroveBasin.TokenRedeemerAdded(address(redeemer));

        vm.prank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
    }

    function test_addTokenRedeemer_invalidZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidRedeemer.selector);
        groveBasin.addTokenRedeemer(address(0));
    }

    function test_addTokenRedeemer_alreadyAdded() public {
        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));

        vm.expectRevert(IGroveBasin.RedeemerAlreadyAdded.selector);
        groveBasin.addTokenRedeemer(address(redeemer));
        vm.stopPrank();
    }

    function test_removeTokenRedeemer() public {
        bytes32 redeemerRole = groveBasin.REDEEMER_CONTRACT_ROLE();

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.removeTokenRedeemer(address(redeemer));
        vm.stopPrank();

        assertFalse(groveBasin.hasRole(redeemerRole, address(redeemer)));
    }

    function test_removeTokenRedeemer_emitsEvent() public {
        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));

        vm.expectEmit(true, false, false, false);
        emit IGroveBasin.TokenRedeemerRemoved(address(redeemer));

        groveBasin.removeTokenRedeemer(address(redeemer));
        vm.stopPrank();
    }

    function test_removeTokenRedeemer_notAdded() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.InvalidRedeemer.selector);
        groveBasin.removeTokenRedeemer(address(redeemer));
    }

    function test_addTokenRedeemer_unauthorized() public {
        address nonOwner = makeAddr("nonOwner");
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonOwner,
                managerAdminRole
            )
        );
        vm.prank(nonOwner);
        groveBasin.addTokenRedeemer(address(redeemer));
    }

    function test_removeTokenRedeemer_unauthorized() public {
        address nonOwner = makeAddr("nonOwner");
        bytes32 managerAdminRole = groveBasin.MANAGER_ADMIN_ROLE();

        vm.prank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonOwner,
                managerAdminRole
            )
        );
        vm.prank(nonOwner);
        groveBasin.removeTokenRedeemer(address(redeemer));
    }

    function test_addMultipleRedeemers() public {
        MockAsyncVault vault2 = new MockAsyncVault(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer2 = new JTRSYTokenRedeemer(address(creditToken), address(vault2), address(groveBasin));

        bytes32 redeemerRole = groveBasin.REDEEMER_CONTRACT_ROLE();

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.addTokenRedeemer(address(redeemer2));
        vm.stopPrank();

        assertTrue(groveBasin.hasRole(redeemerRole, address(redeemer)));
        assertTrue(groveBasin.hasRole(redeemerRole, address(redeemer2)));
    }

}

/**********************************************************************************************/
/*** Initiate redeem integration tests                                                      ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerInitiateRedeemIntegrationTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        vm.stopPrank();

        // Give the basin some credit tokens to redeem
        creditToken.mint(address(groveBasin), 10_000e18);
    }

    function test_initiateRedeem_withAddress() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);

        assertEq(vault.lastRequestRedeemShares(),     amount);
        assertEq(vault.lastRequestRedeemController(), address(redeemer));
        assertEq(vault.lastRequestRedeemOwner(),      address(redeemer));

        assertEq(creditToken.balanceOf(address(redeemer)), amount);
        assertEq(creditToken.balanceOf(address(groveBasin)), 9_000e18);
    }

    function test_initiateRedeem_emitsEvent() public {
        uint256 amount = 1000e18;

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.RedeemInitiated(address(redeemer), owner, amount);

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);
    }

    function test_initiateRedeem_unauthorized() public {
        address nonRedeemer = makeAddr("nonRedeemer");
        bytes32 redeemerRole = groveBasin.REDEEMER_ROLE();

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                nonRedeemer,
                redeemerRole
            )
        );
        vm.prank(nonRedeemer);
        groveBasin.initiateRedeem(address(redeemer), 1000e18);
    }

}

/**********************************************************************************************/
/*** Complete redeem integration tests                                                      ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerCompleteRedeemIntegrationTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();

        // Fund vault with collateral so it can pay out on redeem
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_completeRedeem_withRequestId() public {
        uint256 amount = 1000e18;

        // First initiate to create a request
        creditToken.mint(address(groveBasin), amount);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), amount);

        collateralToken.mint(address(vault), amount);

        uint256 basinBalanceBefore = collateralToken.balanceOf(address(groveBasin));

        groveBasin.completeRedeem(requestId);

        // vault.redeem returns shares 1:1 as assets in mock
        assertEq(vault.lastRedeemShares(),     amount);
        assertEq(vault.lastRedeemReceiver(),   address(redeemer));

        assertEq(collateralToken.balanceOf(address(groveBasin)), basinBalanceBefore + amount);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 amount = 1000e18;

        creditToken.mint(address(groveBasin), amount);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), amount);

        collateralToken.mint(address(vault), amount);

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.RedeemCompleted(address(redeemer), address(this), amount);

        groveBasin.completeRedeem(requestId);
    }

}

/**********************************************************************************************/
/*** Multiple redeemer tests                                                                ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerMultipleRedeemersTests is GroveBasinTestBase {

    MockAsyncVault     public vault1;
    MockAsyncVault     public vault2;
    JTRSYTokenRedeemer public redeemer1;
    JTRSYTokenRedeemer public redeemer2;

    function setUp() public override {
        super.setUp();

        vault1 = new MockAsyncVault(address(collateralToken), address(creditToken));
        vault2 = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer1 = new JTRSYTokenRedeemer(address(creditToken), address(vault1), address(groveBasin));
        redeemer2 = new JTRSYTokenRedeemer(address(creditToken), address(vault2), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer1));
        groveBasin.addTokenRedeemer(address(redeemer2));

        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();

        creditToken.mint(address(groveBasin), 10_000e18);
        collateralToken.mint(address(vault1), 100_000e18);
        collateralToken.mint(address(vault2), 100_000e18);
    }

    function test_initiateRedeem_multipleRedeemers_withAddress() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer1), amount);

        assertEq(vault1.lastRequestRedeemShares(), amount);
    }

    function test_completeRedeem_multipleRedeemers_withRequestId() public {
        uint256 amount = 1000e18;

        creditToken.mint(address(groveBasin), amount);

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer2), amount);

        collateralToken.mint(address(vault2), amount);

        groveBasin.completeRedeem(requestId);

        assertEq(vault2.lastRedeemShares(), amount);
        assertEq(vault2.lastRedeemReceiver(), address(redeemer2));
    }

}

/**********************************************************************************************/
/*** Full flow tests                                                                        ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerFullFlowTests is GroveBasinTestBase {

    MockAsyncVault     public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();

        creditToken.mint(address(groveBasin), 10_000e18);
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_fullFlow_initiateAndCompleteRedeem() public {
        uint256 initiateAmount = 1000e18;

        // Initiate redeem
        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), initiateAmount);

        assertEq(vault.lastRequestRedeemShares(),     initiateAmount);
        assertEq(vault.lastRequestRedeemController(), address(redeemer));
        assertEq(vault.lastRequestRedeemOwner(),      address(redeemer));

        // Complete redeem - redeemer receives collateral from vault, forwards to basin
        uint256 basinCollateralBefore = collateralToken.balanceOf(address(groveBasin));
        groveBasin.completeRedeem(requestId);

        // vault.redeem returns shares 1:1 as assets in mock
        assertEq(vault.lastRedeemShares(),     initiateAmount);
        assertEq(vault.lastRedeemReceiver(),   address(redeemer));
        assertEq(vault.lastRedeemController(), address(redeemer));

        assertEq(collateralToken.balanceOf(address(groveBasin)), basinCollateralBefore + initiateAmount);
    }

}

/**********************************************************************************************/
/*** CreditTokenBalance tracking tests                                                      ***/
/**********************************************************************************************/

contract CreditTokenBalanceTrackingTests is GroveBasinTestBase {

    MockAsyncVault public vault;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public override {
        super.setUp();

        vault = new MockAsyncVault(address(collateralToken), address(creditToken));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();

        creditToken.mint(address(groveBasin), 10_000e18);
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_pendingCreditTokenBalance_initiallyZero() public view {
        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
    }

    function test_pendingCreditTokenBalance_incrementsOnInitiate() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);

        assertEq(groveBasin.pendingCreditTokenBalance(), amount);
    }

    function test_pendingCreditTokenBalance_decrementsOnComplete() public {
        uint256 initiateAmount = 1000e18;

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), initiateAmount);
        assertEq(groveBasin.pendingCreditTokenBalance(), initiateAmount);

        groveBasin.completeRedeem(requestId);

        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
    }

    function test_pendingCreditTokenBalance_fullRedeemCycle() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), amount);
        assertEq(groveBasin.pendingCreditTokenBalance(), amount);

        groveBasin.completeRedeem(requestId);

        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
    }

    function test_pendingCreditTokenBalance_multipleRequestIds() public {
        vm.prank(owner);
        bytes32 requestId1 = groveBasin.initiateRedeem(address(redeemer), 500e18);
        assertEq(groveBasin.pendingCreditTokenBalance(), 500e18);

        // Complete first request before initiating second (only 1 redemption at a time)
        groveBasin.completeRedeem(requestId1);
        assertEq(groveBasin.pendingCreditTokenBalance(), 0);

        vm.roll(block.number + 1);

        vm.prank(owner);
        bytes32 requestId2 = groveBasin.initiateRedeem(address(redeemer), 500e18);
        assertEq(groveBasin.pendingCreditTokenBalance(), 500e18);

        // Complete second request
        groveBasin.completeRedeem(requestId2);

        assertEq(groveBasin.pendingCreditTokenBalance(), 0);
    }

    function test_initiateRedeem_returnsRedeemRequestId() public {
        vm.prank(owner);
        bytes32 requestId = groveBasin.initiateRedeem(address(redeemer), 1000e18);

        // Request ID is keccak256(abi.encode(request))
        assertTrue(requestId != bytes32(0));
    }

}
