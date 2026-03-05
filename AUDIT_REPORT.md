# GroveBasin Smart Contract Audit Report

**Repository:** grove-basin  
**Audited Contracts:**
- `src/GroveBasin.sol`
- `src/UsdsUsdcPocket.sol`
- `src/UsdtPocket.sol`
- `src/oracles/ChronicleRateProvider.sol`
- `src/oracles/FixedRateProvider.sol`
- `deploy/GroveBasinDeploy.sol`

**Language / Compiler:** Solidity `^0.8.34`  
**Date:** 2025

---

## Executive Summary

GroveBasin is a liquidity hub that allows liquidity providers (LPs) to deposit three token types — a *swap token* (e.g. USDC), a *collateral token* (e.g. USDS), and a *credit token* (e.g. sUSDS) — and enables users to swap between them using oracle-derived prices. Liquidity can be routed to external *pocket* contracts (Aave, PSM) to earn yield.

The audit uncovered **two critical/high vulnerabilities** that, without the `GroveBasinDeploy.sol` mitigation, directly lead to **theft of depositor funds**, along with several medium and lower severity issues.

---

## Findings Summary

| # | Title | Severity | Status |
|---|-------|----------|--------|
| 1 | Token Donation Breaks Share Accounting — Pool Drainable When `totalShares == 0` | Critical | Open |
| 2 | Share Inflation Attack — First Depositor Can Steal From Subsequent Depositors | High | Open (partially mitigated by deploy script) |
| 3 | `deposit()` Does Not Revert on Zero Shares Minted | High | Open |
| 4 | `previewSwapExactOut` maxSwapSize Check Excludes Fee Amount | Medium | Open |
| 5 | `UsdtPocket.withdrawLiquidity` Always Returns Requested Amount Regardless of Actual Withdrawn | Medium | Open |
| 6 | `setPocket` Does Not Call `depositLiquidity` on New Pocket | Medium | Open |
| 7 | Silent Failure in `_withdrawLiquidityInPocket` Hides Root Cause | Low | Open |
| 8 | `availableBalance` in `UsdsUsdcPocket` Overstates USDC When PSM Has Fees | Low | Open |
| 9 | Unlimited Slippage in `UsdsUsdcPocket.withdrawLiquidity` | Low | Open |
| 10 | `previewWithdraw` Relies on `msg.sender`, Misleading as a General Preview | Low | Open |
| 11 | Initial Fee Bounds Are Zero — Fees Cannot Be Configured Until Admin Acts | Low | Open |
| 12 | `UsdtPocket.manager` Field Is Unused Dead Code | Informational | Open |
| 13 | `MANAGER_ADMIN_ROLE` Not Granted in Constructor | Informational | Open |
| 14 | Test Suite setUp Broken — `pocket` Not Initialized | Informational | Open |

---

## Detailed Findings

---

### Finding 1 — Critical: Token Donation Breaks Share Accounting — Pool Drainage When `totalShares == 0`

**Severity:** Critical  
**File:** `src/GroveBasin.sol`  
**Lines:** 298–312, 347–367, 447–453, 610–616

#### Root Cause — Bug A: Zero Shares on Deposit

`convertToShares(assetValue)` computes:

```solidity
function convertToShares(uint256 assetValue) public view override returns (uint256) {
    uint256 totalAssets_ = totalAssets();
    if (totalAssets_ != 0) {
        return assetValue * totalShares / totalAssets_;
    }
    return assetValue;
}
```

When `totalShares == 0` but `totalAssets_ != 0` (because tokens were donated directly to the pocket/basin without going through `deposit`), the formula evaluates to:

```
assetValue * 0 / totalAssets_ = 0
```

`deposit()` does not check that the minted `newShares` is non-zero, so the depositor's tokens are transferred in and deployed while their share balance remains zero.

#### Root Cause — Bug B: Zero-Share Withdrawal Drains Pool

`_convertToSharesRoundUp` exhibits the same arithmetic when `totalShares == 0`:

```solidity
function _convertToSharesRoundUp(uint256 assetValue) internal view returns (uint256) {
    uint256 totalValue = totalAssets();
    if (totalValue != 0) {
        return Math.ceilDiv(assetValue * totalShares, totalValue);
        // = Math.ceilDiv(assetValue * 0, totalValue) = 0
    }
    return assetValue;
}
```

