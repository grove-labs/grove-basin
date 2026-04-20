# Grove Basin

![Foundry CI](https://github.com/grove-labs/grove-basin/actions/workflows/master.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/grove-labs/grove-basin/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository contains the implementation of the Grove Basin contract, which facilitates the swapping, depositing, and withdrawing of tokenized credit, the collateral they can be redeemed to, and another stablecoin to unlock atomic swaps for tokenized credit holders. Grove Basin is a fork of [Spark PSM3](https://github.com/sparkdotfi/spark-psm).

The Basin contract allows users to swap between a tokenized credit asset, its underlying collateral, and another stablecoin, deposit any of the assets to mint shares, and withdraw any of the assets by burning shares.

Each of the three assets has a dedicated rate provider contract that returns the conversion rate between the asset and USD. Rate providers return rates in configurable precision (typically 1e27). A staleness threshold is enforced on all rate provider responses.

The conversion rate between assets and shares is based on the total value of assets within Basin. The total value is calculated by converting the assets to their equivalent value in USD with 18 decimal precision. The shares represent the ownership of the underlying assets in Grove Basin. Since three assets are used, each with different precisions and values, they are converted to a common USD-denominated value for share conversions.

The contract uses OpenZeppelin `AccessControl` for role-based permissioning with five roles: `OWNER_ROLE`, `MANAGER_ADMIN_ROLE`, `MANAGER_ROLE`, `PAUSER_ROLE`, `REDEEMER_ROLE`, and `REDEEMER_CONTRACT_ROLE`.

For detailed implementation, refer to the contract code and `IGroveBasin` interface documentation.

## Contracts

### Core

- **`src/GroveBasin.sol`**: The core contract implementing the `IGroveBasin` interface, providing functionality for swapping, depositing, and withdrawing assets.
- **`src/GroveBasinFactory.sol`**: Factory contract for deploying Grove Basin with an initial deposit to prevent first-depositor attacks.

### Pockets

- **`src/pockets/BasePocket.sol`**: Abstract base contract for all pockets, containing shared authorization logic and the immutable basin reference.
- **`src/pockets/UsdsUsdcPocket.sol`**: Pocket that converts USDC to USDS via PSM on deposit and reverses on withdraw.
- **`src/pockets/MorphoUsdtPocket.sol`**: Pocket that deploys USDT liquidity into a Morpho ERC-4626 vault and withdraws on demand.
- **`src/pockets/AaveV3UsdtPocket.sol`**: Pocket that deploys USDT liquidity into Aave V3 and withdraws on demand.

### Rate Providers

- **`src/rate-providers/FixedRateProvider.sol`**: Rate provider that returns a fixed, immutable conversion rate set at deployment.
- **`src/rate-providers/ChronicleRateProvider.sol`**: Rate provider that fetches conversion rates from a Chronicle oracle, scaling to 1e27 precision.

### Redeemers

- **`src/redeemers/BUIDLTokenRedeemer.sol`**: Token redeemer that handles BUIDL credit token redemptions through an offchain settlement process.
- **`src/redeemers/JTRSYTokenRedeemer.sol`**: Token redeemer that handles asynchronous credit token redemptions through an ERC-7540 vault.


## [CRITICAL]: First Depositor Attack Prevention on Deployment

On the deployment of Grove Basin, the deployer **MUST make an initial deposit to get AT LEAST 1e18 shares in order to protect the first depositor from getting attacked with a share inflation attack or DOS attack**. Technical details related to this can be found in `test/InflationAttack.t.sol`.

The DOS attack is performed by:
1. Attacker sends funds directly to Grove Basin. `totalAssets` now returns a non-zero value.
2. Victim calls deposit. `convertToShares` returns `amount * totalShares / totalValue`. In this case, `totalValue` is non-zero and `totalShares` is zero, so it performs `amount * 0 / totalValue` and returns zero.
3. The victim has `transferFrom` called moving their funds into Grove Basin, but they receive zero shares so they cannot recover any of their underlying assets. This renders Grove Basin unusable for all users since this issue will persist. `totalShares` can never be increased in this state.

The `depositInitial` function is provided for this purpose -- it mints shares to the zero address as a permanent seed deposit. The `GroveBasinFactory` (`src/GroveBasinFactory.sol`) calls `depositInitial` during deployment, so it is **HIGHLY RECOMMENDED** to use the factory when deploying Grove Basin. Reasoning for the technical implementation approach taken is outlined in more detail [here](https://github.com/marsfoundation/spark-psm/pull/2).

## Grove Basin Contract Details

### Roles

- **`OWNER_ROLE`**: Equivalent to `DEFAULT_ADMIN_ROLE`. Can set purchase and redemption fees within bounds, and manage all other roles.
- **`MANAGER_ADMIN_ROLE`**: Can set rate providers, swap size bounds, staleness threshold bounds, fee bounds, pocket, fee claimer, and add/remove token redeemers. Admin of `MANAGER_ROLE`, `PAUSER_ROLE`, `REDEEMER_ROLE`, and `REDEEMER_CONTRACT_ROLE`.
- **`MANAGER_ROLE`**: Can set max swap size and staleness threshold within their respective bounds.
- **`PAUSER_ROLE`**: Can pause/unpause individual functions or the entire contract. Can also revoke `MANAGER_ROLE` and `REDEEMER_ROLE`.
- **`REDEEMER_ROLE`**: Can initiate and complete credit token redemptions.
- **`REDEEMER_CONTRACT_ROLE`**: Granted to token redeemer contracts that handle the actual redemption logic.


### Functions

#### Manager Admin Functions

- **`setRateProvider`**: Sets the rate provider for a given token. The token must be one of the three supported assets. Only callable by `MANAGER_ADMIN_ROLE`.
- **`setMaxSwapSizeBounds`**: Sets the lower and upper bounds for max swap size. Clamps the current max swap size if it falls outside the new bounds. Only callable by `MANAGER_ADMIN_ROLE`.
- **`setStalenessThresholdBounds`**: Sets the min and max staleness threshold. Clamps the current threshold if it falls outside the new bounds. Only callable by `MANAGER_ADMIN_ROLE`.
- **`setFeeBounds`**: Sets the min and max fee in BPS. Reverts if current fees are outside the new bounds. Only callable by `MANAGER_ADMIN_ROLE`.
- **`setPocket`**: Sets the `pocket` address, transferring the entire swap token balance to the new pocket. Only callable by `MANAGER_ADMIN_ROLE`.
- **`addTokenRedeemer`**: Adds a token redeemer contract, granting it `REDEEMER_CONTRACT_ROLE` and calling its `setUp` function. Only callable by `MANAGER_ADMIN_ROLE`.
- **`removeTokenRedeemer`**: Removes a token redeemer contract, revoking `REDEEMER_CONTRACT_ROLE` and calling its `tearDown` function. Only callable by `MANAGER_ADMIN_ROLE`.
- **`setFeeClaimer`**: Sets the address that accrues fee shares on swaps. Only callable by `MANAGER_ADMIN_ROLE`.

#### Owner Functions

- **`setPurchaseFee`**: Sets the purchase fee in BPS. Must be within `[minFee, maxFee]`. Only callable by `OWNER_ROLE`.
- **`setRedemptionFee`**: Sets the redemption fee in BPS. Must be within `[minFee, maxFee]`. Only callable by `OWNER_ROLE`.

#### Manager Functions

- **`setMaxSwapSize`**: Sets the maximum swap size in 1e18 precision. Must be within `[maxSwapSizeLowerBound, maxSwapSizeUpperBound]`. Only callable by `MANAGER_ROLE`.
- **`setStalenessThreshold`**: Sets the staleness threshold in seconds. Must be within `[minStalenessThreshold, maxStalenessThreshold]`. Only callable by `MANAGER_ROLE`.

#### Pauser Functions

- **`setPaused`**: Sets or unsets a pause flag. Supports global pause (`bytes4(0)`) and per-function/per-direction pause keys. Only callable by `PAUSER_ROLE`.

#### Swap Functions

- **`swapExactIn`**: Allows swapping of assets based on current conversion rates, specifying an `amountIn` of the asset to swap. Enforces `maxSwapSize`, deducts the applicable fee, and ensures the net output is above `minAmountOut`. Includes a referral code.
- **`swapExactOut`**: Allows swapping of assets based on current conversion rates, specifying an `amountOut` of the asset to receive from the swap. Enforces `maxSwapSize`, adds the applicable fee, and ensures the derived input is below `maxAmountIn`. Includes a referral code.

#### Liquidity Provision Functions

- **`depositInitial`**: Makes the initial seed deposit, minting shares to the zero address. Callable by anyone but only when `totalShares == 0`.
- **`deposit`**: Deposits assets into Grove Basin, minting new shares to a specified receiver. Only callable by `liquidityProvider`.
- **`withdraw`**: Withdraws assets from Grove Basin by burning shares. Ensures the user has sufficient shares for the withdrawal and adjusts the total shares accordingly.

#### Redemption Functions

- **`initiateRedeem`**: Initiates a credit token redemption using a specified token redeemer contract. Stores a `RedeemRequest` and tracks `pendingCreditTokenBalance`. Only callable by `REDEEMER_ROLE`.
- **`completeRedeem`**: Completes a pending credit token redemption by its request ID, decreasing the pending credit token balance and returning collateral tokens. Only callable by `REDEEMER_ROLE`.

#### Fee Calculation Functions

- **`calculatePurchaseFee`**: Returns the purchase fee for a given amount (rounds up).
- **`calculateRedemptionFee`**: Returns the redemption fee for a given amount (rounds up).

#### Preview Functions

- **`previewDeposit`**: Estimates the number of shares minted for a given deposit amount.
- **`previewWithdraw`**: Estimates the number of shares burned and the amount of assets withdrawn for a specified amount.
- **`previewSwapExactIn`**: Estimates the net amount of `assetOut` received (after fees) for a given amount of `assetIn` in a swap.
- **`previewSwapExactOut`**: Estimates the amount of `assetIn` required (including fees) to receive a given amount of `assetOut` in a swap.

#### Conversion Functions

NOTE: These functions do not round in the same way as preview functions, so they are meant to be used for general quoting purposes.

- **`convertToAssets`**: Converts shares to the equivalent amount of a specified asset.
- **`convertToAssetValue`**: Converts shares to their equivalent value in USD terms with 18 decimal precision.
- **`convertToShares(uint256)`**: Converts a USD asset value to shares based on the current exchange rate.
- **`convertToShares(address, uint256)`**: Converts an amount of a given asset to shares based on the current exchange rate.

#### Asset Value Functions

- **`totalAssets`**: Returns the total value of all assets held by Grove Basin (including pending credit token redemptions) denominated in USD with 18 decimal precision.


## Running Tests

To run tests in this repo, run:

```bash
forge test
```
