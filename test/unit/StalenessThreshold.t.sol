// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockERC20, MockRateProvider, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

import { GroveBasinHarness } from "test/unit/harnesses/GroveBasinHarness.sol";

/**********************************************************************************************/
/*** setStalenessThreshold tests                                                            ***/
/**********************************************************************************************/

contract GroveBasinSetStalenessThresholdFailureTests is GroveBasinTestBase {

    address manager = makeAddr("manager");

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();
    }

    function test_setStalenessThreshold_notManager() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ROLE()
            )
        );
        groveBasin.setStalenessThreshold(1 hours);
    }

    function test_setStalenessThreshold_zero() public {
        vm.prank(manager);
        vm.expectRevert("GroveBasin/threshold-too-low");
        groveBasin.setStalenessThreshold(0);
    }

    function test_setStalenessThreshold_sameThresholdNonZero() public {
        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 hours);

        vm.prank(manager);
        vm.expectRevert("GroveBasin/same-staleness-threshold");
        groveBasin.setStalenessThreshold(1 hours);
    }

    function test_setStalenessThreshold_tooLow() public {
        vm.prank(manager);
        vm.expectRevert("GroveBasin/threshold-too-low");
        groveBasin.setStalenessThreshold(5 minutes - 1);
    }

    function test_setStalenessThreshold_tooHigh() public {
        vm.prank(manager);
        vm.expectRevert("GroveBasin/threshold-too-high");
        groveBasin.setStalenessThreshold(48 hours + 1);
    }

    function test_setStalenessThreshold_minimumBoundary() public {
        vm.prank(manager);
        vm.expectRevert("GroveBasin/threshold-too-low");
        groveBasin.setStalenessThreshold(1);

        vm.prank(manager);
        groveBasin.setStalenessThreshold(10 minutes);

        assertEq(groveBasin.stalenessThreshold(), 10 minutes);
    }

}

/**********************************************************************************************/
/*** setStalenessThresholdBounds tests                                                      ***/
/**********************************************************************************************/

contract GroveBasinSetStalenessThresholdBoundsFailureTests is GroveBasinTestBase {

    function test_setStalenessThresholdBounds_notManagerAdmin() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                groveBasin.MANAGER_ADMIN_ROLE()
            )
        );
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);
    }

    function test_setStalenessThresholdBounds_minZero() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/min-threshold-zero");
        groveBasin.setStalenessThresholdBounds(0, 24 hours);
    }

    function test_setStalenessThresholdBounds_minGtMax() public {
        vm.prank(owner);
        vm.expectRevert("GroveBasin/min-gt-max-threshold");
        groveBasin.setStalenessThresholdBounds(2 hours, 1 hours);
    }

}

contract GroveBasinSetStalenessThresholdBoundsSuccessTests is GroveBasinTestBase {

    address manager = makeAddr("manager");

    event StalenessThresholdBoundsSet(
        uint256 oldMinThreshold,
        uint256 oldMaxThreshold,
        uint256 newMinThreshold,
        uint256 newMaxThreshold
    );
    event StalenessThresholdSet(uint256 oldThreshold, uint256 newThreshold);

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();
    }

    function test_setStalenessThresholdBounds_defaults() public view {
        assertEq(groveBasin.minStalenessThreshold(), 5 minutes);
        assertEq(groveBasin.maxStalenessThreshold(), 48 hours);
    }

    function test_setStalenessThresholdBounds() public {
        vm.prank(owner);

        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdBoundsSet(5 minutes, 48 hours, 1 minutes, 24 hours);
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);

        assertEq(groveBasin.minStalenessThreshold(), 1 minutes);
        assertEq(groveBasin.maxStalenessThreshold(), 24 hours);
    }

    function test_setStalenessThresholdBounds_clampsThresholdUp() public {
        vm.prank(manager);
        groveBasin.setStalenessThreshold(10 minutes);

        vm.prank(owner);

        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdBoundsSet(5 minutes, 48 hours, 30 minutes, 24 hours);
        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdSet(10 minutes, 30 minutes);
        groveBasin.setStalenessThresholdBounds(30 minutes, 24 hours);

        assertEq(groveBasin.stalenessThreshold(), 30 minutes);
    }

    function test_setStalenessThresholdBounds_clampsThresholdDown() public {
        vm.prank(manager);
        groveBasin.setStalenessThreshold(6 hours);

        vm.prank(owner);
        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdBoundsSet(5 minutes, 48 hours, 1 minutes, 2 hours);
        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdSet(6 hours, 2 hours);
        groveBasin.setStalenessThresholdBounds(1 minutes, 2 hours);

        assertEq(groveBasin.stalenessThreshold(), 2 hours);
    }

    function test_setStalenessThresholdBounds_noClampWhenWithinBounds() public {
        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 hours);

        vm.prank(owner);
        groveBasin.setStalenessThresholdBounds(30 minutes, 2 hours);

        assertEq(groveBasin.stalenessThreshold(), 1 hours);
    }

    function test_setStalenessThresholdBounds_equalMinMax() public {
        vm.prank(owner);
        groveBasin.setStalenessThresholdBounds(1 hours, 1 hours);

        assertEq(groveBasin.minStalenessThreshold(), 1 hours);
        assertEq(groveBasin.maxStalenessThreshold(), 1 hours);
        assertEq(groveBasin.stalenessThreshold(),    1 hours);
    }

    function test_setStalenessThreshold_respectsNewBounds() public {
        vm.prank(owner);
        groveBasin.setStalenessThresholdBounds(1 minutes, 24 hours);

        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 minutes);
        assertEq(groveBasin.stalenessThreshold(), 1 minutes);

        vm.prank(manager);
        groveBasin.setStalenessThreshold(24 hours);
        assertEq(groveBasin.stalenessThreshold(), 24 hours);

        vm.prank(manager);
        vm.expectRevert("GroveBasin/threshold-too-high");
        groveBasin.setStalenessThreshold(24 hours + 1);
    }

}

