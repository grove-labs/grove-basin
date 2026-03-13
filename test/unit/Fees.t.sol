// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

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
        vm.expectRevert("GroveBasin/min-fee-gt-max-fee");
        groveBasin.setFeeBounds(200, 100);
    }

    function test_setFeeBounds_maxGtBps() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/max-fee-gte-bps");
        groveBasin.setFeeBounds(0, 10_001);
    }

    function test_setFeeBounds_maxGtBps_boundary() public {
        vm.prank(owner);
        groveBasin.setFeeBounds(0, 10_000);

        assertEq(groveBasin.maxFee(), 10_000);
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

    function test_setFeeBounds_clampsPurchaseFeeToMin() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(200);
        groveBasin.setFeeBounds(300, 500);
        vm.stopPrank();

        assertEq(groveBasin.purchaseFee(), 300);
    }

    function test_setFeeBounds_clampsPurchaseFeeToMax() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(400);
        groveBasin.setFeeBounds(0, 300);
        vm.stopPrank();

        assertEq(groveBasin.purchaseFee(), 300);
    }

    function test_setFeeBounds_clampsRedemptionFeeToMin() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setRedemptionFee(100);
        groveBasin.setFeeBounds(200, 500);
        vm.stopPrank();

        assertEq(groveBasin.redemptionFee(), 200);
    }

    function test_setFeeBounds_clampsRedemptionFeeToMax() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setRedemptionFee(400);
        groveBasin.setFeeBounds(0, 300);
        vm.stopPrank();

        assertEq(groveBasin.redemptionFee(), 300);
    }

    function test_setFeeBounds_clampsBothFees() public {
        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(100);
        groveBasin.setRedemptionFee(400);
        groveBasin.setFeeBounds(200, 300);
        vm.stopPrank();

        assertEq(groveBasin.purchaseFee(),   200);
        assertEq(groveBasin.redemptionFee(), 300);
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
        vm.expectRevert("GroveBasin/purchase-fee-out-of-bounds");
        groveBasin.setPurchaseFee(501);
    }

    function test_setPurchaseFee_belowMin() public {
        vm.startPrank(owner);
        groveBasin.setPurchaseFee(50);
        groveBasin.setRedemptionFee(50);
        groveBasin.setFeeBounds(50, 500);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("GroveBasin/purchase-fee-out-of-bounds");
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
        vm.expectRevert("GroveBasin/redemption-fee-out-of-bounds");
        groveBasin.setRedemptionFee(501);
    }

    function test_setRedemptionFee_belowMin() public {
        vm.startPrank(owner);
        groveBasin.setRedemptionFee(50);
        groveBasin.setPurchaseFee(50);
        groveBasin.setFeeBounds(50, 500);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("GroveBasin/redemption-fee-out-of-bounds");
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

contract GroveBasinFeeCalculationTests is GroveBasinTestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);
    }

    function test_calculatePurchaseFee_zeroFee() public view {
        assertEq(groveBasin.calculatePurchaseFee(100e18, false), 0);
    }

    function test_calculatePurchaseFee_withFee() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        assertEq(groveBasin.calculatePurchaseFee(100e18, false), 1e18);
        assertEq(groveBasin.calculatePurchaseFee(1000e6, false), 10e6);
        assertEq(groveBasin.calculatePurchaseFee(0, false), 0);
    }

    function test_calculateRedemptionFee_zeroFee() public view {
        assertEq(groveBasin.calculateRedemptionFee(100e18, false), 0);
    }

    function test_calculateRedemptionFee_withFee() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(50);  // 0.5%

        assertEq(groveBasin.calculateRedemptionFee(10_000e18, false), 50e18);
        assertEq(groveBasin.calculateRedemptionFee(0, false), 0);
    }

    function testFuzz_calculatePurchaseFee(uint256 amount, uint256 fee) public {
        fee    = _bound(fee, 0, 500);
        amount = _bound(amount, 0, 1e30);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        assertEq(groveBasin.calculatePurchaseFee(amount, false), amount * fee / 10_000);
    }

    function testFuzz_calculateRedemptionFee(uint256 amount, uint256 fee) public {
        fee    = _bound(fee, 0, 500);
        amount = _bound(amount, 0, 1e30);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        assertEq(groveBasin.calculateRedemptionFee(amount, false), amount * fee / 10_000);
    }

    function test_calculatePurchaseFee_roundUp() public {
        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        assertEq(groveBasin.calculatePurchaseFee(100e18, true), 1e18);
        assertEq(groveBasin.calculatePurchaseFee(0, true), 0);
        // 3 * 100 / 10000 = 0.03 -> rounds up to 1
        assertEq(groveBasin.calculatePurchaseFee(3, true), 1);
        assertEq(groveBasin.calculatePurchaseFee(3, false), 0);
    }

    function test_calculateRedemptionFee_roundUp() public {
        vm.prank(owner);
        groveBasin.setRedemptionFee(50);  // 0.5%

        assertEq(groveBasin.calculateRedemptionFee(10_000e18, true), 50e18);
        assertEq(groveBasin.calculateRedemptionFee(0, true), 0);
        // 3 * 50 / 10000 = 0.015 -> rounds up to 1
        assertEq(groveBasin.calculateRedemptionFee(3, true), 1);
        assertEq(groveBasin.calculateRedemptionFee(3, false), 0);
    }

    function testFuzz_calculatePurchaseFee_roundUp(uint256 amount, uint256 fee) public {
        fee    = _bound(fee, 0, 500);
        amount = _bound(amount, 0, 1e30);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 expected = fee == 0 ? 0 : Math.ceilDiv(amount * fee, 10_000);
        assertEq(groveBasin.calculatePurchaseFee(amount, true), expected);
    }

    function testFuzz_calculateRedemptionFee_roundUp(uint256 amount, uint256 fee) public {
        fee    = _bound(fee, 0, 500);
        amount = _bound(amount, 0, 1e30);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 expected = fee == 0 ? 0 : Math.ceilDiv(amount * fee, 10_000);
        assertEq(groveBasin.calculateRedemptionFee(amount, true), expected);
    }

}

