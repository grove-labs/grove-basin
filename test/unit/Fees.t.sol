// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

/**********************************************************************************************/
/*** SetFeeBounds tests                                                                     ***/
/**********************************************************************************************/

contract GroveBasinSetFeeBoundsFailureTests is GroveBasinTestBase {

    bytes32 lpRole;

    function setUp() public override {
        super.setUp();
        lpRole = groveBasin.MANAGER_ROLE();
    }

    function test_setFeeBounds_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        groveBasin.setFeeBounds(0, 100);
    }

    function test_setFeeBounds_minGtMax() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.MinFeeGreaterThanMaxFee.selector);
        groveBasin.setFeeBounds(200, 100);
    }

    function test_setFeeBounds_maxGtBps() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.MaxFeeExceedsBps.selector);
        groveBasin.setFeeBounds(0, 10_001);
    }

    function test_setFeeBounds_maxEqBps() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.MaxFeeExceedsBps.selector);
        groveBasin.setFeeBounds(0, 10_000);
    }

    function test_setFeeBounds_revertsWhenPurchaseFeeBelowMin() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(200);
        vm.expectRevert(IGroveBasin.CurrentFeeOutOfNewBounds.selector);
        groveBasin.setFeeBounds(300, 500);
        vm.stopPrank();
    }

    function test_setFeeBounds_revertsWhenPurchaseFeeAboveMax() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(400);
        vm.expectRevert(IGroveBasin.CurrentFeeOutOfNewBounds.selector);
        groveBasin.setFeeBounds(0, 300);
        vm.stopPrank();
    }

    function test_setFeeBounds_revertsWhenRedemptionFeeBelowMin() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setRedemptionFee(100);
        vm.expectRevert(IGroveBasin.CurrentFeeOutOfNewBounds.selector);
        groveBasin.setFeeBounds(200, 500);
        vm.stopPrank();
    }

    function test_setFeeBounds_revertsWhenRedemptionFeeAboveMax() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setRedemptionFee(400);
        vm.expectRevert(IGroveBasin.CurrentFeeOutOfNewBounds.selector);
        groveBasin.setFeeBounds(0, 300);
        vm.stopPrank();
    }

    function test_setFeeBounds_revertsWhenBothFeesOutOfBounds() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(100);
        groveBasin.setRedemptionFee(400);
        vm.expectRevert(IGroveBasin.CurrentFeeOutOfNewBounds.selector);
        groveBasin.setFeeBounds(200, 300);
        vm.stopPrank();
    }

}

contract GroveBasinSetFeeBoundsSuccessTests is GroveBasinTestBase {

    event FeeBoundsSet(uint256 oldMinFee, uint256 oldMaxFee, uint256 newMinFee, uint256 newMaxFee);

    bytes32 lpRole;

    function setUp() public override {
        super.setUp();
        lpRole = groveBasin.MANAGER_ROLE();
    }

    function test_setFeeBounds() public {
        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 0);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit FeeBoundsSet(0, 0, 0, 500);
        groveBasin.setFeeBounds(0, 500);

        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 500);
    }

    function test_setFeeBounds_sameMinMax() public {
        // First set bounds wide, set fees, then tighten
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(100);
        groveBasin.setRedemptionFee(100);
        groveBasin.setFeeBounds(100, 100);
        vm.stopPrank();

        assertEq(groveBasin.minFee(), 100);
        assertEq(groveBasin.maxFee(), 100);
    }

    function test_setFeeBounds_zeroToZero() public {
        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit FeeBoundsSet(0, 0, 0, 0);
        groveBasin.setFeeBounds(0, 0);

        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 0);
    }

    function test_setFeeBounds_update() public {
        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit FeeBoundsSet(0, 500, 0, 1000);
        groveBasin.setFeeBounds(0, 1000);

        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 1000);
    }

    function test_setFeeBounds_tightenBoundsAroundFees() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(200);
        groveBasin.setRedemptionFee(300);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit FeeBoundsSet(0, 500, 200, 300);
        groveBasin.setFeeBounds(200, 300);

        assertEq(groveBasin.minFee(), 200);
        assertEq(groveBasin.maxFee(), 300);
    }

}

