# Basin Issuer Implementation Guide

This document describes how Basin works for prospective issuers looking to integrate their credit token (e.g., a tokenized treasury fund) with Grove Basin. Basin is a multi-asset liquidity pool that facilitates swaps between a swap token, a collateral token, and an issuer's credit token.

> **Interested in integrating with Basin?** Reach out to the Grove team at **basin@grove.finance** to schedule an introductory call and begin the onboarding process.

## Table of Contents

- [1. Swapping](#1-swapping)
- [2. Redemptions](#2-redemptions)
- [3. Admin Timelock](#3-admin-timelock)
- [4. Onboarding Requirements and Timeline](#4-onboarding-requirements-and-timeline)
- [Glossary](#glossary)
- [Links](#links)

---

## 1. Swapping

Basin supports swaps between the credit token and either the swap token or the collateral token. All swaps must involve the credit token on one side. Swaps are permissionless -- anyone can call the swap functions directly on the Basin contract.

### Swap Functions

**`swapExactIn(address assetIn, address assetOut, uint256 amountIn, uint256 minAmountOut, address receiver, uint256 referralCode)`**

Swaps a specified amount of `assetIn` for `assetOut`. The caller specifies the exact input amount and a minimum acceptable output amount (slippage protection). Reverts if the output would be less than `minAmountOut`.

**`swapExactOut(address assetIn, address assetOut, uint256 amountOut, uint256 maxAmountIn, address receiver, uint256 referralCode)`**

Swaps enough `assetIn` to receive exactly `amountOut` of `assetOut`. The caller specifies the desired output amount and the maximum input they are willing to spend. Reverts if the required input exceeds `maxAmountIn`.

### Preview and Fee Functions

These view functions allow callers to query expected swap amounts and fees before executing a swap. They reflect the current oracle rates and fee configuration.

| Function | Description |
|---|---|
| `previewSwapExactIn(assetIn, assetOut, amountIn)` | Returns the net amount of `assetOut` the caller would receive for a given `amountIn`, after fees. |
| `previewSwapExactOut(assetIn, assetOut, amountOut)` | Returns the amount of `assetIn` required to receive exactly `amountOut`, including fees. |
| `previewSwapExactInFee(assetOut, amountOut)` | Returns the fee that will be deducted from a gross output amount in an exact-in swap. |
| `previewSwapExactOutFee(assetOut, amountOut)` | Returns the fee that must be added to a net output amount to compute the gross output in an exact-out swap. |
| `calculatePurchaseFee(amount)` | Returns the purchase fee (in credit token terms) for a given amount. Applied when the credit token is the output. |
| `calculateRedemptionFee(amount)` | Returns the redemption fee for a given amount. Applied when the credit token is the input (i.e., swapping credit token for swap or collateral token). |

> Note: at launch, Grove Basin will charge 0 fees. Fees are configurable by the issuer.

### Fee Structure

- **Purchase fee**: Applied when buying the credit token (swapping swap/collateral token for credit token).
- **Redemption fee**: Applied when selling the credit token (swapping credit token for swap/collateral token).
- Fees are expressed in basis points (BPS), where 10,000 = 100%.
- The issuer can adjust the purchase and redemption fees within bounds set by the manager admin. The current bounds can be queried via `minFee()` and `maxFee()`.

### Swap Limits

Each swap is subject to a maximum swap size (`maxSwapSize()`), denominated in normalized USD value (1e18 precision). This limit can be queried on-chain and applies per-transaction.

### Conversion Rate Queries

| Function | Description |
|---|---|
| `getAssetValue(asset, amount, roundUp)` | Returns the normalized USD value (1e18) of a given amount of an asset. |
| `convertToShares(asset, assets)` | Converts an asset amount to equivalent pool shares. |
| `convertToAssets(asset, numShares)` | Converts pool shares to equivalent asset amount. |
| `totalAssets()` | Returns the total USD value of all assets in the pool, including an estimate value of the credit tokens that are pending redemption. |

---

## 2. Redemptions

Basin uses a two-step asynchronous redemption process to convert credit tokens back to collateral tokens. Redemptions are initiated and completed on the Basin contract by an address with the `REDEEMER_ROLE`, and are processed through a token redeemer contract.

### Default Model: EOA based redemptions

_Reference contract:_ [BUIDLTokenRedeemer.sol](https://github.com/grove-labs/grove-basin/blob/main/src/redeemers/BUIDLTokenRedeemer.sol)

By default, prospective issuers will handle credit token redemptions through an offchain settlement process:

1. **On initiation**, the redeemer transfers credit tokens from Basin to a designated **redemption address** -- an allowlisted address provided by the issuer that receives and burns credit tokens.

2. **On completion**, the issuer sends collateral tokens to the redeemer contract. The issuer calls a function on Basin that returns the collateral tokens back to Basin.

Only one redemption may be active at a time per redeemer contract. 

The token redeemer contract is deployed with three immutable parameters:
- `creditToken` -- the issuer's credit token address
- `redemptionAddress` -- the address that receives credit tokens for offchain settlement (provided by the issuer)
- `basin` -- the Basin contract address

### Redemption Flow

#### Step 1: Initiate Redemption

The redeemer (address with `REDEEMER_ROLE`) calls:

```
basin.initiateRedeem(address redeemer, uint256 creditTokenAmount) -> bytes32 redeemRequestId
```

This:
- Computes the expected collateral token amount at the current oracle rate
- Creates a `RedeemRequest` record, identified by `redeemRequestId`
- Approves the redeemer contract to pull credit tokens from Basin
- Calls `redeemer.initiateRedeem(creditTokenAmount)`, which transfers credit tokens to the redemption address
- Increments `pendingCreditTokenBalance` (tracked as part of `totalAssets()`)

#### Step 2: Issuer Settles Offchain

The issuer processes the redemption offchain: receiving and burning the credit tokens at the redemption address, then sending the equivalent collateral tokens to the token redeemer contract.

#### Step 3: Complete Redemption

Once collateral tokens have arrived at the redeemer contract, the redeemer calls:

```
basin.completeRedeem(bytes32 redeemRequestId)
```

This:
- Calls `redeemer.completeRedeem(request)`, which transfers the redeemer's entire collateral token balance back to Basin
- Clears the `RedeemRequest` record and decrements `pendingCreditTokenBalance`

### Redemption Restrictions

- **No partial redemptions**: Each redemption must be completed in full. When `completeRedeem` is called, the redeemer contract transfers its entire collateral token balance back to Basin. The issuer must send the full collateral amount before completion can succeed.
- **One redemption at a time**: The token redeemer enforces that only a single redemption can be active at any given time. A new redemption cannot be initiated until the current one is completed. Calling `initiateRedeem` while a redemption is active will revert with `RedemptionAlreadyActive`.
- **Sweep function**: In the event of a mistake (e.g., tokens sent to the redeemer contract outside of the normal redemption flow), Grove governance can call `sweep(address token, uint256 amount)` on the redeemer contract to return tokens to Basin. This function can only be called by an address holding the `MANAGER_ADMIN_ROLE` on Basin. 

> Note: the sweep function can only transfer the credit token or the collateral token -- it cannot sweep arbitrary tokens from the redeemer contract.

#### Querying Redemption State

| Function | Description |
|---|---|
| `redeemRequests(redeemRequestId)` | Returns the details of a pending redemption (block number, redeemer, credit token amount, collateral token amount). |
| `pendingRedemptions(redeemer)` | Returns the number of pending redemptions for a given redeemer contract. |
| `pendingCreditTokenBalance()` | Returns the total credit token amount from all pending redemptions. |

### Custom Redemption Contracts

Issuers with custom contracts for handling primary redemptions (e.g., ERC-7540 async vaults) should reach out to Grove directly to discuss integration. Grove can deploy a custom `ITokenRedeemer` implementation tailored to the issuer's redemption infrastructure.

---

## 3. Admin Timelock

Each Basin instance has an associated `TimelockController` (OpenZeppelin) that holds the `OWNER_ROLE` on the Basin contract. The timelock enforces a **7-day minimum delay** on all administrative actions.

### Role Configuration

| Role | Holder | Description |
|---|---|---|
| `PROPOSER_ROLE` | **Issuer** | The issuer's designated address that can schedule transactions on the timelock. |
| `EXECUTOR_ROLE` | Grove Proxy | Executes transactions after the timelock delay has elapsed. |
| `CANCELLER_ROLE` | Issuer + ALM Freezer | Can cancel pending transactions. Granted to both the issuer (automatically via the constructor) and the ALM Freezer multisig. |
| `DEFAULT_ADMIN_ROLE` | Revoked | The deployer's admin role is revoked after setup is complete. |

### How the Timelock Works

1. **Propose**: The issuer calls `schedule()` on the timelock to queue a transaction. The minimum delay is 7 days.
2. **Wait**: The transaction remains pending for at least 7 days.
3. **Execute**: After the delay, Grove executes the transaction via the Grove Proxy by calling `execute()`.

The issuer (as proposer) can schedule changes to:
- Purchase and redemption fees (`setPurchaseFee`, `setRedemptionFee`) within the configured bounds

### Security Measures

The 7-day timelock provides a window for Grove to review proposed changes before execution. In the event of a security concern, Grove can take the following actions:

- **Cancel a suspicious transaction**: If a proposed transaction looks suspicious or if the issuer's proposer key is compromised, the ALM Freezer multisig (or the issuer themselves) can call `cancel()` on the timelock to cancel the pending transaction before it is executed.
- **Pull liquidity during the timelock period**: During the 7-day delay, Grove can withdraw stablecoin liquidity from the Basin, removing funds from the pool before a malicious transaction could take effect.
- **Emergency spell from Sky**: As a last resort, Sky governance can schedule an emergency spell to pull USDS from the system, cutting off the liquidity source entirely.

These layered defenses ensure that a compromised issuer key cannot unilaterally drain or manipulate the Basin.

---

## 4. Onboarding Requirements and Timeline

### Information Required from the Issuer

The issuer must provide the following addresses:

1. **Timelock proposer address** -- the address that will hold `PROPOSER_ROLE` on the Basin's timelock controller. This is the issuer's administrative key for scheduling Basin parameter changes.
2. **Redeemer address** -- the address that will hold `REDEEMER_ROLE` on Basin, authorized to call `initiateRedeem` and `completeRedeem`.
3. **Redemption address** -- the address where the token redeemer will send credit tokens for offchain settlement. This must be an allowlisted address capable of receiving and burning the credit tokens. If this is a smart contract, Grove will need to build a custom redeemer contract.

### Onboarding Steps

After the issuer provides the required addresses, the onboarding proceeds as follows:

1. **Contract deployment** -- Grove deploys the Basin, timelock, pocket, and token redeemer contracts, configuring the issuer's addresses.

2. **Credit token allowlisting** -- The issuer must add the Grove Basin contract and the TokenRedeemer contract to the credit token's allowlist. This is required for Basin to hold and transfer credit tokens during swaps and redemptions.

3. **Timelock test transaction** -- The issuer schedules a test transaction on the timelock (e.g., sending 1 wei of ETH to itself). Grove verifies the executor role by simulating execution on Tenderly, then cancels the test transaction via the ALM Freezer to verify the canceller role.

4. **Test swap** -- Grove executes a test swap through the Basin to verify the swap token, collateral token, and credit token are correctly configured, and that oracle rates are being fetched properly.

5. **Test redemption** -- A test redemption is initiated through the Basin to verify the redeemer contract correctly transfers credit tokens to the redemption address, and that the issuer can settle and return collateral tokens to complete the redemption.

6. **Liquidity allocation** -- After all tests pass, Grove will allowlist the Basin with the Grove Allocator via a governance spell, which will begin allocating stablecoin liquidity to the pool.

7. **Further integration** -- Issuers are encouraged to integrate Basin with their own frontends and user interfaces to enable clients to access instant liquidity. Basin is also integrated with a number of third-party platforms like Galaxy, FalconX, and Anchorage.

### Expected Timeline

The full onboarding process -- from receiving the issuer's addresses through liquidity allocation -- takes approximately **1 month**.

> **Ready to get started?** Contact the Grove team at **basin@grove.finance** to schedule an onboarding call and begin the integration process.

---

## Glossary

| Term | Definition |
|---|---|
| **ALM Freezer** | A Grove-controlled multisig that can cancel pending timelock transactions and pause Basin operations in an emergency. |
| **Collateral token** | The stablecoin used for settling redemptions. Usually USDC. When a credit token is redeemed via primary redemption, the issuer returns collateral tokens to the Basin. |
| **Credit token** | The issuer's yield-bearing tokenized asset (e.g., a tokenized treasury fund share). This is the asset that swappers buy and sell through Basin. Its value is determined by an external rate provider. |
| **Grove Proxy** | The Grove governance execution contract. Holds the `EXECUTOR_ROLE` on the timelock and the `MANAGER_ADMIN_ROLE` on Basin. |
| **Issuer** | The entity that issues the credit token and is responsible for honoring primary redemptions. The issuer holds the `PROPOSER_ROLE` on the Basin's admin timelock. |
| **Pocket** | A contract that holds custody of the swap token on behalf of Basin and can deploy it into yield-generating strategies (e.g., converting USDS to USDC via the PSM). |
| **Primary redemption** | The issuer's native redemption mechanism, which Basin interfaces with through the redeemer contract. |
| **Rate provider** | A contract that returns the conversion rate between an asset and USD. Basin uses rate providers to price each of its three tokens. Credit tokens typically use a Chronicle oracle-based rate provider; swap and collateral tokens use a fixed 1:1 rate provider. |
| **Redeemer** | The address (held by the issuer or their agent) with the `REDEEMER_ROLE` on Basin, authorized to initiate and complete redemptions. Distinct from the redeemer contract. |
| **Redeemer contract** | A smart contract implementing the `ITokenRedeemer` interface that handles the mechanics of transferring credit tokens out for settlement and receiving collateral tokens back. Registered on Basin with the `REDEEMER_CONTRACT_ROLE`. |
| **Redemption address** | The allowlisted address where the redeemer contract sends credit tokens for offchain settlement. Provided by the issuer. |
| **Swap token** | The stablecoin used as the primary liquidity asset in the Basin pool. Currently USDS, sourced from the Sky protocol via the Grove Allocator. |
| **Timelock** | An OpenZeppelin `TimelockController` that enforces a minimum delay (7 days) on administrative actions. The issuer proposes transactions; Grove executes them after the delay. |
| **Token redeemer** | A smart contract that handles primary redemption of credit tokens. Registered on Basin with the `REDEEMER_CONTRACT_ROLE`. |

---

## Links

- **Docs**: http://docs.grove.finance/
- **Codebase**: https://github.com/grove-labs/grove-basin
