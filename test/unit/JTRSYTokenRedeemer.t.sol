// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer } from "src/redeemers/JTRSYTokenRedeemer.sol";
import { ITokenRedeemer, RedeemRequest } from "src/interfaces/ITokenRedeemer.sol";

import { MockAsyncVault }   from "test/mocks/MockAsyncVault.sol";
import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerConstructorTests is Test {

    MockERC20      public creditToken;
    MockERC20      public collateralToken;
    MockAsyncVault public vault;
    GroveBasin     public basin;

    function setUp() public {
        creditToken     = new MockERC20("creditToken", "creditToken", 18);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));
        basin           = _deployBasin(address(collateralToken), address(creditToken));
    }

    function test_constructor() public {
        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(basin));

        assertEq(redeemer.creditToken(),    address(creditToken));
        assertEq(redeemer.vault(),          address(vault));
        assertEq(address(redeemer.basin()), address(basin));
        assertEq(redeemer.redemptionActive(), false);
    }

    function test_constructor_invalidCreditToken() public {
        vm.expectRevert(ITokenRedeemer.InvalidCreditToken.selector);
        new JTRSYTokenRedeemer(address(0), address(vault), address(basin));
    }

    function test_constructor_invalidVault() public {
        vm.expectRevert(JTRSYTokenRedeemer.InvalidVault.selector);
        new JTRSYTokenRedeemer(address(creditToken), address(0), address(basin));
    }

    function test_constructor_invalidBasin() public {
        vm.expectRevert(ITokenRedeemer.InvalidBasin.selector);
        new JTRSYTokenRedeemer(address(creditToken), address(vault), address(0));
    }

    function test_constructor_creditTokenMismatch() public {
        MockERC20 wrongCreditToken = new MockERC20("wrong", "wrong", 18);

        vm.expectRevert(ITokenRedeemer.CreditTokenMismatch.selector);
        new JTRSYTokenRedeemer(address(wrongCreditToken), address(vault), address(basin));
    }

    function test_constructor_collateralAssetMismatch() public {
        MockERC20 otherCollateral = new MockERC20("other", "other", 18);
        MockAsyncVault wrongVault = new MockAsyncVault(address(otherCollateral), address(creditToken));

        vm.expectRevert(JTRSYTokenRedeemer.CollateralAssetMismatch.selector);
        new JTRSYTokenRedeemer(address(creditToken), address(wrongVault), address(basin));
    }

    function test_constructor_shareMismatch() public {
        MockERC20 wrongShare = new MockERC20("wrongShare", "wrongShare", 18);
        MockAsyncVault wrongVault = new MockAsyncVault(address(collateralToken), address(wrongShare));

        vm.expectRevert(JTRSYTokenRedeemer.ShareMismatch.selector);
        new JTRSYTokenRedeemer(address(creditToken), address(wrongVault), address(basin));
    }

    function _deployBasin(address collateralToken_, address creditToken_) internal returns (GroveBasin) {
        MockERC20 swapToken_ = new MockERC20("swapToken", "swapToken", 6);

        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();

        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        return new GroveBasin(
            address(this),
            address(this),
            address(swapToken_),
            collateralToken_,
            creditToken_,
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        );
    }

}