/**********************************************************************************************/
/*** SetPurchaseFee tests                                                                   ***/
/**********************************************************************************************/

contract GroveBasinSetPurchaseFeeFailureTests is GroveBasinTestBase {

    bytes32 ownerRole;

    function setUp() public override {
        super.setUp();
        ownerRole = groveBasin.OWNER_ROLE();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_setPurchaseFee_notOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                ownerRole
            )
        );
        groveBasin.setPurchaseFee(100);
    }

    function test_setPurchaseFee_managerCannotSet() public {
        address manager = makeAddr("manager");
        bytes32 managerRole = groveBasin.MANAGER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(managerRole, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                manager,
                ownerRole
            )
        );
        groveBasin.setPurchaseFee(100);
    }

    function test_setPurchaseFee_aboveMax() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.PurchaseFeeOutOfBounds.selector);
        groveBasin.setPurchaseFee(501);
    }

    function test_setPurchaseFee_belowMin() public {
        vm.startPrank(owner);
        groveBasin.setPurchaseFee(50);
        groveBasin.setRedemptionFee(50);
        groveBasin.setFeeBounds(50, 500);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(IGroveBasin.PurchaseFeeOutOfBounds.selector);
        groveBasin.setPurchaseFee(49);
    }

}

contract GroveBasinSetPurchaseFeeSuccessTests is GroveBasinTestBase {

    event PurchaseFeeSet(uint256 oldPurchaseFee, uint256 newPurchaseFee);

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_setPurchaseFee() public {
        assertEq(groveBasin.purchaseFee(), 0);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PurchaseFeeSet(0, 100);
        groveBasin.setPurchaseFee(100);

        assertEq(groveBasin.purchaseFee(), 100);
    }

    function test_setPurchaseFee_toZero() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PurchaseFeeSet(100, 0);
        groveBasin.setPurchaseFee(0);

        assertEq(groveBasin.purchaseFee(), 0);
    }

    function test_setPurchaseFee_toMax() public {
        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit PurchaseFeeSet(0, 500);
        groveBasin.setPurchaseFee(500);

        assertEq(groveBasin.purchaseFee(), 500);
    }

    function test_setPurchaseFee_atBoundaries() public {
        vm.startPrank(owner);
        groveBasin.setPurchaseFee(50);
        groveBasin.setRedemptionFee(50);
        groveBasin.setFeeBounds(50, 500);
        vm.stopPrank();

        vm.prank(owner);
        groveBasin.setPurchaseFee(50);
        assertEq(groveBasin.purchaseFee(), 50);

        vm.prank(owner);
        groveBasin.setPurchaseFee(500);
        assertEq(groveBasin.purchaseFee(), 500);
    }

}

/**********************************************************************************************/
/*** SetRedemptionFee tests                                                                 ***/
/**********************************************************************************************/

contract GroveBasinSetRedemptionFeeFailureTests is GroveBasinTestBase {

    bytes32 ownerRole;

    function setUp() public override {
        super.setUp();
        ownerRole = groveBasin.OWNER_ROLE();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_setRedemptionFee_notOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                ownerRole
            )
        );
        groveBasin.setRedemptionFee(100);
    }

    function test_setRedemptionFee_aboveMax() public {
        vm.prank(owner);
        vm.expectRevert(IGroveBasin.RedemptionFeeOutOfBounds.selector);
        groveBasin.setRedemptionFee(501);
    }

    function test_setRedemptionFee_belowMin() public {
        vm.startPrank(owner);
        groveBasin.setRedemptionFee(50);
        groveBasin.setPurchaseFee(50);
        groveBasin.setFeeBounds(50, 500);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(IGroveBasin.RedemptionFeeOutOfBounds.selector);
        groveBasin.setRedemptionFee(49);
    }

}

contract GroveBasinSetRedemptionFeeSuccessTests is GroveBasinTestBase {

    event RedemptionFeeSet(uint256 oldRedemptionFee, uint256 newRedemptionFee);

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_setRedemptionFee() public {
        assertEq(groveBasin.redemptionFee(), 0);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit RedemptionFeeSet(0, 100);
        groveBasin.setRedemptionFee(100);

        assertEq(groveBasin.redemptionFee(), 100);
    }

    function test_setRedemptionFee_toMax() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(500);
        assertEq(groveBasin.redemptionFee(), 500);
    }

}

