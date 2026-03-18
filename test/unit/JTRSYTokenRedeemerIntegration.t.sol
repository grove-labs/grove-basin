// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }         from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer } from "src/JTRSYTokenRedeemer.sol";
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

        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault.__setPermissioned(predictedRedeemer, true);

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
        vm.expectRevert("GroveBasin/invalid-redeemer");
        groveBasin.addTokenRedeemer(address(0));
    }

    function test_addTokenRedeemer_alreadyAdded() public {
        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));

        vm.expectRevert("GroveBasin/redeemer-already-added");
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
        vm.expectRevert("GroveBasin/invalid-redeemer");
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

        address predictedRedeemer2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault2.__setPermissioned(predictedRedeemer2, true);

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

        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault.__setPermissioned(predictedRedeemer, true);

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

        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault.__setPermissioned(predictedRedeemer, true);

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();

        // Fund vault with collateral so it can pay out on redeem
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_completeRedeem_withAddress() public {
        uint256 amount = 1000e18;

        uint256 basinBalanceBefore = collateralToken.balanceOf(address(groveBasin));

        groveBasin.completeRedeem(address(redeemer), amount);

        assertEq(vault.lastRedeemShares(),   amount);
        assertEq(vault.lastRedeemReceiver(), address(redeemer));

        assertEq(collateralToken.balanceOf(address(groveBasin)), basinBalanceBefore + amount);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 amount = 1000e18;

        vm.expectEmit(true, true, false, true);
        emit IGroveBasin.RedeemCompleted(address(redeemer), address(this), amount);

        groveBasin.completeRedeem(address(redeemer), amount);
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

        address predictedRedeemer1 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault1.__setPermissioned(predictedRedeemer1, true);
        redeemer1 = new JTRSYTokenRedeemer(address(creditToken), address(vault1), address(groveBasin));

        address predictedRedeemer2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault2.__setPermissioned(predictedRedeemer2, true);
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

    function test_completeRedeem_multipleRedeemers_withAddress() public {
        uint256 amount = 1000e18;

        groveBasin.completeRedeem(address(redeemer2), amount);

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

        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault.__setPermissioned(predictedRedeemer, true);

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
        uint256 completeAmount = 500e18;

        // Initiate redeem
        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), initiateAmount);

        assertEq(vault.lastRequestRedeemShares(),     initiateAmount);
        assertEq(vault.lastRequestRedeemController(), address(redeemer));
        assertEq(vault.lastRequestRedeemOwner(),      address(redeemer));

        // Complete redeem - redeemer receives collateral from vault, forwards to basin
        uint256 basinCollateralBefore = collateralToken.balanceOf(address(groveBasin));
        groveBasin.completeRedeem(address(redeemer), completeAmount);

        assertEq(vault.lastRedeemShares(),     completeAmount);
        assertEq(vault.lastRedeemReceiver(),   address(redeemer));
        assertEq(vault.lastRedeemController(), address(redeemer));

        assertEq(collateralToken.balanceOf(address(groveBasin)), basinCollateralBefore + completeAmount);
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

        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vault.__setPermissioned(predictedRedeemer, true);

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(groveBasin));

        vm.startPrank(owner);
        groveBasin.addTokenRedeemer(address(redeemer));
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), address(this));
        vm.stopPrank();

        creditToken.mint(address(groveBasin), 10_000e18);
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_creditTokenBalance_initiallyZero() public view {
        assertEq(groveBasin.creditTokenBalance(), 0);
    }

    function test_creditTokenBalance_incrementsOnInitiate() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);

        assertEq(groveBasin.creditTokenBalance(), amount);
    }

    function test_creditTokenBalance_decrementsOnComplete() public {
        uint256 initiateAmount = 1000e18;
        uint256 completeAmount = 400e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), initiateAmount);
        assertEq(groveBasin.creditTokenBalance(), initiateAmount);

        groveBasin.completeRedeem(address(redeemer), completeAmount);

        assertEq(groveBasin.creditTokenBalance(), initiateAmount - completeAmount);
    }

    function test_creditTokenBalance_fullRedeemCycle() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);
        assertEq(groveBasin.creditTokenBalance(), amount);

        groveBasin.completeRedeem(address(redeemer), amount);

        assertEq(groveBasin.creditTokenBalance(), 0);
    }

    function test_creditTokenBalance_underflowProtection() public {
        uint256 amount = 1000e18;

        vm.prank(owner);
        groveBasin.initiateRedeem(address(redeemer), amount);
        assertEq(groveBasin.creditTokenBalance(), amount);

        // Complete with more than was initiated
        groveBasin.completeRedeem(address(redeemer), amount + 500e18);

        // Should floor at 0 rather than underflow
        assertEq(groveBasin.creditTokenBalance(), 0);
    }

    function test_creditTokenBalance_multipleInitiates() public {
        vm.startPrank(owner);
        groveBasin.initiateRedeem(address(redeemer), 500e18);
        assertEq(groveBasin.creditTokenBalance(), 500e18);

        groveBasin.initiateRedeem(address(redeemer), 500e18);
        assertEq(groveBasin.creditTokenBalance(), 1000e18);
        vm.stopPrank();
    }

}