`previewWithdraw` therefore computes `sharesToBurn = 0` regardless of how large the withdrawal is. Since `shares[attacker] = 0` and `sharesToBurn = 0`, the guard `if (sharesToBurn > userShares)` is `0 > 0 = false`, so it is not triggered. The function returns `(sharesToBurn=0, assetsWithdrawn=fullBalance)`. `withdraw()` proceeds to transfer the entire pool balance to the caller.

**Any address — including one with zero share balance — can drain the entire pool when `totalShares == 0`.**

#### Attack Scenario

1. Attacker sends 100 USDC directly to the basin/pocket (`transfer`, not `deposit`). `totalAssets = $100`, `totalShares = 0`.
2. Victim calls `deposit(swapToken, victim, 1_000_000e6)`. `convertToShares` returns 0. The million USDC is transferred in, but `shares[victim] = 0`. `totalShares` remains 0.
3. Attacker (or any other address with 0 shares) calls `withdraw(swapToken, attacker, type(uint256).max)`. `sharesToBurn = 0`, `assetsWithdrawn = 1,000,100 USDC`. The entire pool is drained.
4. Victim subsequently calls `withdraw` and receives nothing.

**Attacker profit: $1,000,000 USD. Victim loss: $1,000,000 USD.**

Furthermore, if multiple victims deposit and then race to withdraw, only the first caller retrieves any funds; all others lose their entire deposit.

#### Proof-of-Concept

See `test/unit/AuditTests.t.sol`:
- `DonationAttackTest.test_donationAttack_depositorGetsZeroShares` — demonstrates Bug A
- `DonationAttackTest.test_donationAttack_anyCallerCanDrainPool` — demonstrates Bug B (pool drainage by attacker)
- `DonationAttackTest.test_donationAttack_raceConditionMultipleDepositors` — demonstrates multiple victims losing to first withdrawer

#### Existing Mitigation

`deploy/GroveBasinDeploy.sol` makes an initial deposit of 1 USDC to `address(0)` as part of the deployment flow, establishing `totalShares = 1e18` before any external interaction. With non-zero `totalShares`, the `_convertToSharesRoundUp` denominator is non-zero and Bug B is not triggered; subsequent donations also cannot bring `totalShares` back to zero (shares can only decrease via legitimate withdrawals).

This mitigation is **not enforced in the constructor**, however:
- A deployment that does not use `GroveBasinDeploy.deploy()` leaves the contract in a vulnerable initial state.
- If the deployer lacks the 1 USDC balance needed for the initial deposit, the deployment will succeed but the contract will be unprotected.

#### Remediation

1. **Guard against zero shares in `deposit()`:**
   ```solidity
   require(newShares != 0, "GroveBasin/zero-shares-minted");
   ```

2. **Guard against zero-share drain in `withdraw()`:**
   ```solidity
   require(shares[msg.sender] != 0, "GroveBasin/no-shares");
   // (previewWithdraw already handles the cap correctly when totalShares > 0)
   ```

3. **Move the dead-shares deposit into the constructor** so the invariant is guaranteed regardless of which deployment path is used.

---

### Finding 2 — High: Share Inflation Attack — First Depositor Can Steal From Subsequent Depositors

**Severity:** High  
**File:** `src/GroveBasin.sol`  
**Lines:** 298–312, 447–453  
**Reference:** `test/unit/InflationAttack.t.sol`

#### Root Cause

The standard ERC-4626 share inflation attack applies here. An attacker who obtains a tiny number of shares (e.g., 1) can subsequently donate a large amount of assets to inflate the price-per-share, causing the next depositor's shares to round down severely.

#### Attack Scenario (Without Deploy Script Mitigation)

1. Attacker deposits 1 wei credit token → receives 1 share.
2. Attacker donates 10,000,000 USDC directly to the basin. Price-per-share becomes 10,000,000+ USD per share.
3. First legitimate depositor deposits 20,000,000 USDC. `convertToShares` computes `20M / 10M = 1` share (rounding down).
4. Both attacker and depositor now have 1 share each, out of total 2 shares.
5. Both withdraw: each gets ~15M USDC. Attacker profits ~5M USDC at depositor's expense.