/**********************************************************************************************/
/*** Fee calculation tests                                                                  ***/
/**********************************************************************************************/

contract GroveBasinPreviewSwapFeeTests is GroveBasinTestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_previewSwapExactInFee_creditToken() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        assertEq(groveBasin.previewSwapExactInFee(address(creditToken), 10_000e18), 100e18);
    }

    function test_previewSwapExactInFee_nonCreditToken() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(200);  // 2%

        assertEq(groveBasin.previewSwapExactInFee(address(swapToken), 10_000e6), 200e6);
    }

    function test_previewSwapExactOutFee_creditToken() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        uint256 fee = groveBasin.previewSwapExactOutFee(address(creditToken), 9_900e18);
        assertEq(fee, 100e18);
    }

    function test_previewSwapExactOutFee_nonCreditToken() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(200);  // 2%

        uint256 fee = groveBasin.previewSwapExactOutFee(address(swapToken), 9_800e6);
        assertEq(fee, 200e6);
    }

    function test_previewSwapExactInFee_roundsUpFavoringProtocol() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        // 33 * 100 / 10000 = 0 with floor, 1 with ceil
        // Fee must never round to zero when a fee is configured and amount is non-zero
        uint256 fee = groveBasin.previewSwapExactInFee(address(creditToken), 33);
        assertGt(fee, 0, "ExactIn fee should round up in favor of the protocol");
    }

}

contract GroveBasinFeeCalculationTests is GroveBasinTestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_calculatePurchaseFee_zeroFee() public view {
        assertEq(groveBasin.calculatePurchaseFee(100e18), 0);
    }

    function test_calculatePurchaseFee_withFee() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        assertEq(groveBasin.calculatePurchaseFee(100e18), 1e18);
        assertEq(groveBasin.calculatePurchaseFee(1000e6), 10e6);
        assertEq(groveBasin.calculatePurchaseFee(0),      0);
        // 3 * 100 / 10000 = 0.03 -> rounds up to 1
        assertEq(groveBasin.calculatePurchaseFee(3),      1);
    }

    function test_calculateRedemptionFee_zeroFee() public view {
        assertEq(groveBasin.calculateRedemptionFee(100e18), 0);
    }

    function test_calculateRedemptionFee_withFee() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(50);  // 0.5%

        assertEq(groveBasin.calculateRedemptionFee(10_000e18), 50e18);
        assertEq(groveBasin.calculateRedemptionFee(0),         0);
        // 3 * 50 / 10000 = 0.015 -> rounds up to 1
        assertEq(groveBasin.calculateRedemptionFee(3),         1);
    }

    function testFuzz_calculatePurchaseFee(uint256 amount, uint256 fee) public {
        fee    = _bound(fee,    0, 500);
        amount = _bound(amount, 0, 1e30);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 expected = fee == 0 ? 0 : Math.ceilDiv(amount * fee, 10_000);
        assertEq(groveBasin.calculatePurchaseFee(amount), expected);
    }

    function testFuzz_calculateRedemptionFee(uint256 amount, uint256 fee) public {
        fee    = _bound(fee,    0, 500);
        amount = _bound(amount, 0, 1e30);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 expected = fee == 0 ? 0 : Math.ceilDiv(amount * fee, 10_000);
        assertEq(groveBasin.calculateRedemptionFee(amount), expected);
    }

}

/**********************************************************************************************/
/*** Swap with fees integration tests                                                       ***/
/**********************************************************************************************/