/**********************************************************************************************/
/*** setUp validation tests                                                                 ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerSetUpTests is Test {

    function test_setUp_onlyBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(basin));

        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.setUp(address(basin));
    }

    function test_tearDown_onlyBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(basin));

        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.tearDown(address(basin));
    }

    function _deployBasin(address collateralToken_, address creditToken_) internal returns (GroveBasin) {
        MockERC20 swapToken = new MockERC20("swapToken", "swapToken", 6);

        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();

        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        return new GroveBasin(
            address(this),
            address(this),
            address(swapToken),
            collateralToken_,
            creditToken_,
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        );
    }

}

/**********************************************************************************************/
/*** InitiateRedeem tests                                                                   ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerInitiateRedeemTests is Test {

    MockERC20            public creditToken;
    MockERC20            public collateralToken;
    MockAsyncVault       public vault;
    JTRSYTokenRedeemer   public redeemer;
    address              public basin;

    function setUp() public {
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));

        MockERC20 swapToken = new MockERC20("swapToken", "swapToken", 6);

        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();

        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        basin = address(new GroveBasin(
            address(this),
            address(this),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        ));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), basin);

        creditToken.mint(basin, 10_000e18);
        vm.prank(basin);
        creditToken.approve(address(redeemer), type(uint256).max);
    }

    function test_initiateRedeem() public {
        uint256 amount = 1000e18;

        vm.prank(basin);
        redeemer.initiateRedeem(amount);

        assertEq(vault.lastRequestRedeemShares(),          amount);
        assertEq(vault.lastRequestRedeemController(),      address(redeemer));
        assertEq(vault.lastRequestRedeemOwner(),           address(redeemer));
        assertEq(creditToken.balanceOf(address(redeemer)), amount);
        assertEq(redeemer.redemptionActive(),              true);
    }

    function test_initiateRedeem_revertsIfRedemptionAlreadyActive() public {
        vm.prank(basin);
        redeemer.initiateRedeem(100e18);

        vm.prank(basin);
        vm.expectRevert(JTRSYTokenRedeemer.RedemptionAlreadyActive.selector);
        redeemer.initiateRedeem(200e18);
    }

    function test_initiateRedeem_emitsEvent() public {
        uint256 amount = 1000e18;

        vm.expectEmit(address(redeemer));
        emit ITokenRedeemer.RedeemInitiated(amount);

        vm.prank(basin);
        redeemer.initiateRedeem(amount);
    }

    function test_initiateRedeem_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.initiateRedeem(1000e18);
    }

}

/**********************************************************************************************/
/*** CompleteRedeem tests                                                                   ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerCompleteRedeemTests is Test {

    MockERC20            public collateralToken;
    MockERC20            public creditToken;
    MockAsyncVault       public vault;
    JTRSYTokenRedeemer   public redeemer;
    address              public basin;

    function setUp() public {
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));

        MockERC20 swapToken = new MockERC20("swapToken", "swapToken", 6);

        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();

        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        basin = address(new GroveBasin(
            address(this),
            address(this),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        ));

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), basin);

        // Fund vault with collateral so it can pay out on redeem
        collateralToken.mint(address(vault), 100_000e18);
    }

    function _makeRequest(uint256 creditAmount, uint256 collateralAmount) internal view returns (RedeemRequest memory) {
        return RedeemRequest({
            blockNumber:           block.number,
            redeemer:              address(redeemer),
            creditTokenAmount:     creditAmount,
            collateralTokenAmount: collateralAmount
        });
    }

    function test_completeRedeem_sendsCollateralToCaller() public {
        uint256 creditAmount = 1000e18;
        RedeemRequest memory request = _makeRequest(creditAmount, creditAmount);

        uint256 callerBalanceBefore = collateralToken.balanceOf(basin);

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(request);

        uint256 callerBalanceAfter = collateralToken.balanceOf(basin);

        // vault.redeem returns shares 1:1 as assets in mock
        assertEq(assets,                                   creditAmount);
        assertEq(callerBalanceAfter - callerBalanceBefore, creditAmount);

        assertEq(vault.lastRedeemShares(),     creditAmount);
        assertEq(vault.lastRedeemReceiver(),   address(redeemer));
        assertEq(vault.lastRedeemController(), address(redeemer));
    }

    function test_completeRedeem_resetsRedemptionActive() public {
        creditToken.mint(basin, 10_000e18);
        vm.prank(basin);
        creditToken.approve(address(redeemer), type(uint256).max);

        vm.prank(basin);
        redeemer.initiateRedeem(1000e18);
        assertEq(redeemer.redemptionActive(), true);

        RedeemRequest memory request = _makeRequest(1000e18, 1000e18);

        vm.prank(basin);
        redeemer.completeRedeem(request);
        assertEq(redeemer.redemptionActive(), false);
    }

    function test_completeRedeem_allowsNewRedemptionAfterComplete() public {
        creditToken.mint(basin, 10_000e18);
        vm.prank(basin);
        creditToken.approve(address(redeemer), type(uint256).max);

        // First cycle
        vm.prank(basin);
        redeemer.initiateRedeem(1000e18);

        RedeemRequest memory request = _makeRequest(1000e18, 1000e18);
        vm.prank(basin);
        redeemer.completeRedeem(request);

        // Second cycle should succeed
        vm.prank(basin);
        redeemer.initiateRedeem(500e18);
        assertEq(redeemer.redemptionActive(), true);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 creditAmount = 1000e18;
        RedeemRequest memory request = _makeRequest(creditAmount, creditAmount);

        vm.expectEmit(address(redeemer));
        emit ITokenRedeemer.RedeemCompleted(creditAmount);

        vm.prank(basin);
        redeemer.completeRedeem(request);
    }

    function test_completeRedeem_onlyBasin() public {
        address notBasin = makeAddr("notBasin");
        RedeemRequest memory request = _makeRequest(1000e18, 1000e18);

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.completeRedeem(request);
    }

}

/**********************************************************************************************/
/*** Sweep tests                                                                            ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerSweepTests is Test {

    MockERC20            public creditToken;
    MockERC20            public collateralToken;
    MockAsyncVault       public vault;
    JTRSYTokenRedeemer   public redeemer;
    GroveBasin           public basin;
    address              public managerAdmin;

    function setUp() public {
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));
        managerAdmin    = makeAddr("managerAdmin");

        MockERC20 swapToken = new MockERC20("swapToken", "swapToken", 6);

        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();

        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        basin = new GroveBasin(
            address(this),
            address(this),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        );

        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), address(this));
        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), managerAdmin);

        redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault), address(basin));
    }

    function test_sweep_creditToken() public {
        creditToken.mint(address(redeemer), 500e18);

        vm.prank(managerAdmin);
        redeemer.sweep(address(creditToken), 500e18);

        assertEq(creditToken.balanceOf(address(redeemer)), 0);
        assertEq(creditToken.balanceOf(address(basin)),    500e18);
    }

    function test_sweep_collateralToken() public {
        collateralToken.mint(address(redeemer), 300e18);

        vm.prank(managerAdmin);
        redeemer.sweep(address(collateralToken), 300e18);

        assertEq(collateralToken.balanceOf(address(redeemer)), 0);
        assertEq(collateralToken.balanceOf(address(basin)),    300e18);
    }

    function test_sweep_partialAmount() public {
        creditToken.mint(address(redeemer), 500e18);

        vm.prank(managerAdmin);
        redeemer.sweep(address(creditToken), 200e18);

        assertEq(creditToken.balanceOf(address(redeemer)), 300e18);
        assertEq(creditToken.balanceOf(address(basin)),    200e18);
    }

    function test_sweep_emitsEvent() public {
        creditToken.mint(address(redeemer), 500e18);

        vm.expectEmit(address(redeemer));
        emit ITokenRedeemer.Swept(address(creditToken), 500e18);

        vm.prank(managerAdmin);
        redeemer.sweep(address(creditToken), 500e18);
    }

    function test_sweep_notAuthorized() public {
        address notManagerAdmin = makeAddr("notManagerAdmin");

        vm.prank(notManagerAdmin);
        vm.expectRevert(ITokenRedeemer.NotAuthorized.selector);
        redeemer.sweep(address(creditToken), 100e18);
    }

    function test_sweep_managerRoleNotAuthorized() public {
        address manager = makeAddr("manager");
        basin.grantRole(basin.MANAGER_ROLE(), manager);

        vm.prank(manager);
        vm.expectRevert(ITokenRedeemer.NotAuthorized.selector);
        redeemer.sweep(address(creditToken), 100e18);
    }

    function test_sweep_invalidToken() public {
        address randomToken = makeAddr("randomToken");

        vm.prank(managerAdmin);
        vm.expectRevert(ITokenRedeemer.InvalidToken.selector);
        redeemer.sweep(randomToken, 100e18);
    }

    function test_sweep_zeroAmount() public {
        vm.prank(managerAdmin);
        vm.expectRevert(ITokenRedeemer.ZeroBalance.selector);
        redeemer.sweep(address(creditToken), 0);
    }

}