/**********************************************************************************************/
/*** Swap with fees integration tests                                                       ***/
/**********************************************************************************************/

contract GroveBasinSwapWithFeesTests is GroveBasinTestBase {

    address swapper = makeAddr("swapper");

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 500);

        swapToken.mint(pocket, 1_000_000e6);
        collateralToken.mint(address(groveBasin), 1_000_000e18);
        creditToken.mint(address(groveBasin), 1_000_000e18);
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
        // With 1% fee: amountIn = 100e6 + ceil(100e6 * 100 / 10000) = 101_000_000
        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);
        assertEq(amountIn, 101_000_000);
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
        // With 1% fee: amountIn = 100e18 + ceil(100e18 * 100 / 10000) = 101e18
        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 125e6);
        assertEq(amountIn, 101e18);
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

    // --- Fee accrues value to basin ---

    function test_swapExactIn_feeAccruesToBasin() public {
        _deposit(address(collateralToken), makeAddr("depositor"), 10_000e18);

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        vm.prank(owner);
        groveBasin.setPurchaseFee(100);  // 1%

        swapToken.mint(swapper, 100e6);

        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, swapper, 0);
        vm.stopPrank();

        assertGt(groveBasin.totalAssets(), totalAssetsBefore);
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

    address swapper = makeAddr("swapper");

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        groveBasin.setFeeBounds(0, 2000);  // Max 20% for fuzz range

        collateralToken.mint(address(groveBasin), COLLATERAL_TOKEN_MAX * 100);
        swapToken.mint(pocket, SWAP_TOKEN_MAX * 100);
        creditToken.mint(address(groveBasin), CREDIT_TOKEN_MAX * 100);
    }

    function testFuzz_swapExactIn_purchaseFee_swapToCreditToken(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn, 1, SWAP_TOKEN_MAX);
        fee            = _bound(fee, 0, 2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 rawAmountOut = amountIn * 1e27 / conversionRate * 1e12;
        uint256 expectedAmountOut = rawAmountOut - rawAmountOut * fee / 10_000;

        uint256 amountOut = groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactIn_redemptionFee_creditTokenToSwap(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn, 1, CREDIT_TOKEN_MAX);
        fee            = _bound(fee, 0, 2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 rawAmountOut = amountIn * conversionRate / 1e27 / 1e12;
        uint256 expectedAmountOut = rawAmountOut - rawAmountOut * fee / 10_000;

        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactIn_purchaseFee_collateralToCreditToken(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn, 1, COLLATERAL_TOKEN_MAX);
        fee            = _bound(fee, 0, 2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 rawAmountOut = amountIn * 1e27 / conversionRate;
        uint256 expectedAmountOut = rawAmountOut - rawAmountOut * fee / 10_000;

        uint256 amountOut = groveBasin.previewSwapExactIn(address(collateralToken), address(creditToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactIn_redemptionFee_creditTokenToCollateral(
        uint256 amountIn,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountIn       = _bound(amountIn, 1, CREDIT_TOKEN_MAX);
        fee            = _bound(fee, 0, 2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 rawAmountOut = amountIn * conversionRate / 1e27;
        uint256 expectedAmountOut = rawAmountOut - rawAmountOut * fee / 10_000;

        uint256 amountOut = groveBasin.previewSwapExactIn(address(creditToken), address(collateralToken), amountIn);
        assertEq(amountOut, expectedAmountOut);
    }

    function testFuzz_swapExactOut_purchaseFee_swapToCreditToken(
        uint256 amountOut,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountOut      = _bound(amountOut, 1, CREDIT_TOKEN_MAX);
        fee            = _bound(fee, 0, 2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setPurchaseFee(fee);

        uint256 rawAmountIn = Math.ceilDiv(
            Math.ceilDiv(amountOut * conversionRate, 1e27) * 1e6,
            1e18
        );
        uint256 feeAmount = fee == 0 ? 0 : Math.ceilDiv(rawAmountIn * fee, 10_000);
        uint256 expectedAmountIn = rawAmountIn + feeAmount;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), amountOut);
        assertEq(amountIn, expectedAmountIn);
    }

    function testFuzz_swapExactOut_redemptionFee_creditTokenToSwap(
        uint256 amountOut,
        uint256 fee,
        uint256 conversionRate
    ) public {
        amountOut      = _bound(amountOut, 1, SWAP_TOKEN_MAX);
        fee            = _bound(fee, 0, 2000);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);

        mockCreditTokenRateProvider.__setConversionRate(conversionRate);

        vm.prank(owner);
        groveBasin.setRedemptionFee(fee);

        uint256 rawAmountIn = Math.ceilDiv(
            Math.ceilDiv(amountOut * 1e27, conversionRate) * 1e18,
            1e6
        );
        uint256 feeAmount = fee == 0 ? 0 : Math.ceilDiv(rawAmountIn * fee, 10_000);
        uint256 expectedAmountIn = rawAmountIn + feeAmount;

        uint256 amountIn = groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), amountOut);
        assertEq(amountIn, expectedAmountIn);
    }

    function testFuzz_feeAccruesToBasin(
        uint256 amountIn,
        uint256 purchaseFee_,
        uint256 redemptionFee_
    ) public {
        amountIn       = _bound(amountIn, 1e6, SWAP_TOKEN_MAX);
        purchaseFee_   = _bound(purchaseFee_, 1, 2000);
        redemptionFee_ = _bound(redemptionFee_, 1, 2000);

        _deposit(address(collateralToken), makeAddr("depositor"), 10_000e18);

        vm.startPrank(owner);
        groveBasin.setPurchaseFee(purchaseFee_);
        groveBasin.setRedemptionFee(redemptionFee_);
        vm.stopPrank();

        uint256 totalAssetsBefore = groveBasin.totalAssets();

        swapToken.mint(swapper, amountIn);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);
        groveBasin.swapExactIn(address(swapToken), address(creditToken), amountIn, 0, swapper, 0);
        vm.stopPrank();

        assertGe(groveBasin.totalAssets(), totalAssetsBefore);
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

    address lpRole_  = makeAddr("lpRole");
    address swapper = makeAddr("swapper");

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
        vm.stopPrank();

        purchaseFee_   = _bound(purchaseFee_, 0, 2000);
        redemptionFee_ = _bound(redemptionFee_, 0, 2000);

        vm.startPrank(owner);
        groveBasin.setPurchaseFee(purchaseFee_);
        groveBasin.setRedemptionFee(redemptionFee_);
        vm.stopPrank();

        _deposit(address(collateralToken), lp0, _bound(_hash(depositSeed, "lp0-collateralToken"), 1, COLLATERAL_TOKEN_MAX));

        _deposit(address(swapToken),  lp1, _bound(_hash(depositSeed, "lp1-swapToken"),  1, SWAP_TOKEN_MAX));
        _deposit(address(creditToken), lp1, _bound(_hash(depositSeed, "lp1-creditToken"), 1, CREDIT_TOKEN_MAX));

        _deposit(address(collateralToken),  lp2, _bound(_hash(depositSeed, "lp2-collateralToken"),  1, COLLATERAL_TOKEN_MAX));
        _deposit(address(swapToken),  lp2, _bound(_hash(depositSeed, "lp2-swapToken"),  1, SWAP_TOKEN_MAX));
        _deposit(address(creditToken), lp2, _bound(_hash(depositSeed, "lp2-creditToken"), 1, CREDIT_TOKEN_MAX));

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