contract GroveBasinSwapWithFeesTests is GroveBasinTestBase {

    address swapper    = makeAddr("swapper");
    address feeClaimer = makeAddr("feeClaimer");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setFeeClaimer(feeClaimer);
        vm.stopPrank();

        _deposit(address(swapToken),       makeAddr("seeder"), 1_000_000e6);
        _deposit(address(collateralToken), makeAddr("seeder"), 1_000_000e18);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000_000e18);
    }

    // --- Purchase fee (swap/collateral -> credit) ---

    function test_previewSwapExactIn_purchaseFee_swapToCreditToken() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        // Without fee: 100 USDC -> 80 credit (rate 1.25)
        // With 1% fee: 80 * 9900 / 10000 = 79.2 credit
        uint256 amountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6);
        assertEq(amountOut, 79.2e18);
    }

    function test_previewSwapExactIn_purchaseFee_collateralToCreditToken() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        // Without fee: 100 collateral -> 80 credit
        // With 1% fee: 80 * 9900 / 10000 = 79.2 credit
        uint256 amountOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), 100e18);
        assertEq(amountOut, 79.2e18);
    }

    function test_previewSwapExactOut_purchaseFee_swapToCreditToken() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        // Without fee: 80 credit needs 100 USDC
        // With 1% fee: grossOut = ceil(80e18 * 10000 / 9900), then amountIn = convert(grossOut)
        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);
        assertEq(amountIn, 101_010_102);
    }

    // --- Redemption fee (credit -> swap/collateral) ---

    function test_previewSwapExactIn_redemptionFee_creditTokenToSwap() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(100);  // 1%

        // Without fee: 100 credit -> 125 USDC
        // With 1% fee: 125 * 9900 / 10000 = 123.75 USDC -> 123_750_000
        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 100e18);
        assertEq(amountOut, 123_750_000);
    }

    function test_previewSwapExactIn_redemptionFee_creditTokenToCollateral() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(100);  // 1%

        // Without fee: 100 credit -> 125 collateral
        // With 1% fee: 125 * 9900 / 10000 = 123.75 collateral
        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), 100e18);
        assertEq(amountOut, 123.75e18);
    }

    function test_previewSwapExactOut_redemptionFee_creditTokenToSwap() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(100);  // 1%

        // Without fee: 125 USDC needs 100 credit
        // With 1% fee: grossOut = ceil(125e6 * 10000 / 9900), then amountIn = convert(grossOut)
        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 125e6);
        assertEq(amountIn, 101_010_101_600_000_000_000);
    }

    // --- No fee when fee is zero ---

    function test_previewSwapExactIn_noFee() public view {
        uint256 amountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6);
        assertEq(amountOut, 80e18);
    }

    function test_previewSwapExactOut_noFee() public view {
        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);
        assertEq(amountIn, 100e6);
    }

    // --- Full swap execution with fees ---

    function test_swapExactIn_withPurchaseFee() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        uint256 amountIn = 100e6;
        swapToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);
        uint256 amountOut = groveBasin.swapExactIn(
            address(swapToken), address(creditToken), amountIn, 0, swapper, 0
        );
        vm.stopPrank();

        assertEq(amountOut, 79.2e18);
        assertEq(creditToken.balanceOf(swapper), 79.2e18);
    }

    function test_swapExactIn_withRedemptionFee() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(100);  // 1%

        uint256 amountIn = 100e18;
        creditToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), amountIn);
        uint256 amountOut = groveBasin.swapExactIn(
            address(creditToken), address(swapToken), amountIn, 0, swapper, 0
        );
        vm.stopPrank();

        assertEq(amountOut, 123_750_000);
        assertEq(swapToken.balanceOf(swapper), 123_750_000);
    }

    function test_swapExactOut_withPurchaseFee() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        uint256 expectedAmountIn = groveBasin.previewSwapExactOut(
            address(swapToken), address(creditToken), 80e18
        );

        swapToken.mint(swapper, expectedAmountIn);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), expectedAmountIn);
        uint256 amountIn = groveBasin.swapExactOut(
            address(swapToken), address(creditToken), 80e18, expectedAmountIn, swapper, 0
        );
        vm.stopPrank();

        assertEq(amountIn, expectedAmountIn);
        assertEq(creditToken.balanceOf(swapper), 80e18);
    }

    function test_swapExactOut_withRedemptionFee() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(100);  // 1%

        uint256 expectedAmountIn = groveBasin.previewSwapExactOut(
            address(creditToken), address(swapToken), 125e6
        );

        creditToken.mint(swapper, expectedAmountIn);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), expectedAmountIn);
        uint256 amountIn = groveBasin.swapExactOut(
            address(creditToken), address(swapToken), 125e6, expectedAmountIn, swapper, 0
        );
        vm.stopPrank();

        assertEq(amountIn, expectedAmountIn);
        assertEq(swapToken.balanceOf(swapper), 125e6);
    }

    // --- Fee accrues as shares to fee claimer ---

    function test_swapExactIn_feeAccruesToFeeClaimer() public {

        _deposit(address(collateralToken), makeAddr("depositor"), 10_000e18);

        uint256 totalSharesBefore = groveBasin.totalShares();

        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.shares(feeClaimer), 0);
        assertGt(groveBasin.totalShares(), totalSharesBefore);
    }

    // --- Purchase fee doesn't affect redemptions and vice versa ---

    function test_purchaseFee_doesNotAffectRedemption() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(500);  // 5%

        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 100e18);
        assertEq(amountOut, 125e6);
    }

    function test_redemptionFee_doesNotAffectPurchase() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(500);  // 5%

        uint256 amountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6);
        assertEq(amountOut, 80e18);
    }

    // --- ExactIn and ExactOut charge the same fee ---

    function test_exactInAndExactOut_sameFee_purchase() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        uint256 amountIn  = 100e6;
        uint256 amountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), amountIn);

        uint256 requiredAmountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), amountOut);

        assertEq(requiredAmountIn, amountIn);
    }

    function test_exactInAndExactOut_sameFee_redemption() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(100);  // 1%

        uint256 amountIn  = 100e18;
        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), amountIn);

        uint256 requiredAmountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), amountOut);

        assertEq(requiredAmountIn, amountIn);
    }

    // --- Both fees active simultaneously ---

    function test_bothFeesActive() public {
        vm.startPrank(owner);
        groveBasin.setPurchaseFee(100);    // 1%
        groveBasin.setRedemptionFee(200);  // 2%
        vm.stopPrank();

        // Purchase: 100 USDC -> 80 credit -> 80 * 9900/10000 = 79.2 credit
        assertEq(
            groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6),
            79.2e18
        );

        // Redemption: 100 credit -> 125 USDC -> 125 * 9800/10000 = 122.5 USDC
        assertEq(
            groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 100e18),
            122_500_000
        );
    }

}

