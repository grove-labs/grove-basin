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
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerConstructorTests is Test {

    MockERC20  public creditToken;
    MockERC20  public collateralToken;
    GroveBasin public basin;
    address    public redemptionAddress;

    function setUp() public {
        creditToken       = new MockERC20("creditToken",     "creditToken",     18);
        collateralToken   = new MockERC20("collateralToken", "collateralToken", 18);
        redemptionAddress = makeAddr("redemptionAddress");
        basin             = _deployBasin(address(collateralToken), address(creditToken));
    }

    function test_constructor() public {
        BUIDLTokenRedeemer redeemer = new BUIDLTokenRedeemer(
            address(creditToken), redemptionAddress, address(basin)
        );

        assertEq(redeemer.creditToken(),      address(creditToken));
        assertEq(redeemer.collateralToken(),   address(collateralToken));
        assertEq(redeemer.redemptionAddress(), redemptionAddress);
        assertEq(address(redeemer.basin()),    address(basin));
        assertEq(redeemer.vault(),             redemptionAddress);
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
/*** setUp / tearDown validation tests                                                      ***/
/**********************************************************************************************/

contract BUIDLTokenRedeemerSetUpTests is Test {

    MockERC20          public creditToken;
    MockERC20          public collateralToken;
    GroveBasin         public basin;
    BUIDLTokenRedeemer public redeemer;

    function setUp() public {
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);

        basin = _deployBasin(address(collateralToken), address(creditToken));

        redeemer = new BUIDLTokenRedeemer(
            address(creditToken), makeAddr("redemptionAddress"), address(basin)
        );
    }

    function test_setUp_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.setUp(address(basin));
    }

    function test_setUp_success() public {
        vm.prank(address(basin));
        redeemer.setUp(address(basin));
    }

    function test_tearDown_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.tearDown(address(basin));
    }

    function test_tearDown_success() public {
        vm.prank(address(basin));
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

contract BUIDLTokenRedeemerInitiateRedeemTests is Test {

    MockERC20          public creditToken;
    MockERC20          public collateralToken;
    BUIDLTokenRedeemer public redeemer;
    address            public basin;
    address            public redemptionAddress;

    function setUp() public {
        creditToken       = new MockERC20("creditToken",     "creditToken",     18);
        collateralToken   = new MockERC20("collateralToken", "collateralToken", 18);
        redemptionAddress = makeAddr("redemptionAddress");

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
        assertEq(creditToken.balanceOf(basin),             9000e18);
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

contract BUIDLTokenRedeemerCompleteRedeemTests is Test {

    MockERC20          public collateralToken;
    MockERC20          public creditToken;
    BUIDLTokenRedeemer public redeemer;
    address            public basin;

    function setUp() public {
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        creditToken     = new MockERC20("creditToken",     "creditToken",     18);

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

        redeemer = new BUIDLTokenRedeemer(
            address(creditToken), makeAddr("redemptionAddress"), basin
        );

        collateralToken.mint(address(redeemer), 100_000e18);
    }

    function test_completeRedeem_sendsCollateralToBasin() public {
        uint256 creditTokenAmount = 1000e18;

        uint256 basinBalanceBefore = collateralToken.balanceOf(basin);

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(creditTokenAmount);

        uint256 basinBalanceAfter = collateralToken.balanceOf(basin);

        assertEq(assets,                                       creditTokenAmount);
        assertEq(basinBalanceAfter - basinBalanceBefore,       creditTokenAmount);
    }

    function test_completeRedeem_capsAtBalance() public {
        uint256 redeemerBalance = collateralToken.balanceOf(address(redeemer));
        uint256 creditTokenAmount = redeemerBalance + 1000e18;

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(creditTokenAmount);

        assertEq(assets, redeemerBalance);
        assertEq(collateralToken.balanceOf(address(redeemer)), 0);
    }

    function test_completeRedeem_multipleCompletes() public {
        vm.startPrank(basin);
        redeemer.completeRedeem(100e18);

        uint256 balanceAfterFirst = collateralToken.balanceOf(basin);

        redeemer.completeRedeem(200e18);

        uint256 balanceAfterSecond = collateralToken.balanceOf(basin);
        vm.stopPrank();

        assertEq(balanceAfterSecond - balanceAfterFirst, 200e18);
    }

    function test_completeRedeem_emitsEvent() public {
        uint256 creditTokenAmount = 1000e18;

        vm.expectEmit(address(redeemer));
        emit ITokenRedeemer.RedeemCompleted(creditTokenAmount, creditTokenAmount);

        vm.prank(basin);
        redeemer.completeRedeem(creditTokenAmount);
    }

    function test_completeRedeem_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert(ITokenRedeemer.OnlyBasin.selector);
        redeemer.completeRedeem(1000e18);
    }

}
