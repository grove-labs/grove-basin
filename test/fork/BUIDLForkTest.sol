// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ForkTestBase }     from "test/fork/ForkTestBase.sol";
import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

interface IBUIDLLike {
    function owner() external view returns (address);
    function getDSService(uint256 serviceId) external view returns (address);
    function issueTokensWithNoCompliance(address to, uint256 value) external;
    function burn(address who, uint256 value, string calldata reason) external;
    function preTransferCheck(address from, address to, uint256 value)
        external view returns (uint256 code, string memory reason);
    function setCap(uint256 cap) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function COMPLIANCE_SERVICE() external view returns (uint256);
    function WALLET_REGISTRAR() external view returns (uint256);
    function REGISTRY_SERVICE() external view returns (uint256);
}

contract NoOpFallback {
    fallback() external payable {
        assembly {
            // Return 256 zero-bytes so that the ABI decoder never reverts due
            // to insufficient return-data length.  For void functions the data
            // is simply ignored; for bool-returning functions 0 is "false" but
            // validation functions in the Securitize stack treat non-revert as
            // success; for (uint256,string) it decodes as (0,"") = "valid".
            return(0, 256)
        }
    }
}

abstract contract BUIDLForkTestBase is ForkTestBase {

    IBUIDLLike public buidl = IBUIDLLike(Ethereum.BUIDL);

    address public buidlMaster;
    address public complianceService;
    address public walletRegistrar;
    address public registryService;

    bytes internal originalComplianceCode;

    function _initTokens() internal override {
        swapToken       = IERC20(Ethereum.USDS);
        collateralToken = IERC20(Ethereum.USDC);
        creditToken     = IERC20(Ethereum.BUIDL);
    }

    function _initRateProviders() internal override {
        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1e27);
    }

    function _postDeploy() internal override {
        buidlMaster       = buidl.owner();
        complianceService = buidl.getDSService(buidl.COMPLIANCE_SERVICE());
        walletRegistrar   = buidl.getDSService(buidl.WALLET_REGISTRAR());
        registryService   = buidl.getDSService(buidl.REGISTRY_SERVICE());

        originalComplianceCode = complianceService.code;

        vm.prank(buidlMaster);
        buidl.setCap(type(uint256).max);

        _mockBUIDLWalletRegistrar();
        _mockBUIDLCompliance();
    }

    /**********************************************************************************************/
    /*** Securitize compliance mocking                                                          ***/
    /**********************************************************************************************/

    // The Securitize DSToken checks isWallet() on the registry service before
    // issuing or transferring tokens.  Mock it to accept any address.
    function _mockBUIDLWalletRegistrar() internal {
        vm.mockCall(
            walletRegistrar,
            abi.encodeWithSignature("isWallet(address)"),
            abi.encode(true)
        );
        vm.mockCall(
            registryService,
            abi.encodeWithSignature("isWallet(address)"),
            abi.encode(true)
        );
    }

    // The DSToken's postTransferImpl delegates compliance enforcement to an external
    // ComplianceService contract.  Replace it with a no-op so that all transfers
    // and issuances succeed in tests without real KYC registration.
    function _mockBUIDLCompliance() internal {
        // Replace the compliance service with a contract whose fallback always
        // returns successfully.  This bypasses all Securitize compliance logic
        // (validateTransfer, recordTransfer, etc.).
        vm.etch(complianceService, type(NoOpFallback).runtimeCode);
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _dealToken(address token, address to, uint256 amount) internal override {
        if (token == Ethereum.BUIDL) {
            _dealBUIDL(to, amount);
        } else {
            deal(token, to, amount);
        }
    }

    // Replicates a real BUIDL subscription: the Securitize master mints tokens.
    function _dealBUIDL(address to, uint256 amount) internal {
        vm.prank(buidlMaster);
        buidl.issueTokensWithNoCompliance(to, amount);
    }

    // Replicates a daily yield distribution (rebase).
    // In practice Securitize calls bulkIssuance / issueTokens to each holder.
    function _simulateYieldDistribution(address holder, uint256 yieldAmount) internal {
        vm.prank(buidlMaster);
        buidl.issueTokensWithNoCompliance(holder, yieldAmount);
    }

}