/**********************************************************************************************/
/*** Swap with fees fuzz tests                                                              ***/
/**********************************************************************************************/

contract GroveBasinSwapWithFeesFuzzTests is GroveBasinTestBase {

    address swapper    = makeAddr("swapper");
    address feeClaimer = makeAddr("feeClaimer");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 2000);  // Max 20% for fuzz range
        groveBasin.setFeeClaimer(feeClaimer);
        vm.stopPrank();

        _deposit(address(collateralToken), makeAddr("seeder"), COLLATERAL_TOKEN_MAX * 100);
        _deposit(address(swapToken),       makeAddr("seeder"), SWAP_TOKEN_MAX * 100);
        _deposit(address(creditToken),     makeAddr("seeder"), CREDIT_TOKEN_MAX * 100);
    }

    function testFuzz_swapExactIn_purchaseFee_swapToCreditToken(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn,       1,       SWAP_TOKEN_MAX);
        fee            = _bound(fee,            0,       2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        // Use precise calculation: amountIn * swapRate * creditPrecision / (creditRate * swapPrecision)
        uint256 rawAmountOut = (amountIn * 1e27 * 1e18) / (conversionRate * 1e6);
        uint256 expectedAmountOut = rawAmountOut - Math.ceilDiv(rawAmountOut * fee, 10_000);

        uint256 amountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactIn_redemptionFee_creditTokenToSwap(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn,       1,       CREDIT_TOKEN_MAX);
        fee            = _bound(fee,            0,       2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 rawAmountOut      = amountIn * conversionRate / 1e27 / 1e12;
        uint256 expectedAmountOut = rawAmountOut - Math.ceilDiv(rawAmountOut * fee, 10_000);

        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactIn_purchaseFee_collateralToCreditToken(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn,       1,       COLLATERAL_TOKEN_MAX);
        fee            = _bound(fee,            0,       2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 rawAmountOut      = amountIn * 1e27 / conversionRate;
        uint256 expectedAmountOut = rawAmountOut - Math.ceilDiv(rawAmountOut * fee, 10_000);

        uint256 amountOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactIn_redemptionFee_creditTokenToCollateral(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn,       1,       CREDIT_TOKEN_MAX);
        fee            = _bound(fee,            0,       2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 rawAmountOut      = amountIn * conversionRate / 1e27;
        uint256 expectedAmountOut = rawAmountOut - Math.ceilDiv(rawAmountOut * fee, 10_000);

        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactOut_purchaseFee_swapToCreditToken(
        uint256 amountOut,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountOut      = _bound(amountOut,      1,       CREDIT_TOKEN_MAX);
        fee            = _bound(fee,            0,       2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 grossAmountOut = fee == 0 ? amountOut : Math.ceilDiv(amountOut * 10_000, 10_000 - fee);
        uint256 expectedAmountIn = Math.mulDiv(
            grossAmountOut,
            conversionRate * 1e6,
            1e27 * 1e18,
            Math.Rounding.Ceil
        );

        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), amountOut);
        assertEq(amountIn, expectedAmountIn);
    }

    function testFuzz_swapExactOut_redemptionFee_creditTokenToSwap(
        uint256 amountOut,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountOut      = _bound(amountOut,      1,       SWAP_TOKEN_MAX);
        fee            = _bound(fee,            0,       2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 grossAmountOut = fee == 0 ? amountOut : Math.ceilDiv(amountOut * 10_000, 10_000 - fee);
        uint256 expectedAmountIn = Math.mulDiv(
            grossAmountOut,
            1e27 * 1e18,
            conversionRate * 1e6,
            Math.Rounding.Ceil
        );

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), amountOut);
        assertEq(amountIn, expectedAmountIn);
    }

    function testFuzz_feeAccruesToFeeClaimer(
        uint256 amountIn,
        uint256 purchaseFee_,
        uint256 redemptionFee_
    ) public {
        amountIn       = _bound(amountIn,       1e6, SWAP_TOKEN_MAX);
        purchaseFee_   = _bound(purchaseFee_,   1,   2000);
        redemptionFee_ = _bound(redemptionFee_, 1,   2000);

        _deposit(address(collateralToken), makeAddr("depositor"), 10_000e18);

        vm.startPrank(owner);
        groveBasin.setPurchaseFee(purchaseFee_);
        groveBasin.setRedemptionFee(redemptionFee_);
        vm.stopPrank();

        swapToken.mint(swapper, amountIn);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), amountIn, 0, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.shares(feeClaimer), 0);
    }

    function testFuzz_setFeeBounds(uint256 newMaxFee) public {
        newMaxFee = _bound(newMaxFee, 0, 9_999);

        vm.prank(owner);
        groveBasin.setFeeBounds(0, newMaxFee);

        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), newMaxFee);
    }

    function testFuzz_setPurchaseFee(uint256 fee) public {
        fee = _bound(fee, 0, 2000);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        assertEq(groveBasin.purchaseFee(), fee);
    }

    function testFuzz_setRedemptionFee(uint256 fee) public {
        fee = _bound(fee, 0, 2000);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        assertEq(groveBasin.redemptionFee(), fee);
    }

}