This is documented in `test/unit/InflationAttack.t.sol`. The `_runInflationAttack_noInitialDepositTest` test confirms:
```
assertEq(swapToken.balanceOf(frontRunner),    15_000_000e6);  // Attacker profits
assertEq(swapToken.balanceOf(firstDepositor), 15_000_000e6);  // Victim loses 5M
```

#### Proof-of-Concept

See `test/unit/AuditTests.t.sol` → `InflationAttackTest.test_inflationAttack_swapToken`.

#### Existing Mitigation

`GroveBasinDeploy.deploy()` deposits 1 USDC ($1 USD = 1e18 shares) to `address(0)`. With 1e18 dead shares, inflating price-per-share to produce rounding losses requires donations many orders of magnitude larger than realistic amounts, making the attack economically infeasible in practice.

#### Residual Risk

If the deploy script is not used or the initial deposit is too small, this attack remains viable.

#### Remediation

- Ensure the dead-shares deposit is mandatory and embedded in the constructor.
- Add the minimum shares check from Finding 3 as a defence-in-depth measure.

---

### Finding 3 — High: `deposit()` Does Not Revert on Zero Shares Minted

**Severity:** High  
**File:** `src/GroveBasin.sol`  
**Lines:** 298–312

#### Description

`deposit()` does not assert that `newShares > 0` before completing. This is the root condition for Bug A in Finding 1 (depositor receives zero shares after a donation attack). Without this guard, a user can deposit tokens and receive nothing in return.

Beyond the donation attack, this can also occur legitimately when a deposited amount is so small that `_getAssetValue(asset, amount) * totalShares / totalAssets` truncates to zero. In that case, the user pays for a deposit they cannot undo.

#### Remediation

```solidity
function deposit(address asset, address receiver, uint256 assetsToDeposit)
    external override returns (uint256 newShares)
{
    require(assetsToDeposit != 0, "GroveBasin/invalid-amount");
    newShares = previewDeposit(asset, assetsToDeposit);
    require(newShares != 0, "GroveBasin/zero-shares-minted");  // ADD THIS
    ...
}
```

---

### Finding 4 — Medium: `previewSwapExactOut` maxSwapSize Check Excludes Fee Amount

**Severity:** Medium  
**File:** `src/GroveBasin.sol`  
**Lines:** 389–403

#### Root Cause

In `previewSwapExactOut`, the `maxSwapSize` guard is evaluated on the base `amountIn` **before** fees are added:

```solidity
function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
    public view override returns (uint256 amountIn)
{
    // Round up to get amountIn
    amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);

    require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize,  // ← checked here
            "GroveBasin/swap-size-exceeded");

    // Fee is added AFTER the check
    if (assetOut == address(creditToken)) {
        amountIn += _calculatePurchaseFee(amountIn, true);          // ← fee added here
    } else {
        amountIn += _calculateRedemptionFee(amountIn, true);
    }
}
```

The actual amount the user pays — `amountIn + fee` — can exceed `maxSwapSize`. With a 50% fee and a maxSwapSize of $100, a user can effectively route $150 through the pool in a single swap.

#### Impact

- The operator-controlled circuit breaker (`maxSwapSize`) can be exceeded by the fee amount, undermining its intended protection (e.g., against oracle manipulation or liquidity drainage).
- At typical fee rates (0–3%) the excess is small, but at the protocol-permitted maximum of 100% (`maxFee = BPS = 10_000`), the bypass factor is 2×.

#### Proof-of-Concept

See `test/unit/AuditTests.t.sol` → `MaxSwapSizeFeeBypassTest.test_maxSwapSize_feeNotIncludedInCheck`.

#### Remediation

Move the size check **after** fees are computed, or check against the total `amountIn` (including fee):

```solidity
amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);

if (assetOut == address(creditToken)) {
    amountIn += _calculatePurchaseFee(amountIn, true);
} else {
    amountIn += _calculateRedemptionFee(amountIn, true);
}

// Check AFTER fee so the total amount paid is validated
require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize,
        "GroveBasin/swap-size-exceeded");
```

