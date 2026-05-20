# Runbook: Chronicle Oracle Staleness — Stablecoin Withdrawal DOS

## Summary

When the Chronicle oracle feeding the credit-token rate provider goes stale (no update
within `stalenessThreshold`), every Basin function that reads a conversion rate reverts
with `StaleRate()`. This includes USDS and USDC withdrawals because `previewWithdraw()`
calls `totalAssets()`, which reads the credit-token rate. The "stablecoin withdrawals
are unpausable" property does not hold under oracle staleness.

## Root Cause

```
Basin.withdraw(asset, receiver, amount)
  → previewWithdraw(asset, amount)
    → _convertToSharesRoundUp(assetValue)
      → totalAssets()
        → _getAssetValue(creditToken, ...) → _getConversionRate(creditTokenRateProvider)
          → StaleRate() revert
```

`_getConversionRate` reverts when `block.timestamp - lastUpdated > stalenessThreshold`.
The credit-token rate provider wraps a Chronicle oracle whose `age` reflects the last
on-chain oracle update. `totalAssets()` queries the credit-token rate even for USDS/USDC
withdrawals, so a stale Chronicle oracle blocks all exit paths.

### Default Configuration

| Parameter | Default | Set By |
|-----------|---------|--------|
| `stalenessThreshold` | 1 week | `MANAGER_ROLE` (within bounds) |
| `minStalenessThreshold` | 5 minutes | `MANAGER_ADMIN_ROLE` (governance) |
| `maxStalenessThreshold` | 2 weeks | `MANAGER_ADMIN_ROLE` (governance) |

### Pocket Back-Door Limitations

The `groveProxy` allowance on `UsdsUsdcPocket` can pull USDS directly from the pocket,
bypassing Basin. However:

- It only recovers **USDS** — not USDC.
- It does not help LP shareholders withdraw through Basin.

## Detection

### Monitoring

1. **Chronicle oracle freshness**: Alert when `creditTokenRateProvider` returns a
   `lastUpdated` older than `stalenessThreshold - 1 day`.
2. **On-chain**: Watch for `StaleRate` revert signatures in Basin transaction traces.
3. **Off-chain**: Periodically call `totalAssets()` via `eth_call` and alert on revert.

### Manual Check

```bash
cast call <creditTokenRateProvider> "getConversionRateWithAge()(uint256,uint256)" --rpc-url <rpc>
cast call <Basin_address> "stalenessThreshold()(uint256)" --rpc-url <rpc>
cast call <Basin_address> "totalAssets()(uint256)" --rpc-url <rpc>
```

## Response Procedure

### Phase 1: Immediate (< 1 hour) — Extend Staleness Threshold

`MANAGER_ROLE` extends the threshold to the current `maxStalenessThreshold` (default:
2 weeks). This buys time from the last oracle update.

### Phase 2: Proactive (in parallel) — Queue Governance Bound Increase

Because `MANAGER_ADMIN_ROLE` is behind governance (spell cycle ~2+ days), begin
preparing the bound increase **immediately** — do not wait for the Phase 1 window to
expire.

#### Step 2a: Prepare and queue the governance spell

Queue a spell that calls `setStalenessThresholdBounds(minStalenessThreshold, newMax)`.
Choose `newMax` generously (e.g., 30 days = 2592000 seconds) to avoid needing a second
spell if the outage extends.

```solidity
// Spell action:
IGroveBasin(basin).setStalenessThresholdBounds(300, 2592000);
```

Note: `setStalenessThresholdBounds` auto-clamps the current `stalenessThreshold` to the
new bounds if it falls outside the range. The current threshold will remain unchanged if
it is within the new range.

#### Step 2b: After spell executes, MANAGER_ROLE extends threshold

### Phase 3: Proactive (in parallel) — Prepare FixedRateProvider Fallback

If Chronicle has not diagnosed a root cause, prepare to replace the credit-token rate
provider with a `FixedRateProvider` that unblocks LP withdrawals. This work should begin
**immediately alongside Phase 2** so a deployment is ready to execute the moment
governance approves it.

#### Step 3a: Snapshot the last known good rate

Record the last valid rate returned by the Chronicle rate provider before it went stale.
This is the rate the `FixedRateProvider` will be deployed with.

```bash
# Get the current (stale) rate — the value is still valid, only the age is stale
cast call <creditTokenRateProvider> "getConversionRate()(uint256)" --rpc-url <rpc>
```

#### Step 3b: Deploy FixedRateProvider

`FixedRateProvider` already exists in the codebase (`src/rate-providers/FixedRateProvider.sol`).
It returns `block.timestamp` as the age, so it never goes stale.

```bash
forge create src/rate-providers/FixedRateProvider.sol:FixedRateProvider \
  --constructor-args <last_known_rate> \
  --account <deployer> --sender <deployerAddress> --rpc-url <rpc>
```

#### Step 3c: Queue governance spell to swap rate provider

`setRateProvider` is gated by `MANAGER_ADMIN_ROLE`. Queue a spell:

```solidity
// Spell action:
IGroveBasin(basin).setRateProvider(creditToken, fixedRateProviderAddress);
```

Caution: this step should only be executed if the Grove team diagnoses that the Chronicle oracle outage is not recoverable in the short to medium term. Grove team should be working very closely with the Chronicle team to understand the root cause and potential recovery timeline.

#### Step 3d: After spell executes, verify

```bash
cast call <Basin_address> "creditTokenRateProvider()(address)" --rpc-url <rpc>
cast call <Basin_address> "totalAssets()(uint256)" --rpc-url <rpc>
```

**Trade-off**: A `FixedRateProvider` freezes the credit-token exchange rate. This is
acceptable as an emergency measure to unblock withdrawals but means the credit-token
price will not track the underlying asset. Once Chronicle recovers (or an alternative
oracle is available), swap back to a live rate provider via another governance spell.

### Phase 4: USDS Recovery via Pocket Back-Door (Partial)

If governance is delayed and withdrawals remain blocked, the `groveProxy` can pull USDS
directly from the pocket as a stopgap.

This only recovers USDS in the pocket, not USDC or LP share-based withdrawals.

## Escalation Timeline

| Trigger | Action | Role | Timing |
|---------|--------|------|--------|
| Oracle age > threshold - 24h | Alert: staleness approaching | Monitoring | Proactive |
| Oracle stale, withdrawals revert | Extend threshold to max (2 weeks) | `MANAGER_ROLE` | Immediate |
| Oracle stale, no root cause from Chronicle | Queue bound increase spell (e.g., 30 days) | `MANAGER_ADMIN_ROLE` (governance) | Queue immediately, in parallel with Phase 1 |
| Oracle stale, no root cause from Chronicle | Deploy FixedRateProvider, queue swap spell | `MANAGER_ADMIN_ROLE` (governance) | Queue immediately, in parallel with Phase 1-2 |
| Governance spell executes (bounds) | Extend threshold to new max | `MANAGER_ROLE` | Immediate after execution |
| Governance spell executes (rate provider) | Verify withdrawals unblocked | `MANAGER_ROLE` | Immediate after execution |
| Chronicle recovers | Swap back to ChronicleRateProvider | `MANAGER_ADMIN_ROLE` (governance) | When live oracle confirmed stable |