/**********************************************************************************************/
/*** Multi-swap fuzz test with fees                                                         ***/
/**********************************************************************************************/

contract GroveBasinSwapWithFeesMultiFuzzTests is GroveBasinTestBase {

    address lp0 = makeAddr("lp0");
    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");

    address lpRole_    = makeAddr("lpRole");
    address swapper    = makeAddr("swapper");
    address feeClaimer = makeAddr("feeClaimer");

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: pr.fuzz.runs = 100
    /// forge-config: master.fuzz.runs = 1000
    function testFuzz_swapExactIn_withFees(
        uint256 conversionRate,
        uint256 depositSeed,
        uint256 purchaseFee_,
        uint256 redemptionFee_
    ) public {
        mockCreditTokenRateProvider.__setConversionRate(_bound(conversionRate, 0.01e27, 2e27));

        bytes32 lpRoleHash = groveBasin.MANAGER_ROLE();

        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 2000);
        groveBasin.grantRole(lpRoleHash, lpRole_);
        groveBasin.setFeeClaimer(feeClaimer);
        vm.stopPrank();

        purchaseFee_   = _bound(purchaseFee_,   0, 2000);
        redemptionFee_ = _bound(redemptionFee_, 0, 2000);

        vm.startPrank(owner);
        groveBasin.setPurchaseFee(purchaseFee_);
        groveBasin.setRedemptionFee(redemptionFee_);
        vm.stopPrank();

        _deposit(address(collateralToken), lp0, _bound(_hash(depositSeed, "lp0-collateralToken"), 1, COLLATERAL_TOKEN_MAX));

        _deposit(address(swapToken),   lp1, _bound(_hash(depositSeed, "lp1-swapToken"),   1, SWAP_TOKEN_MAX));
        _deposit(address(creditToken), lp1, _bound(_hash(depositSeed, "lp1-creditToken"), 1, CREDIT_TOKEN_MAX));

        _deposit(address(collateralToken),  lp2, _bound(_hash(depositSeed, "lp2-collateralToken"), 1, COLLATERAL_TOKEN_MAX));
        _deposit(address(swapToken),        lp2, _bound(_hash(depositSeed, "lp2-swapToken"),       1, SWAP_TOKEN_MAX));
        _deposit(address(creditToken),      lp2, _bound(_hash(depositSeed, "lp2-creditToken"),     1, CREDIT_TOKEN_MAX));

        uint256 lp0StartingValue = groveBasin.convertToAssetValue(groveBasin.shares(lp0));
        uint256 lp1StartingValue = groveBasin.convertToAssetValue(groveBasin.shares(lp1));
        uint256 lp2StartingValue = groveBasin.convertToAssetValue(groveBasin.shares(lp2));

        uint256 groveBasinStartingValue = groveBasin.totalAssets();

        vm.startPrank(swapper);

        for (uint256 i; i < 100; ++i) {
            MockERC20 assetIn  = _getAsset(_hash(i, "assetIn"));
            MockERC20 assetOut = _getAsset(_hash(i, "assetOut"));

            if (assetIn == assetOut) {
                assetOut = _getAsset(_hash(i, "assetOut") + 1);
            }

            if (assetIn != creditToken && assetOut != creditToken) {
                assetOut = creditToken;
            }

            uint256 assetOutBalance = address(assetOut) == address(swapToken)
                ? _pocketSwapBalance()
                : assetOut.balanceOf(address(groveBasin));

            uint256 maxAmountIn = groveBasin.previewSwapExactOut(
                address(assetIn),
                address(assetOut),
                assetOutBalance
            );

            uint256 amountIn = _bound(_hash(i, "amountIn"), 0, maxAmountIn - 1);

            uint256 cachedTotalAssets = groveBasin.totalAssets();

            assetIn.mint(swapper, amountIn);
            assetIn.approve(address(groveBasin), amountIn);
            groveBasin.swapExactIn(address(assetIn), address(assetOut), amountIn, 0, swapper, 0);

            assertGe(groveBasin.totalAssets(), cachedTotalAssets);
        }

        assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp0)), lp0StartingValue);
        assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp1)), lp1StartingValue);
        assertGe(groveBasin.convertToAssetValue(groveBasin.shares(lp2)), lp2StartingValue);
        assertGe(groveBasin.totalAssets(), groveBasinStartingValue);
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        uint256 index = indexSeed % 3;

        if (index == 0) return collateralToken;
        if (index == 1) return swapToken;
        if (index == 2) return creditToken;

        else revert("Invalid index");
    }

}