---

### Finding 5 — Medium: `UsdtPocket.withdrawLiquidity` Always Returns Requested Amount Regardless of Actual Withdrawn

**Severity:** Medium  
**File:** `src/UsdtPocket.sol`  
**Lines:** 70–93

#### Root Cause

`UsdtPocket.withdrawLiquidity` always returns `amount` (the *requested* amount), even when Aave's `withdraw` returns a different (smaller) value:

```solidity
function withdrawLiquidity(uint256 amount, address asset) external override onlyBasin returns (uint256) {
    ...
    uint256 balance = usdt.balanceOf(address(this));
    uint256 convertedAmount;

    if (balance < amount) {
        uint256 remainder = amount - balance;
        aUsdt.safeApprove(aaveV3Pool, remainder);
        convertedAmount = IAaveV3PoolLike(aaveV3Pool).withdraw(  // May return < remainder
            address(usdt), remainder, address(this)
        );
    }

    emit LiquidityDrawn(asset, amount, convertedAmount);
    return amount;  // ← ALWAYS returns requested amount
}
```

Aave V3's `withdraw` function can return less than requested in edge cases (rounding, protocol precision). In `GroveBasin._withdrawLiquidityInPocket`, the return value of `withdrawLiquidity` is *ignored* for the swap-token path (wrapped in try/catch). However, for a hypothetical future collateral-token pocket that follows the same pattern, the return value is trusted:

```solidity
try IGroveBasinPocket(pocket).withdrawLiquidity(deficit, asset) returns (uint256 drawn) {
    IERC20(asset).safeTransferFrom(pocket, address(this), drawn);  // Uses returned value
} catch {}
```

If `drawn` exceeds the actual token balance of the pocket, `safeTransferFrom` reverts.

#### Impact

- **Current scope:** For swap tokens (USDT in UsdtPocket), the return value is unused, so no immediate issue.
- **Forward-looking:** A future pocket handling collateral tokens would be affected. The overstatement can cause reverts in `_withdrawLiquidityInPocket`.

#### Remediation

Return the actual amount withdrawn from Aave:

```solidity
return balance >= amount ? amount : balance + convertedAmount;
```

The same applies to `UsdsUsdcPocket.withdrawLiquidity`.

---

### Finding 6 — Medium: `setPocket` Does Not Call `depositLiquidity` on New Pocket

**Severity:** Medium  
**File:** `src/GroveBasin.sol`  
**Lines:** 176–205

#### Root Cause

When `setPocket` migrates liquidity from the old pocket to the new one, it transfers the raw swap token balance but does **not** call `depositLiquidity` on the new pocket:

```solidity
function setPocket(address newPocket) external override onlyRole(MANAGER_ADMIN_ROLE) {
    ...
    if (_hasPocket()) {
        uint256 availableBalance = IGroveBasinPocket(pocket_).availableBalance(...);
        if (availableBalance > 0) {
            IGroveBasinPocket(pocket_).withdrawLiquidity(availableBalance, ...);
        }
    }

    uint256 amountToTransfer = swapToken.balanceOf(pocket_);

    if (!_hasPocket()) {
        swapToken.safeTransfer(newPocket, amountToTransfer);
    } else {
        swapToken.safeTransferFrom(pocket_, newPocket, amountToTransfer);
    }

    pocket = newPocket;
    // ← depositLiquidity on newPocket is never called
}
```

For `UsdtPocket`, tokens must be deposited to Aave to earn yield. After migration, the USDT sits as raw balance in the new pocket indefinitely (until new deposits trigger `_depositLiquidityInPocket`).

#### Impact

- Migrated funds do not earn yield until the next swap-token deposit.
- For large pools, this can represent significant forgone revenue.

#### Remediation

After transferring funds to `newPocket`, call `depositLiquidity` if the new pocket is not `address(this)`:

```solidity
if (newPocket != address(this) && amountToTransfer > 0) {
    IGroveBasinPocket(newPocket).depositLiquidity(amountToTransfer, address(swapToken));
}
```

---

