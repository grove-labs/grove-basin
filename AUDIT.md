# GroveBasin Smart Contract Security Audit

**Repository:** grove-basin  
**Audit Date:** 2025  
**Auditor:** Smart Contract Auditor Agent  
**Contracts In Scope:**
- `src/GroveBasin.sol` — Main protocol contract
- `src/interfaces/IGroveBasin.sol` — Interface
- `src/interfaces/IRateProviderLike.sol` — Rate provider interface
- `deploy/GroveBasinDeploy.sol` — Deployment library
- `script/Deploy.s.sol` — Deployment script

---

## Executive Summary

GroveBasin is a three-asset liquidity pool supporting a `swapToken` (e.g., USDC), a `collateralToken` (e.g., USDS), and a `creditToken` (e.g., sUSDS). It uses external rate providers priced in 1e27 ray-unit USD to value assets and compute LP shares. Liquidity providers deposit any of the three supported assets in exchange for pool shares, and users can swap between supported asset pairs (excluding the swap-to-collateral and collateral-to-swap pair).

The audit uncovered **two critical vulnerabilities**, **several high-severity issues**, and a range of medium and low findings. The most serious issues are a permanent DoS griefing vector that can brick all deposits (rendering deposited funds irrecoverable), a seed-deposit front-run vulnerability during deployment, and an inflation attack that can drain early depositors in the absence of a protected seed.

---

## Severity Legend

| Severity     | Description |
|--------------|-------------|
| **Critical** | Direct loss of funds or permanent bricking of core functionality with no admin recovery path |
| **High**     | Significant risk of loss or dysfunction that can be triggered by a motivated attacker |
| **Medium**   | Protocol invariant violations, economic inconsistencies, or conditions that weaken security posture |
| **Low**      | Minor inaccuracies, unsafe assumptions, or design weaknesses with limited immediate impact |
| **Info**     | Best-practice recommendations and observations |

---

## Findings Summary

| ID   | Title                                                                 | Severity |
|------|-----------------------------------------------------------------------|----------|
| C-01 | Permanent Zero-Share DoS via Pre-Deposit Donation                     | Critical |
| C-02 | Seed Deposit Front-Run Enables Permanent DoS During Deployment        | Critical |
| H-01 | Share Inflation Attack Steals Funds From First Depositors             | High     |
| H-02 | `maxSwapSize = 0` Permanently Disables All Swaps (Docs/Code Mismatch) | High     |
| H-03 | No Slippage Protection on Deposits — Vulnerable to Sandwich Attacks   | High     |
| M-01 | `previewSwapExactOut` maxSwapSize Check Applied Before Fee Addition   | Medium   |
| M-02 | Asymmetric Fee Basis Between `swapExactIn` and `swapExactOut`         | Medium   |
| M-03 | Pocket Approval Dependency Can Lock Swap Token Withdrawals            | Medium   |
| M-04 | Rate Provider Returning Zero Post-Deployment Freezes the Protocol     | Medium   |
| M-05 | `deposit` Does Not Revert on Zero Shares Minted — Funds Lost Silently | Medium   |
| L-01 | Admin Can Set 100% Fee, Enabling Full Output Confiscation             | Low      |
| L-02 | Initial Fee State Prevents Manager From Setting Non-Zero Fees         | Low      |
| L-03 | Missing Precision Bound on `creditToken` Decimals                     | Low      |
| L-04 | `previewWithdraw` Reads `msg.sender` — Breaks Composability           | Low      |
| L-05 | Silent No-Op Withdraw for Users With Zero Shares                      | Low      |
| L-06 | Intermediate Division Order Causes Unnecessary Precision Loss         | Low      |
| I-01 | Deployment Script Uses Placeholder `address(0)` for Rate Providers    | Info     |
| I-02 | `MANAGER_ROLE` Never Granted in Constructor                           | Info     |
| I-03 | No Emergency Pause Mechanism                                          | Info     |
| I-04 | Pocket Contract Not Validated For Token Transfer Support              | Info     |
| I-05 | Centralization Risks — Extensive Admin Power Over Protocol Parameters | Info     |

---

## Detailed Findings

---

### [C-01] Permanent Zero-Share DoS via Pre-Deposit Donation

**Severity:** Critical  
**File:** `src/GroveBasin.sol`

#### Description

The `convertToShares` function contains a branch that computes `assetValue * totalShares / totalAssets`. When `totalShares == 0` and `totalAssets != 0` (which can happen by donating tokens directly to the pool/pocket before any deposit), the formula evaluates to `assetValue * 0 / totalAssets == 0` regardless of `assetValue`. Because `deposit` does not check that `newShares != 0`, the depositor's tokens are pulled from them and added to the pool's balance, but zero shares are minted. As `totalShares` never increases, **every future deposit will also mint zero shares**, permanently bricking the pool.