/**********************************************************************************************/
/*** Fee share accrual tests                                                                ***/
/**********************************************************************************************/

contract GroveBasinFeeShareAccrualTests is GroveBasinTestBase {

    event FeeSharesAccrued(address indexed claimer, uint256 shares);

    address swapper    = makeAddr("swapper");
    address feeClaimer = makeAddr("feeClaimer");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(100);  // 1%
        groveBasin.setFeeClaimer(feeClaimer);
        vm.stopPrank();

        _deposit(address(swapToken),       makeAddr("seeder"), 1_000_000e6);
        _deposit(address(collateralToken), makeAddr("seeder"), 1_000_000e18);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000_000e18);
    }

    function test_feeSharesAccrued_afterSwapExactIn() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.shares(feeClaimer), 0);
    }

    function test_feeSharesAccrued_afterSwapExactOut() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(200);  // 2%

        uint256 amountIn = groveBasin.previewSwapExactOut(
            address(creditToken), address(collateralToken), 100e18
        );
        creditToken.mint(swapper, amountIn);

        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), amountIn);
        groveBasin.swapExactOut(address(creditToken), address(collateralToken), 100e18, amountIn, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.shares(feeClaimer), 0);
    }

    function test_feeSharesAccumulate_multipleSwaps() public {
        swapToken.mint(swapper, 200e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 200e6);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        uint256 firstShares = groveBasin.shares(feeClaimer);
        assertGt(firstShares, 0);

        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.shares(feeClaimer), firstShares);
    }

    function test_accrueFeeShares_roundsUpFavoringProtocol() public {
        _deposit(address(collateralToken), makeAddr("bigLp"), 1e18);

        // Inflate totalAssets relative to totalShares so floor-division would give 0 shares
        mockCollateralTokenRateProvider.__setConversionRate(1e45);

        swapToken.mint(swapper, 1);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 1);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 1, 0, swapper, 0);
        vm.stopPrank();

        // A fee was charged (grossOut > amountOut), so the fee claimer must receive shares.
        // Rounding should favor the protocol (ceil), not the user (floor).
        assertGt(groveBasin.shares(feeClaimer), 0, "Fee shares should round up, not down to zero");
    }

    function test_feeSharesNotAccrued_noFeeClaimerSet() public {
        vm.prank(owner);
        groveBasin.setFeeClaimer(address(0));

        assertEq(groveBasin.feeClaimer(), address(0));

        uint256 totalSharesBefore = groveBasin.totalShares();

        swapToken.mint(swapper, 100e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();

        assertEq(groveBasin.totalShares(), totalSharesBefore);
    }

    function test_feeSharesAccrued_emitsEvent() public {
        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        vm.expectEmit(true, false, false, false, address(groveBasin));
        emit FeeSharesAccrued(feeClaimer, 0);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();
    }

    function test_feeClaimerCanWithdraw() public {
        swapToken.mint(swapper, 100e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();

        uint256 feeClaimerShares = groveBasin.shares(feeClaimer);
        assertGt(feeClaimerShares, 0);

        uint256 expectedAssets = groveBasin.convertToAssets(address(collateralToken), feeClaimerShares);

        vm.prank(feeClaimer);
        uint256 assetsWithdrawn = groveBasin.withdraw(address(collateralToken), feeClaimer, type(uint256).max);

        assertEq(assetsWithdrawn, expectedAssets);
        assertEq(groveBasin.shares(feeClaimer), 0);
    }

    function test_setFeeClaimer() public {
        address newClaimer = makeAddr("newClaimer");

        vm.prank(owner);
        groveBasin.setFeeClaimer(newClaimer);

        assertEq(groveBasin.feeClaimer(), newClaimer);
    }

    function test_setFeeClaimer_toZero() public {
        assertEq(groveBasin.feeClaimer(), feeClaimer);

        vm.prank(owner);
        groveBasin.setFeeClaimer(address(0));

        assertEq(groveBasin.feeClaimer(), address(0));
    }

    function test_setFeeClaimer_notAdmin() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        groveBasin.setFeeClaimer(makeAddr("random"));
    }

    function testFuzz_feeSharesAccrued(uint256 amountIn, uint256 fee) public {
        amountIn = _bound(amountIn, 1e6, 100_000e6);
        fee      = _bound(fee,      1,   500);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        swapToken.mint(swapper, amountIn);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), amountIn, 0, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.shares(feeClaimer), 0);
    }

}
