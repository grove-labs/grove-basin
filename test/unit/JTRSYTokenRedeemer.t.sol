// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer } from "src/JTRSYTokenRedeemer.sol";
import { ITokenRedeemer }     from "src/interfaces/ITokenRedeemer.sol";
import { MockAsyncVault }     from "test/mocks/MockAsyncVault.sol";
import { MockRateProvider }   from "test/mocks/MockRateProvider.sol";

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
    MockAsyncVault       public vault;
    JTRSYTokenRedeemer   public redeemer;

    function setUp() public {
        creditToken = new MockERC20("creditToken", "creditToken", 18);
        vault       = new MockAsyncVault(address(0), address(creditToken));
        redeemer    = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        creditToken.mint(address(this), 10_000e18);
        creditToken.approve(address(redeemer), type(uint256).max);
    }

    function test_initiateRedeem() public {
        uint256 amount = 1000e18;

        redeemer.initiateRedeem(amount);

        assertEq(vault.lastRequestRedeemShares(),     amount);
        assertEq(vault.lastRequestRedeemController(), address(redeemer));
        assertEq(vault.lastRequestRedeemOwner(),      address(redeemer));
        assertEq(creditToken.balanceOf(address(redeemer)), amount);
    }

    function test_initiateRedeem_multipleAmounts() public {
        redeemer.initiateRedeem(100e18);
        assertEq(vault.lastRequestRedeemShares(), 100e18);
        assertEq(creditToken.balanceOf(address(redeemer)), 100e18);

        redeemer.initiateRedeem(200e18);
        assertEq(vault.lastRequestRedeemShares(), 200e18);
        assertEq(creditToken.balanceOf(address(redeemer)), 300e18);
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

    function setUp() public {
        collateralToken = new MockERC20("collateralToken", "collateralToken", 18);
        creditToken     = new MockERC20("creditToken", "creditToken", 18);
        vault           = new MockAsyncVault(address(collateralToken), address(creditToken));
        redeemer        = new JTRSYTokenRedeemer(address(creditToken), address(vault));

        // Fund vault with collateral so it can pay out on redeem
        collateralToken.mint(address(vault), 100_000e18);
    }

    function test_completeRedeem_sendsCollateralToCaller() public {
        uint256 creditTokenAmount = 1000e18;

        uint256 callerBalanceBefore = collateralToken.balanceOf(address(this));

        uint256 assets = redeemer.completeRedeem(creditTokenAmount);

        uint256 callerBalanceAfter = collateralToken.balanceOf(address(this));

        assertEq(assets, creditTokenAmount);
        assertEq(callerBalanceAfter - callerBalanceBefore, creditTokenAmount);
        assertEq(vault.lastRedeemShares(),     creditTokenAmount);
        assertEq(vault.lastRedeemReceiver(),   address(redeemer));
        assertEq(vault.lastRedeemController(), address(redeemer));
    }

    function test_completeRedeem_multipleCompletes() public {
        redeemer.completeRedeem(100e18);

        uint256 balanceAfterFirst = collateralToken.balanceOf(address(this));

        redeemer.completeRedeem(200e18);

        uint256 balanceAfterSecond = collateralToken.balanceOf(address(this));

        assertEq(balanceAfterSecond - balanceAfterFirst, 200e18);
    }

}