#### Root Cause

```solidity
// src/GroveBasin.sol
function convertToShares(uint256 assetValue) public view override returns (uint256) {
    uint256 totalAssets_ = totalAssets();
    if (totalAssets_ != 0) {
        return assetValue * totalShares / totalAssets_;  // ← returns 0 when totalShares == 0
    }
    return assetValue;
}

function deposit(address asset, address receiver, uint256 assetsToDeposit)
    external override returns (uint256 newShares)
{
    require(assetsToDeposit != 0, "GroveBasin/invalid-amount");
    newShares = previewDeposit(asset, assetsToDeposit);  // ← can return 0
    shares[receiver] += newShares;   // ← adds 0
    totalShares      += newShares;   // ← never increases
    _pullAsset(asset, assetsToDeposit);  // ← tokens are taken
    emit Deposit(asset, msg.sender, receiver, assetsToDeposit, newShares);
}
```

#### Attack Scenario

1. Attacker sends **1 wei of swapToken** directly to the `pocket` address (initial pocket is `address(this)`). Cost: negligible gas + 1 wei.
2. `totalAssets()` is now non-zero (e.g., 1e-12 USD in 1e18 units), while `totalShares == 0`.
3. Any user depositing any amount of any asset gets `newShares = 0`.
4. Their tokens are permanently trapped in the contract with no recovery path.
5. All subsequent deposits are also bricked — `totalShares` can never become > 0.

The protocol team is aware of this scenario as evidenced by `test/unit/DoSAttack.t.sol`, but **no fix was applied** in the contract code.

#### Impact

- Any depositor after the donation permanently loses their funds.
- The entire protocol is bricked from its core LP function.
- Attack cost is 1 wei of swapToken + gas.

#### Recommendation

1. Add a guard in `deposit` that reverts if zero shares are minted:
   ```solidity
   require(newShares != 0, "GroveBasin/zero-shares");
   ```
2. Alternatively, handle the `totalShares == 0` special case explicitly in `convertToShares` regardless of `totalAssets`:
   ```solidity
   if (totalShares == 0) return assetValue;
   if (totalAssets_ != 0) return assetValue * totalShares / totalAssets_;
   return assetValue;
   ```
3. Consider burning a minimum initial liquidity in the constructor (Uniswap V2 pattern) to ensure `totalShares` can never be zero post-deployment.

---

### [C-02] Seed Deposit Front-Run Enables Permanent DoS During Deployment

**Severity:** Critical  
**File:** `deploy/GroveBasinDeploy.sol`, `script/Deploy.s.sol`

#### Description

The deployment library `GroveBasinDeploy.deploy()` seeds the pool with 1e6 swapToken units sent to `address(0)` to prevent inflation attacks. However, this seed deposit is performed in a **separate transaction** from the contract deployment, creating a race window where an attacker can donate tokens to the pocket (initially `address(this)`) between contract deployment and the seed deposit. This triggers the same C-01 condition and renders the seed useless, permanently bricking the protocol at zero cost.

#### Root Cause

```solidity
// deploy/GroveBasinDeploy.sol
function deploy(...) internal returns (address groveBasin) {
    groveBasin = address(new GroveBasin(...));  // TX 1: deploys contract, pocket = address(this)
    IERC20(swapToken).approve(groveBasin, 1e6);  // TX 2: approval
    GroveBasin(groveBasin).deposit(swapToken, address(0), 1e6);  // TX 3: seed deposit
}
```

```solidity
// script/Deploy.s.sol
vm.startBroadcast();
address groveBasin = GroveBasinDeploy.deploy({...});  // three separate txs in mempool
vm.stopBroadcast();
```

`vm.startBroadcast()` submits transactions to the public mempool one at a time. An MEV searcher can:
1. Observe the `GroveBasin` contract creation in the mempool.
2. Insert a `swapToken.transfer(groveBasin, 1)` call (costing 1 wei) between TX 1 and TX 3.
3. When TX 3 (seed deposit) executes, `totalAssets != 0` and `totalShares == 0`, so 0 shares are minted.
4. Protocol is permanently bricked (same outcome as C-01).

#### Impact

- The anti-inflation seed mechanism can be defeated atomically by any front-runner on public networks.
- After a successful front-run, no LP can ever deposit, making the deployed contract permanently unusable.

#### Recommendation

1. **Perform the seed deposit inside the constructor** so it is atomically inseparable from contract deployment:
   ```solidity
   constructor(...) {
       // ... existing initialization ...
       // Mint seed shares to address(0) in the constructor
       uint256 seedAmount = 1e6; // or a constructor parameter
       IERC20(swapToken_).transferFrom(msg.sender, address(this), seedAmount);
       uint256 seedShares = _getAssetValue(swapToken_, seedAmount, false);
       shares[address(0)] += seedShares;
       totalShares += seedShares;
   }
   ```