### Finding 7 — Low: Silent Failure in `_withdrawLiquidityInPocket` Hides Root Cause

**Severity:** Low  
**File:** `src/GroveBasin.sol`  
**Lines:** 629–644

#### Root Cause

The swap-token withdrawal path wraps the pocket call in a bare try/catch that discards both the return value and the error:

```solidity
function _withdrawLiquidityInPocket(uint256 amount, address asset) internal {
    if (!_hasPocket()) return;

    if (asset == address(swapToken)) {
        try IGroveBasinPocket(pocket).withdrawLiquidity(amount, asset) {} catch {}
        //                                                             ^^^^^^^^^^^
        // Error swallowed; return value ignored
    }
    ...
}
```

If `withdrawLiquidity` fails (e.g., Aave is paused, liquidity cap reached, or pocket is misconfigured), no indication is surfaced. The subsequent `_pushAsset` call will then fail with a generic ERC20 transfer error, making it harder to diagnose the true problem.

#### Impact

Operationally, operators and users receive confusing revert messages. In practice, the transaction still reverts atomically (no fund loss), because `_pushAsset` will revert if the pocket didn't produce the tokens.

#### Remediation

At minimum, re-throw meaningful errors or add a balance check post-withdrawal:

```solidity
try IGroveBasinPocket(pocket).withdrawLiquidity(amount, asset) {
    // Verify the pocket now has enough balance
    require(
        IERC20(asset).balanceOf(pocket) >= amount,
        "GroveBasin/pocket-withdrawal-insufficient"
    );
} catch (bytes memory reason) {
    // Re-throw with context
    assembly { revert(add(reason, 32), mload(reason)) }
}
```

---

### Finding 8 — Low: `availableBalance` in `UsdsUsdcPocket` Overstates USDC When PSM Has Fees

**Severity:** Low  
**File:** `src/UsdsUsdcPocket.sol`  
**Lines:** 83–91

#### Root Cause

`availableBalance` computes available USDC as:

```solidity
return usdc.balanceOf(address(this))
    + usds.balanceOf(address(this)) * _usdcPrecision / _usdsPrecision;
```

This assumes a 1:1 conversion from USDS to USDC through the PSM. If the PSM charges a fee (e.g., `tin` or `tout` in the Maker PSM model), the actual USDC obtainable from USDS is:

```
usds_balance * usdcPrecision / usdsPrecision * (1 - psmFee)
```

The overstatement of `availableBalance` causes `previewWithdraw` to show users they can withdraw more than the pocket can actually deliver. When `withdrawLiquidity` is subsequently called, the PSM would consume more USDS than the pocket holds or return fewer USDC units than expected.

#### Impact

- Users see inflated withdrawal previews.
- `withdrawLiquidity` may fail if the actual USDC obtained falls short.
- Potential revert during `setPocket` migration if the PSM has fees.

#### Remediation

Query the PSM for the actual conversion rate, or apply a known fee factor to the USDS portion of `availableBalance`.

---

### Finding 9 — Low: Unlimited Slippage in `UsdsUsdcPocket.withdrawLiquidity`

**Severity:** Low  
**File:** `src/UsdsUsdcPocket.sol`  
**Lines:** 72–88

#### Root Cause

When withdrawing USDC by converting USDS via the PSM, the maximum USDS that may be spent is set to `type(uint256).max`:

```solidity
convertedAmount = IPSMLike(psm).swapExactOut(
    address(usds),
    address(usdc),
    remainder,
    type(uint256).max,  // ← no slippage protection
    address(this),
    0
);
```

#### Impact

If the PSM's exchange rate degrades (e.g., during a governance attack, a depeg event, or a misconfiguration), the pocket would spend an unbounded amount of USDS to obtain the requested USDC. This could drain the pocket's USDS reserves far beyond the nominal exchange rate.

#### Remediation

Compute and pass a sensible `maxAmountIn` based on the expected 1:1 rate plus a small tolerance (e.g., 0.1%):

```solidity
uint256 maxUsdsIn = remainder * _usdsPrecision / _usdcPrecision * 10_010 / 10_000; // 0.1% slippage
convertedAmount = IPSMLike(psm).swapExactOut(
    address(usds),
    address(usdc),
    remainder,
    maxUsdsIn,
    address(this),
    0
);
```