contract GroveBasinSetStalenessThresholdSuccessTests is GroveBasinTestBase {

    address manager = makeAddr("manager");

    event StalenessThresholdSet(uint256 oldThreshold, uint256 newThreshold);

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();
    }

    function test_setStalenessThreshold() public {
        assertEq(groveBasin.stalenessThreshold(), 5 minutes);

        vm.prank(manager);
        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdSet(5 minutes, 1 hours);
        groveBasin.setStalenessThreshold(1 hours);

        assertEq(groveBasin.stalenessThreshold(), 1 hours);
    }

    function test_setStalenessThreshold_update() public {
        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 hours);

        vm.prank(manager);
        vm.expectEmit(address(groveBasin));
        emit StalenessThresholdSet(1 hours, 2 hours);
        groveBasin.setStalenessThreshold(2 hours);

        assertEq(groveBasin.stalenessThreshold(), 2 hours);
    }

    function test_setStalenessThreshold_cannotDisable() public {
        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 hours);

        vm.prank(manager);
        vm.expectRevert("GroveBasin/threshold-too-low");
        groveBasin.setStalenessThreshold(0);
    }

}

/**********************************************************************************************/
/*** Staleness check tests                                                                  ***/
/**********************************************************************************************/

contract GroveBasinStalenessCheckTests is GroveBasinTestBase {

    address swapper  = makeAddr("swapper");
    address receiver = makeAddr("receiver");
    address manager  = makeAddr("manager");

    function setUp() public override {
        super.setUp();

        vm.warp(10 hours);

        mockSwapTokenRateProvider.__setConversionRate(1e27);
        mockCollateralTokenRateProvider.__setConversionRate(1e27);
        mockCreditTokenRateProvider.__setConversionRate(1.25e27);

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.prank(manager);
        groveBasin.setStalenessThreshold(1 hours);

        _deposit(address(collateralToken), makeAddr("seeder"), 1_000_000e18);
        _deposit(address(swapToken),       makeAddr("seeder"), 1_000_000e6);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000_000e18);

        _deposit(address(swapToken), swapper, 10_000e6);
    }

    /**********************************************************************************************/
    /*** Default threshold (minStalenessThreshold) enforces staleness                            ***/
    /**********************************************************************************************/

    function test_defaultThreshold_staleRateReverts() public {
        GroveBasin freshBasin = new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertEq(freshBasin.stalenessThreshold(), 5 minutes);

        collateralToken.mint(address(freshBasin), 1e18);

        mockSwapTokenRateProvider.__setLastUpdated(1);

        vm.expectRevert("GroveBasin/stale-rate");
        freshBasin.totalAssets();
    }

    /**********************************************************************************************/
    /*** totalAssets reverts on stale rate                                                       ***/
    /**********************************************************************************************/

    function test_totalAssets_staleSwapRate() public {
        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.totalAssets();
    }

    function test_totalAssets_staleCollateralRate() public {
        mockCollateralTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.totalAssets();
    }

    function test_totalAssets_staleCreditRate() public {
        mockCreditTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.totalAssets();
    }

    function test_totalAssets_freshRates() public {
        assertGt(groveBasin.totalAssets(), 0);
    }

    /**********************************************************************************************/
    /*** Boundary: exactly at threshold is allowed, threshold + 1 reverts                       ***/
    /**********************************************************************************************/

    function test_staleness_boundary() public {
        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours);

        assertGt(groveBasin.totalAssets(), 0);

        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.totalAssets();
    }

    /**********************************************************************************************/
    /*** Swaps revert on stale rate                                                             ***/
    /**********************************************************************************************/

    function test_swapExactIn_staleRate() public {
        mockCreditTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        swapToken.mint(swapper, 100e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 100e6);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.swapExactIn(address(swapToken), address(creditToken), 100e6, 0, receiver, 0);
    }

    function test_swapExactOut_staleRate() public {
        mockCreditTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        swapToken.mint(swapper, 200e6);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), 200e6);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.swapExactOut(address(swapToken), address(creditToken), 80e18, 200e6, receiver, 0);
    }

    /**********************************************************************************************/
    /*** Deposits revert on stale rate                                                          ***/
    /**********************************************************************************************/

    function test_deposit_staleRate() public {
        mockCreditTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        creditToken.mint(swapper, 100e18);
        vm.startPrank(swapper);
        creditToken.approve(address(groveBasin), 100e18);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.deposit(address(creditToken), swapper, 100e18);
    }

    /**********************************************************************************************/
    /*** Withdrawals revert on stale rate                                                       ***/
    /**********************************************************************************************/

    function test_withdraw_staleRate() public {
        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.prank(swapper);
        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.withdraw(address(swapToken), swapper, 100e6);
    }

    /**********************************************************************************************/
    /*** Preview functions revert on stale rate                                                 ***/
    /**********************************************************************************************/

    function test_previewSwapExactIn_staleRate() public {
        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6);
    }

    function test_previewSwapExactOut_staleRate() public {
        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18);
    }

    function test_previewDeposit_staleRate() public {
        mockCollateralTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.previewDeposit(address(collateralToken), 100e18);
    }

    function test_previewWithdraw_staleRate() public {
        mockCreditTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.previewWithdraw(address(creditToken), 100e18);
    }

    /**********************************************************************************************/
    /*** convertToAssets and convertToShares revert on stale rate                               ***/
    /**********************************************************************************************/

    function test_convertToAssets_staleRate() public {
        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.convertToAssets(address(swapToken), 100e18);
    }

    function test_convertToShares_asset_staleRate() public {
        mockCollateralTokenRateProvider.__setLastUpdated(block.timestamp - 1 hours - 1);

        vm.expectRevert("GroveBasin/stale-rate");
        groveBasin.convertToShares(address(collateralToken), 100e18);
    }

    /**********************************************************************************************/
    /*** _getConversionRate harness tests                                                    ***/
    /**********************************************************************************************/

    function test_getConversionRate_fresh() public {
        GroveBasinHarness harness = new GroveBasinHarness(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        harness.grantRole(harness.MANAGER_ADMIN_ROLE(), owner);
        harness.grantRole(harness.MANAGER_ROLE(),       manager);
        vm.stopPrank();

        vm.prank(manager);
        harness.setStalenessThreshold(1 hours);

        uint256 rate = harness.getConversionRate(address(swapTokenRateProvider));
        assertEq(rate, 1e27);
    }

    function test_getConversionRate_stale() public {
        GroveBasinHarness harness = new GroveBasinHarness(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        harness.grantRole(harness.MANAGER_ADMIN_ROLE(), owner);
        harness.grantRole(harness.MANAGER_ROLE(),    manager);
        vm.stopPrank();

        vm.prank(manager);
        harness.setStalenessThreshold(1 hours);

        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - 2 hours);

        vm.expectRevert("GroveBasin/stale-rate");
        harness.getConversionRate(address(swapTokenRateProvider));
    }

    function test_getConversionRate_defaultThresholdEnforced() public {
        GroveBasinHarness harness = new GroveBasinHarness(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        mockSwapTokenRateProvider.__setLastUpdated(1);

        vm.expectRevert("GroveBasin/stale-rate");
        harness.getConversionRate(address(swapTokenRateProvider));
    }

    /**********************************************************************************************/
    /*** Fuzz tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_staleness_boundary(uint256 threshold, uint256 age) public {
        threshold = _bound(threshold, 5 minutes, 48 hours);
        age       = _bound(age, 0, block.timestamp);

        if (threshold != groveBasin.stalenessThreshold()) {
            vm.prank(manager);
            groveBasin.setStalenessThreshold(threshold);
        }

        mockSwapTokenRateProvider.__setLastUpdated(block.timestamp - age);
        mockCollateralTokenRateProvider.__setLastUpdated(block.timestamp);
        mockCreditTokenRateProvider.__setLastUpdated(block.timestamp);

        if (age > threshold) {
            vm.expectRevert("GroveBasin/stale-rate");
            groveBasin.totalAssets();
        } else {
            assertGt(groveBasin.totalAssets(), 0);
        }
    }

}
