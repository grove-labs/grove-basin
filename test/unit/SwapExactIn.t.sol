// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract GroveBasinSwapExactInFailureTests is GroveBasinTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Needed for boundary success conditions
        usdc.mint(pocket, 100e6);
        creditToken.mint(address(groveBasin), 100e18);
    }

    function test_swapExactIn_amountZero() public {
        vm.expectRevert("GroveBasin/invalid-amountIn");
        groveBasin.swapExactIn(address(usdc), address(creditToken), 0, 0, receiver, 0);
    }

    function test_swapExactIn_receiverZero() public {
        vm.expectRevert("GroveBasin/invalid-receiver");
        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18, address(0), 0);
    }

    function test_swapExactIn_invalid_assetIn() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.swapExactIn(makeAddr("other-token"), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_invalid_assetOut() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.swapExactIn(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothUsdc() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.swapExactIn(address(usdc), address(usdc), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothCollateralToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.swapExactIn(address(collateralToken), address(collateralToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothCreditToken() public {
        vm.expectRevert("GroveBasin/invalid-asset");
        groveBasin.swapExactIn(address(creditToken), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_minAmountOutBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(groveBasin), 100e6);

        uint256 expectedAmountOut = groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("GroveBasin/amountOut-too-low");
        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18 + 1, receiver, 0);

        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(groveBasin), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18, receiver, 0);

        usdc.approve(address(groveBasin), 100e6);

        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(groveBasin), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18, receiver, 0);

        usdc.mint(swapper, 1);

        groveBasin.swapExactIn(address(usdc), address(creditToken), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientGroveBasinBalanceBoundary() public {
        // NOTE: Using 2 instead of 1 here because 1/1.25 rounds to 0, 2/1.25 rounds to 1
        //       this is because the conversion rate is divided out before the precision conversion
        //       is done.
        usdc.mint(swapper, 125e6 + 2);

        vm.startPrank(swapper);

        usdc.approve(address(groveBasin), 125e6 + 2);

        uint256 expectedAmountOut = groveBasin.previewSwapExactIn(address(usdc), address(creditToken), 125e6 + 2);

        assertEq(expectedAmountOut, 100.000001e18);  // More than balance of creditToken

        vm.expectRevert("SafeERC20/transfer-failed");
        groveBasin.swapExactIn(address(usdc), address(creditToken), 125e6 + 2, 100e18, receiver, 0);

        groveBasin.swapExactIn(address(usdc), address(creditToken), 125e6, 100e18, receiver, 0);
    }

}

contract GroveBasinSwapExactInSuccessTestsBase is GroveBasinTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Mint 100x higher than max amount for each token (max conversion rate)
        // Covers both lower and upper bounds of conversion rate (1% to 10,000% are both 100x)
        collateralToken.mint(address(groveBasin),  COLLATERAL_TOKEN_MAX  * 100);
        usdc.mint(pocket,        USDC_TOKEN_MAX  * 100);
        creditToken.mint(address(groveBasin), CREDIT_TOKEN_MAX * 100);
    }

    function _swapExactInTest(
        MockERC20 assetIn,
        MockERC20 assetOut,
        uint256 amountIn,
        uint256 amountOut,
        address swapper_,
        address receiver_
    ) internal {
        // 100 trillion of each token corresponds to original mint amount
        uint256 groveBasinAssetInBalance  = 100_000_000_000_000 * 10 ** assetIn.decimals();
        uint256 groveBasinAssetOutBalance = 100_000_000_000_000 * 10 ** assetOut.decimals();

        address assetInCustodian  = address(assetIn)  == address(usdc) ? pocket : address(groveBasin);
        address assetOutCustodian = address(assetOut) == address(usdc) ? pocket : address(groveBasin);

        assetIn.mint(swapper_, amountIn);

        vm.startPrank(swapper_);

        assetIn.approve(address(groveBasin), amountIn);

        assertEq(assetIn.allowance(swapper_, address(groveBasin)), amountIn);

        assertEq(assetIn.balanceOf(swapper_),         amountIn);
        assertEq(assetIn.balanceOf(assetInCustodian), groveBasinAssetInBalance);

        assertEq(assetOut.balanceOf(receiver_),         0);
        assertEq(assetOut.balanceOf(assetOutCustodian), groveBasinAssetOutBalance);

        uint256 returnedAmountOut = groveBasin.swapExactIn(
            address(assetIn),
            address(assetOut),
            amountIn,
            amountOut,
            receiver_,
            0
        );

        assertEq(returnedAmountOut, amountOut);

        assertEq(assetIn.allowance(swapper_, address(groveBasin)), 0);

        assertEq(assetIn.balanceOf(swapper_),         0);
        assertEq(assetIn.balanceOf(assetInCustodian), groveBasinAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver_),         amountOut);
        assertEq(assetOut.balanceOf(assetOutCustodian), groveBasinAssetOutBalance - amountOut);
    }

}

