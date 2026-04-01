// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer } from "src/redeemers/JTRSYTokenRedeemer.sol";
import { IAsyncVaultLike }   from "src/interfaces/IAsyncVaultLike.sol";

import { JTRSYForkTestBase } from "test/fork/JTRSYForkTest.sol";

interface IEscrowLike {
    function approve(address token, address spender, uint256 amount) external;
}

abstract contract JTRSYGroveBasinForkTestBase is JTRSYForkTestBase {

    address public constant CENTRIFUGE_JTRSY_VAULT = Ethereum.CENTRIFUGE_JTRSY;

    JTRSYTokenRedeemer public tokenRedeemer;

    function setUp() public virtual override {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());

        _initTokens();
        _initRateProviders();

        groveBasin = new GroveBasin(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(),       owner);

        groveBasin.setMaxSwapSizeBounds(0, 10_000_000_000_000_000e18);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);

        pocket = address(groveBasin);
        vm.stopPrank();

        _postDeploy();

        // Predict redeemer address and allowlist it before deployment
        address predictedRedeemer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        _addToJTRSYAllowlist(predictedRedeemer);

        tokenRedeemer = new JTRSYTokenRedeemer(
            address(creditToken),
            CENTRIFUGE_JTRSY_VAULT,
            address(groveBasin)
        );

        vm.prank(owner);
        groveBasin.addTokenRedeemer(address(tokenRedeemer));

        vm.label(address(swapToken),       "swapToken");
        vm.label(address(collateralToken), "collateralToken");
        vm.label(address(creditToken),     "creditToken");
        vm.label(address(groveBasin),      "groveBasin");
        vm.label(address(tokenRedeemer),   "tokenRedeemer");
        vm.label(CENTRIFUGE_JTRSY_VAULT,   "centrifugeVault");
    }

}

/**********************************************************************************************/
/*** Constructor tests                                                                      ***/
/**********************************************************************************************/

contract JTRSYGroveBasinForkTest_Constructor is JTRSYGroveBasinForkTestBase {

    function test_constructor_withLiveVault() public view {
        assertEq(tokenRedeemer.vault(),       CENTRIFUGE_JTRSY_VAULT);
        assertEq(tokenRedeemer.creditToken(), address(creditToken));

        assertEq(groveBasin.swapToken(),       address(swapToken));
        assertEq(groveBasin.collateralToken(), address(collateralToken));
        assertEq(groveBasin.creditToken(),     address(creditToken));

        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), address(tokenRedeemer)));
    }

}

/**********************************************************************************************/
/*** initiateRedeem tests                                                                   ***/
/**********************************************************************************************/

contract JTRSYGroveBasinForkTest_InitiateRedeem is JTRSYGroveBasinForkTestBase {

    address public issuer = makeAddr("issuer");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), issuer);
        vm.stopPrank();
    }

    function test_initiateRedeem_liveVault() public {
        uint256 amount = 1000e6;  // JTRSY has 6 decimals

        // Deal JTRSY to basin (as creditToken held by the basin itself)
        _dealJTRSY(address(groveBasin), amount);

        uint256 basinBalanceBefore = IERC20(JTRSY_TOKEN).balanceOf(address(groveBasin));
        assertEq(basinBalanceBefore, amount);

        // Call initiateRedeem as owner - redeemer pulls from basin, then calls vault
        vm.prank(issuer);
        groveBasin.initiateRedeem(address(tokenRedeemer), amount);

        // After requestRedeem, JTRSY should have been transferred from basin through redeemer
        // to the vault's escrow (basin -> redeemer -> vault escrow)
        uint256 basinBalanceAfter = IERC20(JTRSY_TOKEN).balanceOf(address(groveBasin));
        assertEq(basinBalanceAfter, 0);
    }

    function test_initiateRedeem_withAddress_liveVault() public {
        uint256 amount = 1000e6;

        _dealJTRSY(address(groveBasin), amount);

        vm.prank(issuer);
        groveBasin.initiateRedeem(address(tokenRedeemer), amount);

        uint256 basinBalanceAfter = IERC20(JTRSY_TOKEN).balanceOf(address(groveBasin));
        assertEq(basinBalanceAfter, 0);
    }

}

/**********************************************************************************************/
/*** Swap and deposit tests                                                                 ***/
/**********************************************************************************************/

contract JTRSYGroveBasinForkTest_SwapAndDeposit is JTRSYGroveBasinForkTestBase {

    address public depositor = makeAddr("depositor");
    address public swapper   = makeAddr("swapper");
    address public receiver  = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _addToJTRSYAllowlist(swapper);
        _addToJTRSYAllowlist(receiver);

        // Seed GroveBasin with liquidity
        _deposit(address(collateralToken), makeAddr("lp1"), 100_000e6);
        _deposit(JTRSY_TOKEN,              makeAddr("lp2"), 100_000e6);
    }

    function test_swapAndDeposit_liveVault() public {
        // Test deposit with USDC (collateralToken)
        uint256 depositAmount = 1000e6;
        _deposit(address(collateralToken), depositor, depositAmount);

        assertGt(groveBasin.shares(depositor), 0);

        // Test swap: USDC -> JTRSY
        uint256 swapAmount = 500e6;
        _dealToken(address(collateralToken), swapper, swapAmount);

        vm.startPrank(swapper);
        IERC20(address(collateralToken)).approve(address(groveBasin), swapAmount);

        uint256 expectedOut = groveBasin.previewSwapExactIn(address(collateralToken), JTRSY_TOKEN, swapAmount);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(
            address(collateralToken),
            JTRSY_TOKEN,
            swapAmount,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), amountOut);
    }

}