/**********************************************************************************************/
/*** Deployment and basic sanity tests                                                      ***/
/**********************************************************************************************/

contract BUIDLForkTest_Deployment is BUIDLForkTestBase {

    function test_deployment() public view {
        assertEq(address(groveBasin.swapToken()),       Ethereum.USDS);
        assertEq(address(groveBasin.collateralToken()), Ethereum.USDC);
        assertEq(address(groveBasin.creditToken()),     Ethereum.BUIDL);
        assertEq(groveBasin.pocket(),                   pocket);
    }

}

/**********************************************************************************************/
/*** Deposit tests (Subscription)                                                           ***/
/**********************************************************************************************/

contract BUIDLForkTest_Deposit is BUIDLForkTestBase {

    address public depositor = makeAddr("depositor");

    function test_deposit_creditToken() public {
        uint256 amount = 1000e6;  // BUIDL has 6 decimals
        _deposit(Ethereum.BUIDL, depositor, amount);

        assertGt(groveBasin.shares(depositor), 0);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(address(groveBasin)), amount);
    }

    function test_deposit_collateralToken() public {
        uint256 amount = 1000e6;
        _deposit(Ethereum.USDC, depositor, amount);

        assertGt(groveBasin.shares(depositor), 0);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(groveBasin)), amount);
    }

    function test_deposit_swapToken() public {
        uint256 amount = 1000e18;
        _deposit(Ethereum.USDS, depositor, amount);

        assertGt(groveBasin.shares(depositor), 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(pocket), amount);
    }

    function test_deposit_allTokens() public {
        _deposit(Ethereum.USDS, depositor, 1000e18);
        uint256 sharesAfterFirst = groveBasin.shares(depositor);

        _deposit(Ethereum.USDC, depositor, 1000e6);
        uint256 sharesAfterSecond = groveBasin.shares(depositor);

        _deposit(Ethereum.BUIDL, depositor, 1000e6);
        uint256 sharesAfterThird = groveBasin.shares(depositor);

        assertGt(sharesAfterSecond, sharesAfterFirst);
        assertGt(sharesAfterThird, sharesAfterSecond);
    }

}

/**********************************************************************************************/
/*** Withdraw tests (Redemption)                                                            ***/
/**********************************************************************************************/

contract BUIDLForkTest_Withdraw is BUIDLForkTestBase {

    address public depositor = makeAddr("depositor");
    address public receiver  = makeAddr("receiver");

    function test_withdraw_creditToken() public {
        uint256 depositAmount = 1000e6;
        _deposit(Ethereum.BUIDL, depositor, depositAmount);

        uint256 sharesBefore = groveBasin.shares(depositor);

        _withdraw(Ethereum.BUIDL, depositor, receiver, depositAmount);

        assertLt(groveBasin.shares(depositor), sharesBefore);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(receiver), depositAmount);
    }

    function test_withdraw_collateralToken() public {
        uint256 depositAmount = 1000e6;
        _deposit(Ethereum.USDC, depositor, depositAmount);

        uint256 sharesBefore = groveBasin.shares(depositor);

        _withdraw(Ethereum.USDC, depositor, receiver, depositAmount);

        assertLt(groveBasin.shares(depositor), sharesBefore);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), depositAmount);
    }

    function test_withdraw_swapToken() public {
        uint256 depositAmount = 1000e18;
        _deposit(Ethereum.USDS, depositor, depositAmount);

        uint256 sharesBefore = groveBasin.shares(depositor);

        _withdraw(Ethereum.USDS, depositor, receiver, depositAmount);

        assertLt(groveBasin.shares(depositor), sharesBefore);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), depositAmount);
    }

}