contract GroveBasinSwapExactInCollateralTokenAssetInTests is GroveBasinSwapExactInSuccessTestsBase {

    function test_swapExactIn_collateralTokenToUsdc_sameReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(collateralToken, usdc, 100e18, 100e6, swapper, swapper);
    }

    function test_swapExactIn_collateralTokenToCreditToken_sameReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(collateralToken, creditToken, 100e18, 80e18, swapper, swapper);
    }

    function test_swapExactIn_collateralTokenToUsdc_differentReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(collateralToken, usdc, 100e18, 100e6, swapper, receiver);
    }

    function test_swapExactIn_collateralTokenToCreditToken_differentReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(collateralToken, creditToken, 100e18, 80e18, swapper, receiver);
    }

    function testFuzz_swapExactIn_collateralTokenToUsdc(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(groveBasin));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(groveBasin));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, COLLATERAL_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn / 1e12;
        _swapExactInTest(collateralToken, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_collateralTokenToCreditToken(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(groveBasin));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(groveBasin));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       COLLATERAL_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate
        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        _swapExactInTest(collateralToken, creditToken, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract GroveBasinSwapExactInUsdcAssetInTests is GroveBasinSwapExactInSuccessTestsBase {

    function test_swapExactIn_usdcToCollateralToken_sameReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(usdc, collateralToken, 100e6, 100e18, swapper, swapper);
    }

    function test_swapExactIn_usdcToCreditToken_sameReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(usdc, creditToken, 100e6, 80e18, swapper, swapper);
    }

    function test_swapExactIn_usdcToCollateralToken_differentReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(usdc, collateralToken, 100e6, 100e18, swapper, receiver);
    }

    function test_swapExactIn_usdcToCreditToken_differentReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(usdc, creditToken, 100e6, 80e18, swapper, receiver);
    }

    function testFuzz_swapExactIn_usdcToCollateralToken(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(groveBasin));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(groveBasin));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, USDC_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn * 1e12;
        _swapExactInTest(usdc, collateralToken, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_usdcToCreditToken(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(groveBasin));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(groveBasin));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        _swapExactInTest(usdc, creditToken, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract GroveBasinSwapExactInCreditTokenAssetInTests is GroveBasinSwapExactInSuccessTestsBase {

    function test_swapExactIn_creditTokenToCollateralToken_sameReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(creditToken, collateralToken, 100e18, 125e18, swapper, swapper);
    }

    function test_swapExactIn_creditTokenToUsdc_sameReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(creditToken, usdc, 100e18, 125e6, swapper, swapper);
    }

    function test_swapExactIn_creditTokenToCollateralToken_differentReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(creditToken, collateralToken, 100e18, 125e18, swapper, receiver);
    }

    function test_swapExactIn_creditTokenToUsdc_differentReceiver() public assertAtomicGroveBasinValueDoesNotChange {
        _swapExactInTest(creditToken, usdc, 100e18, 125e6, swapper, receiver);
    }

    function testFuzz_swapExactIn_creditTokenToCollateralToken(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(groveBasin));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(groveBasin));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        _swapExactInTest(creditToken, collateralToken, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_creditTokenToUsdc(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(groveBasin));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(groveBasin));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       CREDIT_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        _swapExactInTest(creditToken, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract GroveBasinSwapExactInFuzzTests is GroveBasinTestBase {

    address lp0 = makeAddr("lp0");
    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");

    address swapper = makeAddr("swapper");

    struct FuzzVars {
        uint256 lp0StartingValue;
        uint256 lp1StartingValue;
        uint256 lp2StartingValue;
        uint256 groveBasinStartingValue;
        uint256 lp0CachedValue;
        uint256 lp1CachedValue;
        uint256 lp2CachedValue;
        uint256 groveBasinCachedValue;
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: pr.fuzz.runs = 100
    /// forge-config: master.fuzz.runs = 1000
    function testFuzz_swapExactIn(
        uint256 conversionRate,
        uint256 depositSeed
    ) public {
        // 1% to 200% conversion rate
        mockCreditTokenRateProvider.__setConversionRate(_bound(conversionRate, 0.01e27, 2e27));

        _deposit(address(collateralToken), lp0, _bound(_hash(depositSeed, "lp0-collateralToken"), 1, COLLATERAL_TOKEN_MAX));

        _deposit(address(usdc),  lp1, _bound(_hash(depositSeed, "lp1-usdc"),  1, USDC_TOKEN_MAX));
        _deposit(address(creditToken), lp1, _bound(_hash(depositSeed, "lp1-creditToken"), 1, CREDIT_TOKEN_MAX));

        _deposit(address(collateralToken),  lp2, _bound(_hash(depositSeed, "lp2-collateralToken"),  1, COLLATERAL_TOKEN_MAX));
        _deposit(address(usdc),  lp2, _bound(_hash(depositSeed, "lp2-usdc"),  1, USDC_TOKEN_MAX));
        _deposit(address(creditToken), lp2, _bound(_hash(depositSeed, "lp2-creditToken"), 1, CREDIT_TOKEN_MAX));

        FuzzVars memory vars;

        vars.lp0StartingValue = groveBasin.convertToAssetValue(groveBasin.shares(lp0));
        vars.lp1StartingValue = groveBasin.convertToAssetValue(groveBasin.shares(lp1));
        vars.lp2StartingValue = groveBasin.convertToAssetValue(groveBasin.shares(lp2));
        vars.groveBasinStartingValue = groveBasin.totalAssets();

        vm.startPrank(swapper);

        for (uint256 i; i < 1000; ++i) {
            MockERC20 assetIn  = _getAsset(_hash(i, "assetIn"));
            MockERC20 assetOut = _getAsset(_hash(i, "assetOut"));

            if (assetIn == assetOut) {
                assetOut = _getAsset(_hash(i, "assetOut") + 1);
            }

            address assetOutCustodian = address(assetOut) == address(usdc) ? pocket : address(groveBasin);

            // Calculate the maximum amount that can be swapped by using the inverse conversion rate
            uint256 maxAmountIn = groveBasin.previewSwapExactOut(
                address(assetIn),
                address(assetOut),
                assetOut.balanceOf(assetOutCustodian)
            );

            uint256 amountIn = _bound(_hash(i, "amountIn"), 0, maxAmountIn - 1);  // Rounding

            vars.lp0CachedValue = groveBasin.convertToAssetValue(groveBasin.shares(lp0));
            vars.lp1CachedValue = groveBasin.convertToAssetValue(groveBasin.shares(lp1));
            vars.lp2CachedValue = groveBasin.convertToAssetValue(groveBasin.shares(lp2));
            vars.groveBasinCachedValue = groveBasin.totalAssets();

            assetIn.mint(swapper, amountIn);
            assetIn.approve(address(groveBasin), amountIn);
            groveBasin.swapExactIn(address(assetIn), address(assetOut), amountIn, 0, swapper, 0);

            // Rounding is always in favour of the LPs
            assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp0)), vars.lp0CachedValue);
            assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp1)), vars.lp1CachedValue);
            assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp2)), vars.lp2CachedValue);
            assertGe(groveBasin.totalAssets(),                        vars.groveBasinCachedValue);

            // Up to 2e12 rounding on each swap
            assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(lp0)), vars.lp0CachedValue, 2e12);
            assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(lp1)), vars.lp1CachedValue, 2e12);
            assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(lp2)), vars.lp2CachedValue, 2e12);
            assertApproxEqAbs(groveBasin.totalAssets(),                        vars.groveBasinCachedValue, 2e12);
        }

        // Rounding is always in favour of the LPs
        assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp0)), vars.lp0StartingValue);
        assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp1)), vars.lp1StartingValue);
        assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp2)), vars.lp2StartingValue);
        assertGe(groveBasin.totalAssets(),                        vars.groveBasinStartingValue);

        // Up to 2e12 rounding on each swap, for 1000 swaps
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(lp0)), vars.lp0StartingValue, 2000e12);
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(lp1)), vars.lp1StartingValue, 2000e12);
        assertApproxEqAbs(groveBasin.convertToAssetValue(groveBasin.shares(lp2)), vars.lp2StartingValue, 2000e12);
        assertApproxEqAbs(groveBasin.totalAssets(),                        vars.groveBasinStartingValue, 2000e12);
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        uint256 index = indexSeed % 3;

        if (index == 0) return collateralToken;
        if (index == 1) return usdc;
        if (index == 2) return creditToken;

        else revert("Invalid index");
    }

}