2. Alternatively, use a `CREATE2`-based factory that includes the seed deposit in the same deployment transaction/bundle.
3. Ensure the initial pocket is set to a value that prevents direct token donations before seeding (e.g., use a dedicated initializer that sets up the pool atomically).

---

### [H-01] Share Inflation Attack Steals Funds From First Depositors

**Severity:** High  
**File:** `src/GroveBasin.sol`

#### Description

When the pool has very few shares (e.g., 1 share from a 1-wei credit or collateral token deposit), an attacker can inflate the share value by donating large amounts of tokens directly to the pool. The next depositor suffers severe rounding truncation—receiving far fewer shares than their deposit is worth—while the attacker profits from the inflated price.

#### Root Cause

```solidity
function convertToShares(uint256 assetValue) public view override returns (uint256) {
    uint256 totalAssets_ = totalAssets();
    if (totalAssets_ != 0) {
        return assetValue * totalShares / totalAssets_;  // vulnerable to manipulation
    }
    return assetValue;
}
```

With `totalShares = 1` and `totalAssets = 10_000_000e18` (from donation), a 20M USDC deposit produces:
`20_000_000e18 * 1 / 10_000_001e18 = 1` share (instead of ~2 shares).

The attacker ends up with 50% of the pool after a 10M donation and gains ~5M USDC.

#### Attack Scenario (confirmed by `test/unit/InflationAttack.t.sol`)

1. Front-runner deposits 1 wei of creditToken → 1 share.
2. Front-runner donates 10M USDC to the pool.
3. Victim deposits 20M USDC, receives only 1 share (rounding attack).
4. Both users withdraw — each receives 15M USDC.
5. Front-runner nets +5M USDC; victim loses 5M USDC.

#### Impact

- Large capital loss for the first real depositor.
- Economically feasible when expected victim deposit is >> attacker donation.

#### Recommendation

The `GroveBasinDeploy.deploy()` library's seed deposit (burn 1e6 swapToken shares to `address(0)`) is the intended mitigation. However it must be atomic with deployment (see C-02). Once the seed is properly applied, the inflation attack becomes uneconomical because the rounding error is proportional to `1 / totalShares` (which is 1e18 after the seed). Additionally, add the `require(newShares != 0)` guard from C-01.

---

### [H-02] `maxSwapSize = 0` Permanently Disables All Swaps (Docs/Code Mismatch)

**Severity:** High  
**File:** `src/GroveBasin.sol`, `src/interfaces/IGroveBasin.sol`

#### Description

The interface documentation states:
> "Returns the maximum value of a swap in 1e18 precision. Settable by the owner. **If set to zero, there is no limit on swap size.**"

However, the actual implementation checks:
```solidity
require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize, "GroveBasin/swap-size-exceeded");
```

If `maxSwapSize == 0`, the check becomes `require(value <= 0)`, which fails for any non-trivial swap since `amountIn != 0` is already enforced. Setting `maxSwapSize = 0` therefore **disables all swaps**, contrary to the documentation.

#### Impact

- An admin who follows the documentation and sets `maxSwapSize = 0` intending to remove the cap will brick all swaps instead.
- A malicious admin can use this to griefing-pause the protocol without a pause mechanism.
- No admin recovery other than setting a non-zero value.

#### Recommendation

Either:
1. Update the check to treat zero as unlimited:
   ```solidity
   if (maxSwapSize != 0) {
       require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize, "GroveBasin/swap-size-exceeded");
   }
   ```
2. Or update the documentation and revert if attempting to set `maxSwapSize = 0`.

---

### [H-03] No Slippage Protection on Deposits — Vulnerable to Sandwich Attacks

**Severity:** High  
**File:** `src/GroveBasin.sol`

#### Description

The `deposit` function accepts only `asset`, `receiver`, and `assetsToDeposit`. There is no `minShares` parameter. A user calling `previewDeposit` followed by `deposit` in separate transactions can be sandwiched: an attacker manipulates the pool state (e.g., via a large direct token donation or rate changes) between the preview and the actual deposit, causing the user to receive significantly fewer shares than expected while paying the full `assetsToDeposit`.

```solidity
function deposit(address asset, address receiver, uint256 assetsToDeposit)
    external override returns (uint256 newShares)
{
    require(assetsToDeposit != 0, "GroveBasin/invalid-amount");
    newShares = previewDeposit(asset, assetsToDeposit);  // no minimum enforced
    shares[receiver] += newShares;
    totalShares      += newShares;
    _pullAsset(asset, assetsToDeposit);
    ...
}
```

#### Impact