---

### Finding 10 — Low: `previewWithdraw` Relies on `msg.sender`, Misleading as a General Preview

**Severity:** Low  
**File:** `src/GroveBasin.sol`  
**Lines:** 347–367

#### Root Cause

`previewWithdraw` is a `public view` function intended for off-chain previews, but it internally reads `shares[msg.sender]`:

```solidity
function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
    public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
{
    ...
    uint256 userShares = shares[msg.sender];  // ← depends on caller identity

    if (sharesToBurn > userShares) {
        assetsWithdrawn = convertToAssets(asset, userShares);
        sharesToBurn    = userShares;
    }
}
```

When called from a UI contract, an aggregator, or any address other than the actual withdrawer, `msg.sender` refers to that intermediary, not the user. The result is therefore incorrect: the function either shows more or less than the user could actually withdraw.

#### Proof-of-Concept

See `test/unit/AuditTests.t.sol` → `PreviewWithdrawMsgSenderTest.test_previewWithdraw_incorrectForThirdPartyCallers`.

#### Impact

Incorrect off-chain previews lead to a poor user experience and potential griefing (e.g., a UI showing a user can withdraw funds they cannot).

#### Remediation

Add an explicit `account` parameter:

```solidity
function previewWithdraw(address asset, uint256 maxAssetsToWithdraw, address account)
    public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
{
    ...
    uint256 userShares = shares[account];
    ...
}
```

Maintain a backward-compatible overload that uses `msg.sender` for the internal `withdraw()` call path.

---

### Finding 11 — Low: Initial Fee Bounds Are Zero — Fees Cannot Be Configured Until Admin Acts

**Severity:** Low  
**File:** `src/GroveBasin.sol`  
**Lines:** 43–46, 149–174

#### Root Cause

`minFee` and `maxFee` both default to `0`. `_setPurchaseFee` and `_setRedemptionFee` enforce:

```solidity
require(newPurchaseFee >= minFee && newPurchaseFee <= maxFee, "GroveBasin/purchase-fee-out-of-bounds");
```

With `maxFee == 0`, the only valid fee value is `0`. A `MANAGER` cannot configure any non-zero fee until a `MANAGER_ADMIN` calls `setFeeBounds` first.

#### Impact

- If operators forget to call `setFeeBounds` before granting MANAGER_ROLE and expecting fee revenue, the protocol earns no fees.
- The silent constraint is non-obvious; `setPurchaseFee(50)` reverts with a confusing "out-of-bounds" message that obscures the real cause (bounds not set).

#### Remediation

Either set non-zero default bounds in the constructor, or add a more descriptive check:

```solidity
require(maxFee != 0, "GroveBasin/fee-bounds-not-set");
```

---

### Finding 12 — Informational: `UsdtPocket.manager` Field Is Unused Dead Code

**Severity:** Informational  
**File:** `src/UsdtPocket.sol`  
**Lines:** 18, 31, 45

#### Description

`UsdtPocket` stores a `manager` address:

```solidity
address public immutable manager;
```

This field is assigned in the constructor but never referenced in any function. It suggests that access control for the pocket (e.g., to call `depositLiquidity` or change the pool) was planned but not implemented.

#### Remediation

Either implement the intended access control using `manager`, or remove the field to reduce deployment cost and eliminate confusion.

---

### Finding 13 — Informational: `MANAGER_ADMIN_ROLE` Not Granted in Constructor

**Severity:** Informational  
**File:** `src/GroveBasin.sol`  
**Lines:** 107–109

#### Description

The constructor grants `OWNER_ROLE` to the owner but does **not** grant `MANAGER_ADMIN_ROLE` to anyone:

```solidity
_grantRole(OWNER_ROLE, owner_);
_setRoleAdmin(MANAGER_ROLE, MANAGER_ADMIN_ROLE);
// MANAGER_ADMIN_ROLE is never granted
```

Until the owner explicitly calls `grantRole(MANAGER_ADMIN_ROLE, someAddress)`, no one can call `setMaxSwapSize`, `setStalenessThresholdBounds`, `setFeeBounds`, or `setPocket`. The contract is therefore deployed in a partially-locked state.