/**********************************************************************************************/
/*** SwapExactIn tests                                                                      ***/
/**********************************************************************************************/

contract BUIDLForkTest_SwapExactIn is BUIDLForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDC, makeAddr("lp2"), 100_000e6);
        _deposit(Ethereum.BUIDL, makeAddr("lp3"), 100_000e6);
    }

    function test_swapExactIn_swapTokenToCreditToken() public {
        uint256 amountIn = 1000e18;
        _dealToken(Ethereum.USDS, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(Ethereum.USDS, Ethereum.BUIDL, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.USDS, Ethereum.BUIDL, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(receiver), amountOut);
        assertEq(IERC20(Ethereum.USDS).balanceOf(swapper), 0);
    }

    function test_swapExactIn_creditTokenToSwapToken() public {
        uint256 amountIn = 1000e6;
        _dealToken(Ethereum.BUIDL, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.BUIDL).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(Ethereum.BUIDL, Ethereum.USDS, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.BUIDL, Ethereum.USDS, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_collateralTokenToCreditToken() public {
        uint256 amountIn = 1000e6;
        _dealToken(Ethereum.USDC, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDC).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(Ethereum.USDC, Ethereum.BUIDL, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.USDC, Ethereum.BUIDL, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_creditTokenToCollateralToken() public {
        uint256 amountIn = 1000e6;
        _dealToken(Ethereum.BUIDL, swapper, amountIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.BUIDL).approve(address(groveBasin), amountIn);

        uint256 expectedOut = groveBasin.previewSwapExactIn(Ethereum.BUIDL, Ethereum.USDC, amountIn);
        assertGt(expectedOut, 0);

        uint256 amountOut = groveBasin.swapExactIn(Ethereum.BUIDL, Ethereum.USDC, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

    function test_swapExactIn_invalidSwap_swapTokenToCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.swapExactIn(Ethereum.USDS, Ethereum.USDC, 100e18, 0, receiver, 0);
    }

    function test_swapExactIn_invalidSwap_collateralTokenToSwapToken() public {
        vm.expectRevert("GroveBasin/invalid-swap");
        groveBasin.swapExactIn(Ethereum.USDC, Ethereum.USDS, 100e6, 0, receiver, 0);
    }

}

/**********************************************************************************************/
/*** SwapExactOut tests                                                                     ***/
/**********************************************************************************************/

contract BUIDLForkTest_SwapExactOut is BUIDLForkTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);
        _deposit(Ethereum.USDC, makeAddr("lp2"), 100_000e6);
        _deposit(Ethereum.BUIDL, makeAddr("lp3"), 100_000e6);
    }

    function test_swapExactOut_swapTokenToCreditToken() public {
        uint256 amountOut = 1000e6;
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.USDS, Ethereum.BUIDL, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(Ethereum.USDS, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(Ethereum.USDS, Ethereum.BUIDL, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_creditTokenToSwapToken() public {
        uint256 amountOut = 1000e18;
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.BUIDL, Ethereum.USDS, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(Ethereum.BUIDL, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.BUIDL).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(Ethereum.BUIDL, Ethereum.USDS, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_collateralTokenToCreditToken() public {
        uint256 amountOut = 1000e6;
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.USDC, Ethereum.BUIDL, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(Ethereum.USDC, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDC).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(Ethereum.USDC, Ethereum.BUIDL, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.BUIDL).balanceOf(receiver), amountOut);
    }

    function test_swapExactOut_creditTokenToCollateralToken() public {
        uint256 amountOut = 1000e6;
        uint256 expectedIn = groveBasin.previewSwapExactOut(Ethereum.BUIDL, Ethereum.USDC, amountOut);
        assertGt(expectedIn, 0);

        _dealToken(Ethereum.BUIDL, swapper, expectedIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.BUIDL).approve(address(groveBasin), expectedIn);

        uint256 amountIn = groveBasin.swapExactOut(Ethereum.BUIDL, Ethereum.USDC, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

}

/**********************************************************************************************/
/*** Yield distribution tests (Rebase)                                                      ***/
/**********************************************************************************************/

contract BUIDLForkTest_YieldDistribution is BUIDLForkTestBase {

    address public depositor  = makeAddr("depositor");
    address public depositor2 = makeAddr("depositor2");

    function test_yieldDistribution_increasesTotalAssets() public {
        _deposit(Ethereum.BUIDL, depositor, 10_000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        _simulateYieldDistribution(address(groveBasin), 10e6);

        assertGt(groveBasin.totalAssets(), totalAssetsBefore);
    }

    function test_yieldDistribution_increasesShareValue() public {
        _deposit(Ethereum.BUIDL, depositor, 10_000e6);

        uint256 sharesBefore        = groveBasin.shares(depositor);
        uint256 valuePerShareBefore = groveBasin.convertToAssetValue(1e18);

        _simulateYieldDistribution(address(groveBasin), 10e6);

        assertEq(groveBasin.shares(depositor), sharesBefore);
        assertGt(groveBasin.convertToAssetValue(1e18), valuePerShareBefore);
    }

    function test_yieldDistribution_depositorCanWithdrawMore() public {
        uint256 depositAmount = 10_000e6;
        _deposit(Ethereum.BUIDL, depositor, depositAmount);

        uint256 yieldAmount = 100e6;
        _simulateYieldDistribution(address(groveBasin), yieldAmount);

        address receiver = makeAddr("receiver");

        _withdraw(Ethereum.BUIDL, depositor, receiver, depositAmount + yieldAmount);

        assertEq(IERC20(Ethereum.BUIDL).balanceOf(receiver), depositAmount + yieldAmount);
    }

    function test_yieldDistribution_multipleDepositors_fairSharing() public {
        _deposit(Ethereum.BUIDL, depositor,  10_000e6);
        _deposit(Ethereum.BUIDL, depositor2, 10_000e6);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        _simulateYieldDistribution(address(groveBasin), 20e6);

        assertGt(groveBasin.totalAssets(), totalAssetsBefore);
        assertEq(groveBasin.shares(depositor), groveBasin.shares(depositor2));
    }

    function test_depositAfterYieldDistribution_fewerShares() public {
        _deposit(Ethereum.BUIDL, depositor, 10_000e6);

        _simulateYieldDistribution(address(groveBasin), 100e6);

        _deposit(Ethereum.BUIDL, depositor2, 10_000e6);

        assertLt(groveBasin.shares(depositor2), groveBasin.shares(depositor));
    }

}

/**********************************************************************************************/
/*** Allowlist enforcement tests                                                            ***/
/**********************************************************************************************/

contract BUIDLForkTest_Allowlist is BUIDLForkTestBase {

    address public depositor = makeAddr("depositor");
    address public nonMember = makeAddr("nonMember");

    function _restoreRealCompliance() internal {
        vm.clearMockedCalls();
        vm.etch(complianceService, originalComplianceCode);
    }

    function test_withdraw_creditToken_toNonMember_reverts() public {
        _deposit(Ethereum.BUIDL, depositor, 1000e6);

        _restoreRealCompliance();

        vm.prank(depositor);
        vm.expectRevert();
        groveBasin.withdraw(Ethereum.BUIDL, nonMember, 1000e6);
    }

    function test_swap_creditTokenOut_toNonMember_reverts() public {
        _deposit(Ethereum.BUIDL, makeAddr("lp"), 100_000e6);

        uint256 amountIn = 1000e18;
        _dealToken(Ethereum.USDS, depositor, amountIn);

        _restoreRealCompliance();

        vm.startPrank(depositor);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn);

        vm.expectRevert();
        groveBasin.swapExactIn(Ethereum.USDS, Ethereum.BUIDL, amountIn, 0, nonMember, 0);
        vm.stopPrank();
    }

}
