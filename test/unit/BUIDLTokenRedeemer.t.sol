// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { BUIDLTokenRedeemer }  from "src/BUIDLTokenRedeemer.sol";
import { ITokenRedeemer }      from "src/interfaces/ITokenRedeemer.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

/**********************************************************************************************/
/*** Helper                                                                                 ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerTestBase is Test {

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
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerConstructorTests is BUIDLTokenRedeemerTestBase {

    MockERC20  public creditToken;
    MockERC20  public collateralToken;
    address    public redemptionAddress;
    GroveBasin public basin;

    function setUp() public {
        creditToken       = new MockERC20("creditToken", "creditToken", 18);
        collateralToken   = new MockERC20("collateralToken", "collateralToken", 18);
        redemptionAddress = makeAddr("redemptionAddress");
        basin             = _deployBasin(address(collateralToken), address(creditToken));
    }

    function test_constructor() public {
        BUIDLTokenRedeemer redeemer = new BUIDLTokenRedeemer(address(creditToken), redemptionAddress, address(basin));

        assertEq(redeemer.creditToken(),      address(creditToken));
        assertEq(redeemer.collateralToken(),   address(collateralToken));
        assertEq(redeemer.redemptionAddress(), redemptionAddress);
        assertEq(redeemer.vault(),             redemptionAddress);
        assertEq(address(redeemer.basin()),    address(basin));
    }

    function test_constructor_invalidCreditToken() public {
        vm.expectRevert(ITokenRedeemer.InvalidCreditToken.selector);
        new BUIDLTokenRedeemer(address(0), redemptionAddress, address(basin));
    }

    function test_constructor_invalidRedemptionAddress() public {
        vm.expectRevert(BUIDLTokenRedeemer.InvalidRedemptionAddress.selector);
        new BUIDLTokenRedeemer(address(creditToken), address(0), address(basin));
    }

    function test_constructor_invalidBasin() public {
        vm.expectRevert(ITokenRedeemer.InvalidBasin.selector);
        new BUIDLTokenRedeemer(address(creditToken), redemptionAddress, address(0));
    }

    function test_constructor_creditTokenMismatch() public {
        MockERC20 wrongCreditToken = new MockERC20("wrong", "wrong", 18);

        vm.expectRevert(ITokenRedeemer.CreditTokenMismatch.selector);
        new BUIDLTokenRedeemer(address(wrongCreditToken), redemptionAddress, address(basin));
    }

}

/**********************************************************************************************/
/*** setUp / tearDown tests                                                                 ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerSetUpTests is BUIDLTokenRedeemerTestBase {

    function test_setUp_onlyBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        address   redemptionAddr  = makeAddr("redemptionAddress");

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        BUIDLTokenRedeemer redeemer = new BUIDLTokenRedeemer(address(creditToken), redemptionAddr, address(basin));

        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.setUp(address(basin));
    }

    function test_tearDown_onlyBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        address   redemptionAddr  = makeAddr("redemptionAddress");

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        BUIDLTokenRedeemer redeemer = new BUIDLTokenRedeemer(address(creditToken), redemptionAddr, address(basin));

        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.tearDown(address(basin));
    }

}

/**********************************************************************************************/
/*** InitiateRedeem tests                                                                   ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerInitiateRedeemTests is BUIDLTokenRedeemerTestBase {

    MockERC20            public creditToken;
    MockERC20            public collateralToken;
    BUIDLTokenRedeemer   public redeemer;
    address              public basin;
    address              public redemptionAddress;

    function setUp() public {
        creditToken       = new MockERC20("creditToken",     "creditToken",     18);
        collateralToken   = new MockERC20("collateralToken", "collateralToken", 18);
        redemptionAddress = makeAddr("redemptionAddress");

        basin = address(_deployBasin(address(collateralToken), address(creditToken)));

        redeemer = new BUIDLTokenRedeemer(address(creditToken), redemptionAddress, basin);

        creditToken.mint(basin, 10_000e18);
        vm.prank(basin);
        creditToken.approve(address(redeemer), type(uint256).max);
    }

    function test_initiateRedeem() public {
        uint256 amount = 1000e18;

        vm.prank(basin);
        redeemer.initiateRedeem(amount);

        assertEq(creditToken.balanceOf(redemptionAddress), amount);
        assertEq(creditToken.balanceOf(address(redeemer)), 0);
        assertEq(creditToken.balanceOf(basin),             9_000e18);
    }

    function test_initiateRedeem_multipleAmounts() public {
        vm.startPrank(basin);
        redeemer.initiateRedeem(100e18);
        assertEq(creditToken.balanceOf(redemptionAddress), 100e18);

        redeemer.initiateRedeem(200e18);
        assertEq(creditToken.balanceOf(redemptionAddress), 300e18);
        vm.stopPrank();
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

contract BUIDLTokenRedeemerCompleteRedeemTests is BUIDLTokenRedeemerTestBase {

    MockERC20            public collateralToken;
    MockERC20            public creditToken;
    BUIDLTokenRedeemer   public redeemer;
    address              public basin;
    address              public redemptionAddress;

    function setUp() public {
        collateralToken   = new MockERC20("collateralToken", "collateralToken", 18);
        creditToken       = new MockERC20("creditToken",     "creditToken",     18);
        redemptionAddress = makeAddr("redemptionAddress");

        basin = address(_deployBasin(address(collateralToken), address(creditToken)));

        redeemer = new BUIDLTokenRedeemer(address(creditToken), redemptionAddress, basin);
    }

    function test_completeRedeem_sendsCollateralToCaller() public {
        uint256 collateralTokenAmount = 1000e18;

        collateralToken.mint(address(redeemer), collateralTokenAmount);

        uint256 callerBalanceBefore = collateralToken.balanceOf(basin);

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(collateralTokenAmount);

        uint256 callerBalanceAfter = collateralToken.balanceOf(basin);

        assertEq(assets,                                   collateralTokenAmount);
        assertEq(callerBalanceAfter - callerBalanceBefore, collateralTokenAmount);
    }

    function test_completeRedeem_usesBalanceWhenLess() public {
        uint256 collateralTokenAmount = 1000e18;
        uint256 redeemerBalance       = 800e18;

        collateralToken.mint(address(redeemer), redeemerBalance);

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(collateralTokenAmount);

        assertEq(assets, redeemerBalance);
    }

    function test_completeRedeem_usesAmountWhenLess() public {
        uint256 collateralTokenAmount = 500e18;
        uint256 redeemerBalance       = 1000e18;

        collateralToken.mint(address(redeemer), redeemerBalance);

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(collateralTokenAmount);

        assertEq(assets, collateralTokenAmount);
    }

    function test_completeRedeem_multipleCompletes() public {
        collateralToken.mint(address(redeemer), 1000e18);

        vm.startPrank(basin);
        redeemer.completeRedeem(400e18);

        uint256 balanceAfterFirst = collateralToken.balanceOf(basin);

        redeemer.completeRedeem(300e18);

        uint256 balanceAfterSecond = collateralToken.balanceOf(basin);
        vm.stopPrank();

        assertEq(balanceAfterFirst,                        400e18);
        assertEq(balanceAfterSecond - balanceAfterFirst,   300e18);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 collateralTokenAmount = 1000e18;

        collateralToken.mint(address(redeemer), collateralTokenAmount);

        vm.expectEmit(address(redeemer));
        emit ITokenRedeemer.RedeemCompleted(collateralTokenAmount);

        vm.prank(basin);
        redeemer.completeRedeem(collateralTokenAmount);
    }

    function test_completeRedeem_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.completeRedeem(1000e18);
    }

}