#### Impact

Operational risk: if the owner forgets this step, the protocol configuration functions are inaccessible.

#### Remediation

Grant `MANAGER_ADMIN_ROLE` to the owner in the constructor, or document the required post-deployment setup clearly.

---

### Finding 14 — Informational: Test Suite setUp Broken — `pocket` Not Initialized

**Severity:** Informational  
**File:** `test/GroveBasinTestBase.sol`  
**Lines:** 17, 71

#### Description

`GroveBasinTestBase` declares `pocket` without initialisation:

```solidity
address public pocket;  // = address(0)
```

`setUp()` then calls:

```solidity
groveBasin.setPocket(pocket);  // setPocket(address(0)) — reverts!
```

`setPocket` enforces `require(newPocket != address(0), "GroveBasin/invalid-pocket")`. This causes the entire `setUp` call to revert, which in Foundry marks every test in contracts that inherit `GroveBasinTestBase` (without overriding `pocket`) as failed.

Test contracts affected include: `GroveBasinDepositTests`, `InflationAttackTests`, `DoSAttackTests`, `GroveBasinSwapExactInFailureTests`, `GroveBasinSwapExactOutFailureTests`, `GroveBasinSetFeeBoundsFailureTests`, `RoundingTests`, and several others.

#### Remediation

Initialise `pocket` to a valid address. The simplest fix is to assign it to the groveBasin address itself (self-pocket mode), which is the initial state anyway:

```solidity
// In setUp(), after constructing groveBasin:
pocket = address(groveBasin);
```

Or use `makeAddr("pocket")` combined with appropriate ERC20 approvals.

---

## Additional Observations

### Oracle Staleness Protection is Well Implemented

`_getConversionRate` validates `block.timestamp - lastUpdated <= stalenessThreshold` for every oracle call. `FixedRateProvider` returns `block.timestamp` as age, so it never goes stale — by design. The configurable `stalenessThreshold` (default 5 minutes, bounded between 5 minutes and 12 hours) provides reasonable freshness guarantees.

**Edge case:** If a Chronicle oracle ever returns a `lastUpdated` timestamp that is in the future (i.e., `lastUpdated > block.timestamp`), the subtraction `block.timestamp - lastUpdated` would underflow and revert with a Solidity arithmetic error rather than the intended `"GroveBasin/stale-rate"` message. Although Chronicle oracles are designed to be well-behaved, a defensive `require(lastUpdated <= block.timestamp)` check before the subtraction would improve clarity.

### Rounding Consistently Favours the Protocol

`previewDeposit` rounds down shares (so depositors get fewer shares than the exact mathematical value), and `previewWithdraw` rounds up shares-to-burn. This consistent rounding direction protects against exploits that try to extract more value than deposited.

### `SafeERC20` Handles Non-Standard Tokens Correctly

The `erc20-helpers/SafeERC20.sol` library correctly handles USDT-style tokens that require allowance to be reset to zero before setting a new value. The two-step approve pattern (`approve(0)` then `approve(amount)`) is only triggered when the first attempt fails.

### Reentrancy Analysis

State updates in `deposit` and `withdraw` occur **before** external token transfers (checks-effects-interactions pattern). No reentrant callback can profitably exploit these functions. Swaps carry no state-changing operations of concern either.

### Integer Overflow / Underflow

Solidity 0.8.34 provides built-in overflow protection. Intermediate products in rate calculations (`amount * rate`) stay within uint256 bounds for realistic token amounts and rate values.

---

## Appendix: Test Files

The following test file was created as part of this audit to provide executable proof-of-concept for the critical/high findings:

- `test/unit/AuditTests.t.sol`
  - `DonationAttackTest` — demonstrates permanent fund loss via token donation (Finding 1)
  - `InflationAttackTest` — demonstrates share inflation and theft (Finding 2)
  - `MaxSwapSizeFeeBypassTest` — demonstrates fee bypass of maxSwapSize (Finding 4)
  - `PreviewWithdrawMsgSenderTest` — demonstrates incorrect previews for third-party callers (Finding 10)