- MEV bots can sandwich LP deposits to extract value from unsuspecting users.
- Especially impactful for large deposits.

#### Recommendation

Add a `minShares` parameter with a corresponding check:
```solidity
function deposit(address asset, address receiver, uint256 assetsToDeposit, uint256 minShares)
    external override returns (uint256 newShares)
{
    ...
    newShares = previewDeposit(asset, assetsToDeposit);
    require(newShares >= minShares, "GroveBasin/insufficient-shares-out");
    ...
}
```

---

### [M-01] `previewSwapExactOut` maxSwapSize Check Applied Before Fee Addition

**Severity:** Medium  
**File:** `src/GroveBasin.sol`

#### Description

In `previewSwapExactOut`, the `maxSwapSize` check is performed **before** the fee is added to `amountIn`:

```solidity
function previewSwapExactOut(...) public view override returns (uint256 amountIn) {
    amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);
    require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize, ...);  // ← check here
    if (assetOut == address(creditToken)) {
        amountIn += _calculatePurchaseFee(amountIn, true);    // ← fee added AFTER check
    } else {
        amountIn += _calculateRedemptionFee(amountIn, true);
    }
}
```

The fee can be up to `maxFee` BPS (up to 10,000 = 100% as per L-01). With `maxSwapSize = 100e18` and `purchaseFee = 1000 (10%)`, the user ends up paying `110e18` worth of swapToken — 10% above the `maxSwapSize` limit — without the check catching it. With a 100% fee, the user could pay double `maxSwapSize`.

This also means `previewSwapExactIn` and `previewSwapExactOut` are inconsistent: ExactIn checks the true user payment amount (input), while ExactOut checks only the pre-fee equivalent, not the actual total cost.

#### Recommendation

Move the size check after fee addition, or base it on the output asset's value (which is bounded regardless of fees):
```solidity
amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);
if (assetOut == address(creditToken)) {
    amountIn += _calculatePurchaseFee(amountIn, true);
} else {
    amountIn += _calculateRedemptionFee(amountIn, true);
}
require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize, ...);
```

---

### [M-02] Asymmetric Fee Basis Between `swapExactIn` and `swapExactOut`

**Severity:** Medium  
**File:** `src/GroveBasin.sol`

#### Description

The fee is applied to different bases in the two swap modes:

- **`swapExactIn`**: Fee is deducted from the **output** amount (creditToken or swapToken out).
- **`swapExactOut`**: Fee is added to the **input** amount (equivalent swapToken or creditToken in).

This creates an asymmetry. For a purchase swap (swapToken → creditToken) at rate 1:1.25:

| Mode | User pays | User receives | Effective fee (on USD value) |
|------|-----------|---------------|------------------------------|
| ExactIn (100 USDC) | 100 USDC | 76 creditToken (5% off 80) | $5 |
| ExactOut (76 creditToken) | 99.75 USDC | 76 creditToken | $4.75 |

A user wanting 76 creditToken pays $4.75 via ExactOut but their counterparty pays $5 via ExactIn. Users can consistently save `(fee/BPS)² ≈ 0.25%` of the fee by using ExactOut over ExactIn. While not large at typical fee levels, this is a protocol-level inefficiency that sophisticated users can exploit systematically.

#### Recommendation

Unify the fee calculation by applying it consistently to the same economic basis. One common approach is to always apply fees to the output asset's value:

- For ExactIn: `amountOut -= fee(amountOut)` (current behaviour)
- For ExactOut: instead of adding fee to `amountIn`, calculate `grossAmountOut = amountOut / (1 - fee/BPS)` and set `amountIn = quote(grossAmountOut)`.

---

### [M-03] Pocket Approval Dependency Can Lock Swap Token Withdrawals and Pocket Migration

**Severity:** Medium  
**File:** `src/GroveBasin.sol`

#### Description

All swap token flows in and out of the protocol (swaps, withdrawals, and pocket migration) depend on the `pocket` address having an active approval to the GroveBasin contract. When `pocket != address(this)`:

```solidity
function _pushAsset(address asset, address receiver, uint256 amount) internal {
    if (asset == address(swapToken) && pocket != address(this)) {
        swapToken.safeTransferFrom(pocket, receiver, amount);  // requires pocket approval
    } else {
        IERC20(asset).safeTransfer(receiver, amount);
    }
}

function setPocket(address newPocket) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    ...
    swapToken.safeTransferFrom(pocket_, newPocket, amountToTransfer);  // requires pocket approval
}
```

If the pocket contract:
- Revokes its approval to GroveBasin, or
- Is upgraded to a version that does not provide approval, or
- Is a multisig that delays/denies approvals,

