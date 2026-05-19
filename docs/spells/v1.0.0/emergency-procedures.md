# Emergency Procedures — Grove Basin v1.0.0

## 11. Pause-Initiation Procedure

### Who can initiate

The Grove Freezer Proxy [`0xB0113804960345fd0a245788b3423319c86940e5`](https://etherscan.io/address/0xB0113804960345fd0a245788b3423319c86940e5) is a **2-of-5 Gnosis Safe** (v1.4.1). Any 2 of the following 5 signers can initiate and confirm a pause transaction:

| # | Signer Address |
|---|----------------|
| 1 | `0x19b998Bb3975B3F556cCAea74E9478fc65A52DC1` |
| 2 | `0x701D0812bE1103EE166F154501826C30048e9653` |
| 3 | `0x6EB16fD8E5B185c86c7e61AB99e18809a41E78Ab` |
| 4 | `0x2dAD571383D5B4d04edD8CBb5F71FF6C5906E712` |
| 5 | `0xBD6d28927e7A7060638d4921A75Ef35B23555E26` |

The Freezer holds `PAUSER_ROLE` on both Basin instances:

| Basin | Address |
|-------|---------|
| JTRSY GroveBasin | [`0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363`](https://etherscan.io/address/0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363) |
| BUIDL GroveBasin | [`0x10b3d3A96646720f8B3a29229cF96d513f3C84F1`](https://etherscan.io/address/0x10b3d3A96646720f8B3a29229cF96d513f3C84F1) |

### Pre-conditions

- The ALM Freezer must hold `PAUSER_ROLE` on the target Basin (already configured at deployment).
- At least 2 of the 5 Freezer signers must be available to sign.
- The target Basin must not already be globally paused (re-pausing is a no-op; the call succeeds but has no additional effect).

### Transaction staging and execution order

For most cases, we would prefer a global pause:

**Global pause.** A Freezer signer creates a transaction in the Safe UI (or CLI) targeting the Basin contract:

- **To**: `<Basin address>` (JTRSY or BUIDL, see table above)
- **Value**: `0`
- **Data**: `setPaused(bytes4)` with key `0x00000000` (global pause)
  - Encoded calldata: `0x150c99d00000000000000000000000000000000000000000000000000000000000000000`

A second signer confirms the transaction in the Safe. Once the 2-of-5 threshold is met, any signer executes it on-chain.

In the event of a compromised Grove ALM Relayer, we would elect to revoke the MANAGER_ROLE:

**Revoke `MANAGER_ROLE` (full lockdown).** The Freezer stages a second Safe transaction:

- **To**: `<Basin address>`
- **Value**: `0`
- **Data**: `revokeRole(bytes32, address)` where `role` = `MANAGER_ROLE` (`0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08`) and `account` = ALM Relayer (`0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f`)

A second signer confirms and executes.

Similarly, in the event of a compromised redeemer, we would elect to revoke the REDEEMER_ROLE:

**Revoke `REDEEMER_ROLE` (full lockdown).** The Freezer stages a third Safe transaction:

- **To**: `<Basin address>`
- **Value**: `0`
- **Data**: `revokeRole(bytes32, address)` where `role` = `REDEEMER_ROLE` (`0x44ac9762eec3a11893fefb11d028bb3102560094137c3ed4518712475b2577cc`) and `account` = the basin's redeemer address

| Basin | Redeemer Address |
|-------|------------------|
| JTRSY | `0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a` |
| BUIDL | `0xdfC603076EA75895DD4d59c6e2ee5038f881CB74` |

A second signer confirms and executes.

If multiple transactions are required, they should be batched into a single multi-send Safe transaction to reduce confirmation overhead from multiple rounds to one.

We are currently exploring how to automate this process using a monitoring system through Hypernative.

### Side effects

| Step | Effect | Reversibility |
|------|--------|---------------|
| Global pause | All pausable functions (`swapExactIn`, `swapExactOut`, `deposit`, `withdraw`, `initiateRedeem`, `completeRedeem`) revert with `Paused()`. | Requires `MANAGER_ADMIN_ROLE` (Grove Proxy) to call `setUnpaused(bytes4(0))`. |
| Revoke `MANAGER_ROLE` | The ALM Relayer can no longer call manager-gated functions (rebalancing, pocket operations, fee collection). | Requires `MANAGER_ADMIN_ROLE` (Grove Proxy) to re-grant `MANAGER_ROLE`. |
| Revoke `REDEEMER_ROLE` | The issuer's redeemer address can no longer initiate new redemptions. In-flight redemptions already submitted to the issuer's settlement process can still be completed by the redeemer contract. | Requires `MANAGER_ADMIN_ROLE` (Grove Proxy) to re-grant `REDEEMER_ROLE`. |

---

## 12. Timelock-Cancel Procedure

### Applicable contracts

| Basin | TimelockController | Proposer (Issuer) | Cancellers |
|-------|-------------------|-------------------|------------|
| JTRSY | [`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`](https://etherscan.io/address/0xA52dC9876aB4A9DB6dAfbb83410554086054d140) | `0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c` (Anemoy) | Anemoy proposer + ALM Freezer |
| BUIDL | [`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`](https://etherscan.io/address/0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34) | `0x551e841e6fb54431a0664C8776784F6d7E611428` (Securitize) | Securitize proposer + ALM Freezer |

Both timelocks have a **7-day minimum delay** (`604800` seconds). The `CANCELLER_ROLE` is held by both the issuer's proposer address (granted automatically by the constructor) and the ALM Freezer (granted via deployment script).

### Pre-conditions

- A transaction must be in the **Pending** state (scheduled but not yet executed and not yet expired).
- The cancellation must occur before the 7-day delay elapses **and** before the Grove Proxy executes the queued operation.

### Procedure

**Step 1 — Identify the operation `id`.** When the issuer calls `schedule()` on the TimelockController, the contract emits:

```
event CallScheduled(
    bytes32 indexed id,
    uint256 indexed index,
    address target,
    uint256 value,
    bytes   data,
    bytes32 predecessor,
    uint256 delay
);
```

Locate the `id` (topic 1) from the `CallScheduled` event in the scheduling transaction's receipt. This can be found via:
- Etherscan: navigate to the scheduling tx → Logs tab → find the `CallScheduled` event → `id` is the first indexed topic.
- Cast: `cast receipt <tx_hash> --rpc-url mainnet` and inspect the logs.
- Alternatively, recompute: `id = keccak256(abi.encode(target, value, data, predecessor, salt))` using the arguments from the `schedule()` call.

**Step 2 — Stage the cancel transaction.** A Freezer signer creates a transaction in the Safe UI targeting the appropriate TimelockController:

- **To**: `<TimelockController address>` (see table above)
- **Value**: `0`
- **Data**: `cancel(bytes32)` with the `id` from Step 1
  - Function selector: `0xc4d252f5`
  - Encoded calldata: `0xc4d252f5` + `id` (32 bytes, zero-padded)

**Step 3 — Confirm and execute.** A second Freezer signer confirms the transaction in the Safe. Once the 2-of-5 threshold is met, any signer executes it on-chain.

### Side effects

- The operation transitions from **Pending** to **Unset** (deleted from the timelock's internal mapping).
- The `Cancelled(bytes32 indexed id)` event is emitted.
- The operation can never be executed. If the same action is still desired, the issuer must call `schedule()` again, restarting the full 7-day delay.
- No on-chain state is modified on the Basin itself — the cancel only removes the queued proposal from the timelock.

---

## 13. Governance USDS-Recovery Procedure

### Background

Each `UsdsUsdcPocket` grants an **unlimited USDS approval** (`type(uint256).max`) to the Grove Proxy (`0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`) at construction time. This is a residual recovery path: it allows a Sky governance spell, executing through the Grove Proxy, to withdraw any amount of USDS from the pocket without requiring cooperation from the Basin's access-control holders.

| Basin | UsdsUsdcPocket | USDS Approval Granted To |
|-------|---------------|--------------------------|
| JTRSY | [`0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9`](https://etherscan.io/address/0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9) | Grove Proxy (`0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`) |
| BUIDL | [`0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA`](https://etherscan.io/address/0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA) | Grove Proxy (`0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`) |

### Conditions that justify this path

This recovery path should only be invoked when:

1. The Basin's normal withdrawal mechanisms are compromised or unavailable (e.g., the Basin is paused and standard administrative recovery through the Grove Proxy's `MANAGER_ADMIN_ROLE` is insufficient or blocked).
2. The issuer's timelock proposer key is compromised and a malicious admin transaction is queued that cannot be safely canceled.
3. A critical vulnerability is discovered in the Basin or Pocket contract that could result in loss of USDS funds.
4. Sky governance determines that USDS liquidity must be recalled from the Basin system as an emergency measure.

### Destination address pattern

The destination is a **Sky governance-controlled address** — typically the Sky Pause Proxy or a designated recovery module within the Sky protocol. The specific address is determined by the governance spell and must be a trusted Sky-controlled contract, not an EOA.

### Spell structure

The recovery is executed via a **Sky governance spell** — a contract that, when executed through the Sky governance process, calls into the Grove Proxy:

1. **Sky governance proposes the spell.** The spell contract contains a single delegatecall-compatible function that, when executed by the Grove Proxy, performs:

   ```solidity
   IERC20(USDS).transferFrom(
       <UsdsUsdcPocket address>,   // source: the pocket holding USDS
       <Sky-controlled address>,    // destination: Sky Pause Proxy or recovery module
       <amount>                     // amount of USDS to recover (up to pocket balance)
   );
   ```

2. **Sky governance votes and passes the spell.** The spell follows the standard Sky governance process (executive vote, GSM delay).

3. **The spell is cast.** Execution flows: Sky governance → Grove Proxy (delegatecall) → `USDS.transferFrom(pocket, destination, amount)`. The Grove Proxy's pre-existing unlimited approval from the pocket allows the transfer to succeed.

4. **USDS arrives at the Sky-controlled destination.** From there, Sky governance can route the recovered USDS as appropriate (e.g., back into the DSS surplus buffer or into a new allocation).

### Side effects

- The pocket's USDS balance is reduced by the transferred amount. This reduces the Basin's available swap-token liquidity.
- The Basin's share accounting is unaffected — shareholders still hold their shares, but the underlying USDS backing those shares has been reduced.
- The unlimited approval from the pocket to the Grove Proxy remains intact after the transfer (approvals are not consumed by `transferFrom` when set to `type(uint256).max`).
- If the Basin is not paused, swaps and withdrawals that require USDS liquidity will fail with insufficient balance until liquidity is restored.

---

## 14. Other Emergency Actions

Beyond the Pause, Timelock Cancel, and Governance USDS Recovery procedures documented above, the following additional emergency capabilities exist within the system:

- **Pocket migration via Grove Proxy.** The Grove Proxy (as `MANAGER_ADMIN_ROLE` holder) can call `setPocket()` on a Basin to migrate swap-token custody to a new pocket contract. The old pocket automatically withdraws its swap-token balance back to the Basin during migration. This can be used to move funds out of a compromised pocket implementation.

- **ALM Proxy liquidity recall.** The ALM Proxy (`0x491EDFB0B8b608044e227225C715981a30F3A44E`), which is the designated `liquidityProvider` on both Basins, can withdraw deposited liquidity (shares) from the Basin. This is part of normal ALM operations but can be used in an emergency to pull allocated funds.

No other emergency actions are in scope for this spell beyond the above and the three primary procedures (Pause, Cancel, USDS Recovery).
