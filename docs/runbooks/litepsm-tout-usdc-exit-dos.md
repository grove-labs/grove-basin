# Runbook: LitePSM tout != 0 — USDC Withdrawal DOS

## Summary

When Sky governance sets `LitePSM.tout()` to a non-zero value, every USDC withdrawal
path through `UsdsUsdcPocket` reverts with `NonZeroPsmTout()`.

## Root Cause

`UsdsUsdcPocket.withdrawLiquidity()` (line 95) contains a hard guard:

```solidity
if (IPSMLike(psm).tout() != 0) revert NonZeroPsmTout();
```

This is intentional — a non-zero `tout` means the PSM charges a fee on `buyGem`, which
would cause a shortfall between the USDS burned and the USDC received. The
revert blocks **all** USDC withdrawals from the pocket.

### Affected Paths

| Path | Impact |
|------|--------|
| `Basin.withdraw(USDC, ...)` | Reverts when pocket has insufficient USDC balance |
| `Basin.withdraw(USDC, ...)` when pocket has USDC balance | Still reverts — guard fires before balance check |
| `Basin.previewWithdraw(USDC, ...)` | Succeeds (view-only, does not call pocket) |
| `Basin.withdraw(USDS, ...)` | Unaffected — USDS path does not hit the `tout` guard |
| `groveProxy` USDS recovery | Unaffected — only pulls USDS from pocket via allowance |

### Dependency Chain

```
Sky governance spell → LitePSM.file("tout", X) → tout() returns non-zero
  → UsdsUsdcPocket.withdrawLiquidity(USDC) reverts
    → Basin._withdrawLiquidityInPocket(USDC) reverts
      → Basin.withdraw(USDC) reverts
```

## Detection

### Monitoring

1. **Watch Sky governance forum and on-chain proposals** for any spell that calls
   `LitePSM.file("tout", ...)` with a non-zero value.
2. **On-chain monitoring**: Alert if `LitePSM.tout()` transitions from 0 to non-zero.
3. **Basin monitoring**: Alert on repeated `NonZeroPsmTout` revert traces in USDC
   withdrawal transactions.

### Manual Check

```bash
cast call <LitePSM_address> "tout()(uint256)" --rpc-url <rpc>
```

If the result is non-zero, USDC exits via the pocket are blocked.

## Response Procedure

### Phase 1: Immediate — Confirm and Freeze USDC Swap Paths

#### Step 1a: Confirm the DOS

```bash
# Verify tout is non-zero
cast call <LitePSM_address> "tout()(uint256)" --rpc-url <rpc>

# Verify USDC withdrawals are reverting
cast call <Basin_address> "previewWithdraw(address,uint256)(uint256,uint256)" <USDC_address> 1000000 --rpc-url <rpc>
# previewWithdraw will succeed but actual withdraw will revert
```

#### Step 1b: Pause USDC swap paths

`PAUSER_ROLE` pauses the swap directions involving USDC (the collateral token) to
prevent users from swapping into or out of USDC while the pocket is broken:

This prevents new USDC from entering Basin through swaps (which would increase the
amount stuck behind the broken pocket) and prevents users from attempting credit-to-USDC
swaps that would also fail at the pocket layer.

#### Step 1c: Sweep any USDC already in the pocket

If the pocket holds USDC (from direct transfers or prior partial operations), sweep it
to Basin so it can be withdrawn without hitting the pocket path:

This only recovers USDC already sitting in the pocket. It does not convert USDS.

#### Step 1d: Communicate to users

Announce that USDC withdrawals and USDC swaps are temporarily unavailable. USDS
withdrawals remain functional. Users who need to exit can withdraw USDS and swap to USDC
externally.

### Phase 2: Proactive (in parallel) — Queue Pocket Rotation via Governance

Because `MANAGER_ADMIN_ROLE` is behind governance (spell cycle ~2+ days), begin
preparing the pocket rotation **immediately** — do not wait for user complaints or
further assessment.

#### Step 2a: Deploy a replacement pocket

Options (in order of preference):

1. **New UsdsUsdcPocket** pointing to a different PSM (if one exists with tout = 0).
2. **A pocket that tolerates non-zero tout** (accepts the fee as slippage).
3. **Set pocket to Basin itself** (`address(this)`) if USDS should remain in Basin
   directly and USDC withdrawal via PSM should be disabled until tout returns to 0.

Deployment requires no on-chain role — anyone can deploy. Have the replacement pocket
ready before the spell is queued.

#### Step 2b: Queue governance spell for pocket rotation

`setPocket` is gated by `MANAGER_ADMIN_ROLE`. Queue a spell that calls:

```solidity
IGroveBasin(basin).setPocket(newPocketAddress);
```

`setPocket` internally:
1. Withdraws all USDS from the current pocket back to Basin.
2. Transfers the USDS balance to the new pocket.
3. Updates the `pocket` storage variable.

**Important**: `setPocket` calls `_withdrawLiquidityInPocket(swapToken)` on the **old**
pocket. Since this is a USDS (swapToken) withdrawal, it does NOT hit the `tout` guard.
The rotation will succeed even while `tout != 0`.

#### Step 2c: After spell executes — verify and unpause

Once USDC withdrawals are confirmed working, `MANAGER_ADMIN_ROLE` unpauses the swap
paths (unpausing requires `MANAGER_ADMIN_ROLE`, not `PAUSER_ROLE`):

Note: Since unpausing also requires governance, include these `setUnpaused` calls in the
same spell as the `setPocket` call if possible.

## Escalation Timeline

| Trigger | Action | Role | Timing |
|---------|--------|------|--------|
| `tout()` transitions to non-zero | Confirm DOS | Monitoring | Immediate |
| Confirmed | Pause USDC swap paths | `PAUSER_ROLE` | Immediate |
| Confirmed | Sweep USDC from pocket | `MANAGER_ROLE` | Immediate |
| Confirmed | Deploy replacement pocket | No role needed | Immediate |
| Confirmed | Queue spell: `setPocket` + `setUnpaused` | `MANAGER_ADMIN_ROLE` (governance) | Queue immediately, in parallel |
| Spell executes | Verify USDC withdrawals, confirm unpaused | `MANAGER_ROLE` | Immediate after execution |
| `tout()` returns to 0 (if applicable) | Evaluate rotating back to original pocket | `MANAGER_ADMIN_ROLE` (governance) | When confirmed stable |

## Long-Term Coordination with Sky

If Sky intends to keep `tout != 0` permanently:

1. Grove must maintain a pocket implementation that either:
   - Accounts for the tout fee in the withdrawal calculation, or
   - Sources USDC from an alternative venue (DEX, other PSM).
2. Document this external dependency in the deployment configuration.
3. Establish a communication channel with Sky governance to receive advance notice of
   tout parameter changes.

## Roles Required

| Action | Role |
|--------|------|
| `setPaused()` on swap paths | `PAUSER_ROLE` |
| `sweep()` on pocket | `MANAGER_ROLE` |
| `setPocket()` | `MANAGER_ADMIN_ROLE` (governance spell) |
| `setUnpaused()` on swap paths | `MANAGER_ADMIN_ROLE` (governance spell) |
| Deploy new pocket | No on-chain role needed |