then:
1. All `swapExactIn/Out` calls returning swapToken will fail.
2. All `withdraw(swapToken, ...)` calls will fail.
3. `setPocket(newPocket)` will also fail (can't migrate to fix the situation).

This creates a scenario where **swapToken funds are permanently trapped** with no recovery path once the pocket revokes approval.

#### Recommendation

1. Enforce that the pocket always maintains an infinite approval as a protocol invariant; document this as a hard requirement for pocket implementations.
2. Add a `rescueTokens` or `recoverPocket` function callable by admin that can transfer swap tokens from the current pocket to `address(this)` when `pocket == address(this)` is temporarily set — OR allow migrating the pocket even when allowance is zero if the balance is also zero.
3. Consider storing swapTokens in the GroveBasin contract itself (`pocket = address(this)`) by default and only using external pockets via a wrapper pattern where the pocket always auto-approves.

---

### [M-04] Rate Provider Returning Zero Post-Deployment Freezes the Protocol

**Severity:** Medium  
**File:** `src/GroveBasin.sol`

#### Description

The constructor validates that all rate providers return non-zero at deployment time. However, if a rate provider returns zero at any point post-deployment, several functions become broken:

```solidity
function convertToAssets(address asset, uint256 numShares) public view override returns (uint256) {
    ...
    return assetValue * 1e9 * _swapTokenPrecision
        / IRateProviderLike(swapTokenRateProvider).getConversionRate();  // ← div-by-zero
}
```

A zero rate from any provider causes:
- `convertToAssets` to revert (division by zero)
- `previewWithdraw` to revert (calls `convertToAssets`)
- `withdraw` to revert
- LP fund access completely frozen until the provider recovers

Since rate providers are immutable (`address public override immutable swapTokenRateProvider`), there is no way to update a broken provider without a full contract migration.

#### Impact

- Any downtime or bug in a rate provider contract completely freezes LP withdrawals.
- Rate providers are permanently bound; a compromised provider has indefinite effect.

#### Recommendation

1. Add a fallback rate or bounds check: if the rate is 0 or outside a reasonable range, revert with a descriptive error rather than a raw division-by-zero.
2. Consider making rate providers upgradeable (governed replacement) to allow recovery from a broken provider.
3. Add minimum/maximum rate sanity bounds checked in every rate provider call:
   ```solidity
   uint256 rate = IRateProviderLike(swapTokenRateProvider).getConversionRate();
   require(rate != 0, "GroveBasin/swap-rate-is-zero");
   ```

---

### [M-05] `deposit` Does Not Revert on Zero Shares Minted — Funds Lost Silently

**Severity:** Medium  
**File:** `src/GroveBasin.sol`

#### Description

Beyond the attack scenarios in C-01, there is a legitimate scenario where a small deposit mints zero shares due to integer division when `totalAssets` is very large relative to `totalShares * assetValue`:

```solidity
function convertToShares(uint256 assetValue) public view override returns (uint256) {
    uint256 totalAssets_ = totalAssets();
    if (totalAssets_ != 0) {
        return assetValue * totalShares / totalAssets_;  // can be 0 for small deposits
    }
    return assetValue;
}
```

If `assetValue * totalShares < totalAssets_`, shares = 0. The deposit function does not check this:

```solidity
newShares = previewDeposit(asset, assetsToDeposit);
shares[receiver] += newShares;  // += 0
totalShares      += newShares;  // += 0
_pullAsset(asset, assetsToDeposit);  // funds taken!
```

The user's funds are permanently transferred into the pool (accruing to other LPs), but they receive zero shares and cannot recover the funds.

#### Recommendation

Add a mandatory check:
```solidity
require(newShares != 0, "GroveBasin/zero-shares-minted");
```
This guards against both the DoS griefing attack (C-01) and dust deposit losses.

---

### [L-01] Admin Can Set 100% Fee, Enabling Full Output Confiscation

**Severity:** Low  
**File:** `src/GroveBasin.sol`

#### Description

The `setFeeBounds` function allows `newMaxFee` to be set up to `BPS = 10,000` (100%):

```solidity
require(newMaxFee <= BPS, "GroveBasin/max-fee-gte-bps");
```

If the admin sets `maxFee = BPS = 10,000` and the manager then sets `purchaseFee = 10,000`:
- `swapExactIn` (swap → credit): `amountOut -= amountOut * 10000 / 10000 = amountOut` → user receives 0
- `swapExactOut` (swap → credit): `amountIn += amountIn * 10000 / 10000 = 2 * amountIn` → user pays double

This allows a malicious or compromised admin/manager to confiscate 100% of swap output.

#### Recommendation

Enforce a maximum fee cap that is substantially below 100% (e.g., 10% = 1000 BPS):
```solidity
uint256 public constant MAX_FEE_CAP = 1000; // 10%
require(newMaxFee <= MAX_FEE_CAP, "GroveBasin/max-fee-exceeds-cap");
```

---

### [L-02] Initial Fee State Prevents Manager From Setting Non-Zero Fees

**Severity:** Low  
**File:** `src/GroveBasin.sol`

#### Description

At deployment, `minFee = 0`, `maxFee = 0`, `purchaseFee = 0`, `redemptionFee = 0` (Solidity default values). The `_setPurchaseFee` and `_setRedemptionFee` internal functions enforce:

```solidity
require(newPurchaseFee >= minFee && newPurchaseFee <= maxFee, "GroveBasin/purchase-fee-out-of-bounds");
```

With `minFee = maxFee = 0`, calling `setPurchaseFee(1)` will revert. The MANAGER_ROLE cannot set any non-zero fee until the admin explicitly calls `setFeeBounds`. This is an operational footgun: if the deployer forgets to call `setFeeBounds`, fees can never be charged regardless of how many managers are granted.

Additionally, `setFeeBounds` is not called in `GroveBasinDeploy.deploy()`, so the default deployment has no fee bounds configured.

#### Recommendation

1. Either set non-zero default fee bounds in the constructor, or
2. Add `setFeeBounds` with initial values to the deployment library, or
3. Document explicitly that `setFeeBounds` must be called as part of deployment setup before enabling the MANAGER_ROLE.

---

### [L-03] Missing Precision Bound on `creditToken` Decimals

**Severity:** Low  
**File:** `src/GroveBasin.sol`

#### Description

The constructor validates precision bounds for `swapToken` and `collateralToken` but not for `creditToken`:

```solidity
// Necessary to ensure rounding works as expected
require(_swapTokenPrecision       <= 1e18, "GroveBasin/swapToken-precision-too-high");
require(_collateralTokenPrecision <= 1e18, "GroveBasin/collateralToken-precision-too-high");
// _creditTokenPrecision is NOT checked
```

If `creditToken` has more than 18 decimals (e.g., a hypothetical 27-decimal token), the swap conversion formula:
```solidity
amount * swapRate / creditRate * _creditTokenPrecision / _swapTokenPrecision
```
multiplies `_creditTokenPrecision` as a scaling factor. With `_creditTokenPrecision = 1e27` and `_swapTokenPrecision = 1e6`, this becomes a `1e21` multiplier that can cause arithmetic overflow for large amounts, or at minimum introduces rounding behavior inconsistent with the intended design.

#### Recommendation

Add the missing precision check:
```solidity
require(_creditTokenPrecision <= 1e18, "GroveBasin/creditToken-precision-too-high");
```

---

### [L-04] `previewWithdraw` Reads `msg.sender` — Breaks Composability and On-Chain Simulation

**Severity:** Low  
**File:** `src/GroveBasin.sol`

#### Description

`previewWithdraw` is declared `public view` but internally reads `msg.sender`:

```solidity
function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
    public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
{
    ...
    uint256 userShares = shares[msg.sender];  // ← reads msg.sender
    if (sharesToBurn > userShares) {
        assetsWithdrawn = convertToAssets(asset, userShares);
        sharesToBurn    = userShares;
    }
}
```

This makes the function behave differently depending on the caller's identity. Problems:
1. **Router/aggregator contracts** calling `previewWithdraw` on behalf of users will see the router's shares (0), not the user's shares.
2. **Off-chain simulations** using `eth_call` with a specific `from` address will work, but calling from a different address (e.g., a simulation contract) returns incorrect results.
3. **Third-party UIs and integrations** that call the contract view with a generic caller cannot accurately preview withdrawals for arbitrary users.

The `withdraw` function also reads `msg.sender` for shares (which is correct for access control), but the *preview* function should ideally accept a `user` parameter.

#### Recommendation

Add a `user` parameter to the preview function:
```solidity
function previewWithdraw(address asset, address user, uint256 maxAssetsToWithdraw)
    public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
{
    ...
    uint256 userShares = shares[user];
    ...
}
```
And have the internal withdrawal logic call it with `msg.sender`.

---

### [L-05] Silent No-Op Withdraw for Users With Zero Shares

**Severity:** Low  
**File:** `src/GroveBasin.sol`

#### Description

When a user with `shares[msg.sender] == 0` calls `withdraw`, the function does not revert. `previewWithdraw` returns `(0, 0)`, and `withdraw` proceeds to transfer 0 tokens and emit a `Withdraw` event with `assetsWithdrawn = 0` and `sharesBurned = 0`:

```solidity
function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
    external override returns (uint256 assetsWithdrawn)
{
    require(maxAssetsToWithdraw != 0, "GroveBasin/invalid-amount");
    uint256 sharesToBurn;
    (sharesToBurn, assetsWithdrawn) = previewWithdraw(asset, maxAssetsToWithdraw);
    // Both are 0 if user has no shares; no revert
    unchecked {
        shares[msg.sender] -= sharesToBurn;  // 0 - 0 = 0
        totalShares        -= sharesToBurn;
    }
    _pushAsset(asset, receiver, assetsWithdrawn);  // transfer(receiver, 0)
    emit Withdraw(asset, msg.sender, receiver, assetsWithdrawn, sharesToBurn);  // emits 0-value event
}
```

This wastes gas and emits misleading zero-value events, polluting event logs and any indexer tracking withdrawals.

#### Recommendation

Add a guard:
```solidity
require(assetsWithdrawn != 0, "GroveBasin/zero-assets-withdrawn");
```
Or check the user's shares at the start:
```solidity
require(shares[msg.sender] != 0, "GroveBasin/no-shares");
```

---

### [L-06] Intermediate Division Order Causes Unnecessary Precision Loss

**Severity:** Low  
**File:** `src/GroveBasin.sol`

#### Description

Swap conversion functions perform two sequential integer divisions that could be combined into a single operation to reduce rounding error:

```solidity
// _convertSwapToCreditToken (non-roundUp path)
return amount * swapRate / creditRate * _creditTokenPrecision / _swapTokenPrecision;
//              ^^^^^^^^^^^^^^^^^^      ^^^^^^^^^^^^^^^^^^^^^^^^^^^
//              Division 1              Division 2
```

The mathematically equivalent combined operation:
`amount * swapRate * _creditTokenPrecision / (creditRate * _swapTokenPrecision)`

performs only one division, losing at most 1 unit of precision rather than up to 2 units from two separate divisions. Although Solidity `uint256` is large enough to avoid overflow in most practical cases (verified by max-value analysis), the two-step approach is strictly less precise.

This affects the `roundDown` paths in `_convertSwapToCreditToken`, `_convertCreditTokenToSwap`, `_convertCollateralToCreditToken`, and `_convertCreditTokenToCollateral`.

#### Recommendation

Combine the multiplications before dividing:
```solidity
return amount * swapRate * _creditTokenPrecision / creditRate / _swapTokenPrecision;
// or equivalently:
return amount * swapRate * _creditTokenPrecision / (creditRate * _swapTokenPrecision);
```
Verify no overflow is possible given maximum values before making this change.

---

### [I-01] Deployment Script Uses Placeholder `address(0)` for Rate Providers

**Severity:** Info  
**File:** `script/Deploy.s.sol`

#### Description

The deployment script has explicit `address(0)` placeholders for all three rate providers with `// TODO` comments:

```solidity
address groveBasin = GroveBasinDeploy.deploy({
    owner                       : Ethereum.GROVE_PROXY,
    swapToken                   : Ethereum.USDC,
    collateralToken             : Ethereum.USDS,
    creditToken                 : Ethereum.SUSDS,
    swapTokenRateProvider       : address(0),  // TODO: set up rate provider
    collateralTokenRateProvider : address(0),  // TODO: set up rate provider
    creditTokenRateProvider     : address(0)   // TODO: set up rate provider
});
```

The constructor validates `require(addr != address(0), ...)` for all providers, so this script will revert if run as-is. However, the risk is that a deployment is accidentally attempted with incomplete configuration, and on test/staging networks the zero-address check might be bypassed if using mock providers.

Additionally, the script file header imports from `lib/grove-address-registry/src/Ethereum.sol` but is targeting Base (due to `vm.createSelectFork(getChain("base").rpcUrl)`). The `Ethereum.*` constants may not correspond to Base addresses.

#### Recommendation

1. Fill in the rate provider addresses before merging this to a production branch.
2. Add a CI check that validates the script doesn't contain `address(0)` provider entries.
3. Rename the script/library or the address constants to reflect the correct network (Base vs. Ethereum).

---

### [I-02] `MANAGER_ROLE` Never Granted in Constructor

**Severity:** Info  
**File:** `src/GroveBasin.sol`

#### Description

`setPurchaseFee` and `setRedemptionFee` require `MANAGER_ROLE`, but this role is never granted in the constructor. Only `DEFAULT_ADMIN_ROLE` is granted to `owner_`. As a result, fee management is inaccessible until the owner explicitly calls `grantRole(MANAGER_ROLE, someAddress)`.

If the intent is for the owner to manage fees directly, they would need to also grant themselves `MANAGER_ROLE`. This is not obvious and could be missed.

#### Recommendation

Decide on the intended architecture and either:
1. Grant `MANAGER_ROLE` to `owner_` in the constructor if they should be the initial fee manager.
2. Document clearly that `MANAGER_ROLE` must be granted post-deployment for fee management.
3. Consider whether the two-role system adds meaningful security vs. the operational overhead.

---

### [I-03] No Emergency Pause Mechanism

**Severity:** Info  
**File:** `src/GroveBasin.sol`

#### Description

The protocol has no `pause()` function or circuit breaker. If a rate provider is exploited or returns highly manipulated values, there is no way to halt swaps or deposits until a full contract migration is performed. Given that rate providers are immutable, a compromised provider has indefinite effect.

#### Recommendation

Implement an `OpenZeppelin Pausable` pattern controlled by the `DEFAULT_ADMIN_ROLE` to allow emergency halting of swaps and/or deposits while preserving withdrawals.

---

### [I-04] Pocket Contract Not Validated For Token Transfer Support

**Severity:** Info  
**File:** `src/GroveBasin.sol`

#### Description

`setPocket` sets the pocket to any non-zero address without verifying that the address can receive and transfer ERC20 tokens. If `newPocket` is a contract without the ability to approve GroveBasin (e.g., it has no `approve` or `transfer` function, or it's a contract that doesn't support ERC20 callbacks), future `_pushAsset` calls will fail.

#### Recommendation

Document that pockets must be ERC20-aware contracts. Consider requiring that the new pocket has already pre-approved GroveBasin before `setPocket` is called:
```solidity
require(swapToken.allowance(newPocket, address(this)) == type(uint256).max, "GroveBasin/pocket-not-approved");
```

---

### [I-05] Centralization Risks — Extensive Admin Power Over Protocol Parameters

**Severity:** Info  
**File:** `src/GroveBasin.sol`

#### Description

The `DEFAULT_ADMIN_ROLE` holder has significant and immediate power to affect all protocol users:

| Action | Effect |
|--------|--------|
| `setMaxSwapSize(0)` | Disables all swaps (see H-02) |
| `setFeeBounds(0, 10000)` | Enables 100% fee confiscation (see L-01) |
| `setPocket(evilAddress)` | Redirects all swap token deposits to attacker-controlled address |
| `grantRole(MANAGER_ROLE, attacker)` | Enables fee manipulation |

None of these actions are time-locked, require a governance vote, or can be contested by users.

#### Recommendation

1. Implement a **timelock** (e.g., 48-72 hours) for all `DEFAULT_ADMIN_ROLE` actions so users can react before changes take effect.
2. Cap the max fee at a protocol-defined constant (see L-01).
3. Consider making the `owner_` address a governance contract rather than an EOA.

---

## Appendix: Additional Observations

### Collateral-to-Swap and Swap-to-Collateral Swaps Are Disabled

`_getSwapQuote` reverts with `"GroveBasin/invalid-swap"` for:
- `swapToken → collateralToken`  
- `collateralToken → swapToken`

This is by design (these tokens are both considered USD-pegged stable assets), but users attempting these swaps receive only a generic revert message. A clearer error such as `"GroveBasin/stable-to-stable-swap-not-supported"` would improve user experience.

### `totalAssets` Includes All Token Balances, Including Donations

`totalAssets()` sums the balances of all three tokens held by the protocol/pocket. Any accidental or intentional token donation increases `totalAssets` without increasing `totalShares`, slightly increasing the value of all existing shares. This is generally acceptable (it benefits LPs) but can cause rounding on subsequent deposits for very small pools.

### `previewSwapExactOut` Validates `assetOut` But `previewSwapExactIn` Does Not Explicitly

In `previewSwapExactIn`, if `assetIn` is valid but `assetOut` is an invalid address (not one of the three supported tokens), the revert comes from inside `_getSwapQuote` with `"GroveBasin/invalid-asset"`. In `previewSwapExactOut`, the same holds for invalid `assetOut`. Both paths revert, but the error site is deep in the call stack. A top-level validation check would produce clearer error messages.

### Rounding Always Against the User (Correctly Implemented)

The protocol correctly rounds in favor of the protocol (against the user) throughout:
- `deposit`: rounds down shares minted
- `withdraw`: rounds up shares burned (uses `_convertToSharesRoundUp`)
- `swapExactIn`: rounds down amount out
- `swapExactOut`: rounds up amount in

This is the correct invariant for vault/AMM designs and is verified by the fuzz tests in `Rounding.t.sol`.

---

## Summary of Critical Fixes Required

Before deployment to mainnet, the following must be addressed:

1. **[C-01]** Add `require(newShares != 0)` in `deposit`.
2. **[C-02]** Make the seed deposit atomic with contract deployment (move to constructor or use a factory).
3. **[H-02]** Fix `maxSwapSize = 0` behavior to mean "unlimited" rather than "all swaps disabled."
4. **[H-03]** Add `minShares` slippage protection to `deposit`.
5. **[M-05]** Same as C-01 — add zero-share guard.

The remaining findings should be evaluated and addressed prior to production launch.
