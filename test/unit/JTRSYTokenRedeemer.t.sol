// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer } from "src/JTRSYTokenRedeemer.sol";
import { ITokenRedeemer }     from "src/interfaces/ITokenRedeemer.sol";

import { MockAsyncVault }   from "test/mocks/MockAsyncVault.sol";
import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerConstructorTests is Test {

    MockERC20      public creditToken;
    MockAsyncVault public vault;

    function setUp() public {
        creditToken = new MockERC20("creditToken", "creditToken", 18);
        vault       = new MockAsyncVault(address(0), address(creditToken));
    }

    function test_constructor() public {
        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        assertEq(redeemer.creditToken(), address(creditToken));
        assertEq(redeemer.vault(),       address(vault));
    }

    function test_constructor_invalidCreditToken() public {
        vm.expectRevert("JTRSYTokenRedeemer/invalid-creditToken");
        new JTRSYTokenRedeemer(address(0), address(vault));
    }

    function test_constructor_invalidVault() public {
        vm.expectRevert("JTRSYTokenRedeemer/invalid-vault");
        new JTRSYTokenRedeemer(address(creditToken), address(0));
    }

}

/**********************************************************************************************/
/*** setUp validation tests                                                                 ***/
/**********************************************************************************************/

contract JTRSYTokenRedeemerSetUpTests is Test {

    function test_setUp_setsBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        vm.prank(address(basin));
        redeemer.setUp(address(basin));

        assertEq(redeemer.basin(), address(basin));
    }

    function test_setUp_alreadySetUp() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        GroveBasin basin1 = _deployBasin(address(collateralToken), address(creditToken));
        GroveBasin basin2 = _deployBasin(address(collateralToken), address(creditToken));

        vm.prank(address(basin1));
        redeemer.setUp(address(basin1));

        vm.prank(address(basin2));
        vm.expectRevert("JTRSYTokenRedeemer/already-set-up");
        redeemer.setUp(address(basin2));
    }

    function test_setUp_creditTokenMismatch() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 otherCreditToken = new MockERC20("otherCreditToken", "otherCreditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(otherCreditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        // Deploy a basin with a different creditToken
        GroveBasin basin = _deployBasin(address(collateralToken), address(otherCreditToken));

        vm.prank(address(basin));
        vm.expectRevert("JTRSYTokenRedeemer/creditToken-mismatch");
        redeemer.setUp(address(basin));
    }

    function test_setUp_collateralAssetMismatch() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockERC20 otherAsset      = new MockERC20("otherAsset", "otherAsset", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(otherAsset), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        vm.prank(address(basin));
        vm.expectRevert("JTRSYTokenRedeemer/collateral-asset-mismatch");
        redeemer.setUp(address(basin));
    }

    function test_setUp_notAllowlisted() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        vm.prank(address(basin));
        vm.expectRevert("JTRSYTokenRedeemer/not-allowlisted");
        redeemer.setUp(address(basin));
    }

    function test_setUp_onlyBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert("JTRSYTokenRedeemer/only-basin");
        redeemer.setUp(address(basin));
    }

    function test_tearDown_onlyBasin() public {
        MockERC20 creditToken     = new MockERC20("creditToken", "creditToken", 18);
        MockERC20 collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        MockAsyncVault vault      = new MockAsyncVault(address(collateralToken), address(creditToken));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        GroveBasin basin = _deployBasin(address(collateralToken), address(creditToken));

        vm.prank(address(basin));
        redeemer.setUp(address(basin));

        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert("JTRSYTokenRedeemer/only-basin");
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
        creditToken     = new MockERC20("creditToken", "creditToken", 18);
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));
        redeemer        = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        MockERC20 swapToken = new MockERC20("swapToken", "swapToken", 6);
        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();
        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        basin = address(new GroveBasin(
            address(this),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        ));

        vm.prank(basin);
        redeemer.setUp(basin);

        creditToken.mint(basin, 10_000e18);
        vm.prank(basin);
        creditToken.approve(address(redeemer), type(uint256).max);
    }

    function test_initiateRedeem() public {
        uint256 amount = 1000e18;

        vm.prank(basin);
        redeemer.initiateRedeem(amount);

        assertEq(vault.lastRequestRedeemShares(),     amount);
        assertEq(vault.lastRequestRedeemController(), address(redeemer));
        assertEq(vault.lastRequestRedeemOwner(),      address(redeemer));
        assertEq(creditToken.balanceOf(address(redeemer)), amount);
    }

    function test_initiateRedeem_multipleAmounts() public {
        vm.startPrank(basin);
        redeemer.initiateRedeem(100e18);
        assertEq(vault.lastRequestRedeemShares(), 100e18);
        assertEq(creditToken.balanceOf(address(redeemer)), 100e18);

        redeemer.initiateRedeem(200e18);
        assertEq(vault.lastRequestRedeemShares(), 200e18);
        assertEq(creditToken.balanceOf(address(redeemer)), 300e18);
        vm.stopPrank();
    }

    function test_initiateRedeem_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert("JTRSYTokenRedeemer/only-basin");
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
        creditToken     = new MockERC20("creditToken", "creditToken", 18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));
        redeemer        = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        vault.__setPermissioned(address(redeemer), true);

        MockERC20 swapToken = new MockERC20("swapToken", "swapToken", 6);
        MockRateProvider swapRp       = new MockRateProvider();
        MockRateProvider collateralRp = new MockRateProvider();
        MockRateProvider creditRp     = new MockRateProvider();
        swapRp.__setConversionRate(1e27);
        collateralRp.__setConversionRate(1e27);
        creditRp.__setConversionRate(1e27);

        basin = address(new GroveBasin(
            address(this),
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapRp),
            address(collateralRp),
            address(creditRp)
        ));

        vm.prank(basin);
        redeemer.setUp(basin);

        // Fund vault with collateral so it can pay out on redeem
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_completeRedeem_sendsCollateralToCaller() public {
        uint256 creditTokenAmount = 1000e18;

        uint256 callerBalanceBefore = collateralToken.balanceOf(basin);

        vm.prank(basin);
        uint256 assets = redeemer.completeRedeem(creditTokenAmount);

        uint256 callerBalanceAfter = collateralToken.balanceOf(basin);

        assertEq(assets, creditTokenAmount);
        assertEq(callerBalanceAfter - callerBalanceBefore, creditTokenAmount);
        assertEq(vault.lastRedeemShares(),     creditTokenAmount);
        assertEq(vault.lastRedeemReceiver(),   address(redeemer));
        assertEq(vault.lastRedeemController(), address(redeemer));
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

    function test_completeRedeem_onlyBasin() public {
        address notBasin = makeAddr("notBasin");

        vm.prank(notBasin);
        vm.expectRevert("JTRSYTokenRedeemer/only-basin");
        redeemer.completeRedeem(1000e18);
    }

}
