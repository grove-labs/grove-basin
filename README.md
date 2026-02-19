# Grove Basin

![Foundry CI](https://github.com/grove-labs/grove-basin/actions/workflows/master.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/grove-labs/grove-basin/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository contains the implementation of the Grove Basin contract, which facilitates the swapping, depositing, and withdrawing of tokenized credit, the collateral they can be redeemed to, and another stablecoin to unlock atomic swaps for tokenized credit holders. Grove Basin is a fork of [Spark PSM3](https://github.com/sparkdotfi/spark-psm).

The Basin contract allows users to swap between a tokenized credit asset, its underlying collateral, and another stablecoin, deposit any of the assets to mint shares, and withdraw any of the assets by burning shares.

The conversion between a stablecoin and the tokenized credit asset is provided by a rate provider contract. The rate provider returns the conversion rate between the tokenized credit asset and the stablecoin in 1e27 precision. The conversion between the stablecoins is determined by a different rate provider

The conversion rate between assets and shares is based on the total value of assets within Basin. The total value is calculated by converting the assets to their equivalent value in USD with 18 decimal precision. The shares represent the ownership of the underlying assets in Grove Basin. Since three assets are used, each with different precisions and values, they are converted to a common USD-denominated value for share conversions.

For detailed implementation, refer to the contract code and `IGroveBasin` interface documentation.

## Contracts

- **`src/GroveBasin.sol`**: The core contract implementing the `IGroveBasin` interface, providing functionality for swapping, depositing, and withdrawing assets.
- **`src/interfaces/IGroveBasin.sol`**: Defines the essential functions and events that Grove Basin contract implements.

## [CRITICAL]: First Depositor Attack Prevention on Deployment

On the deployment of Grove Basin, the deployer **MUST make an initial deposit to get AT LEAST 1e18 shares in order to protect the first depositor from getting attacked with a share inflation attack or DOS attack**. Technical details related to this can be found in `test/InflationAttack.t.sol`.

The DOS attack is performed by:
1. Attacker sends funds directly to Grove Basin. `totalAssets` now returns a non-zero value.
2. Victim calls deposit. `convertToShares` returns `amount * totalShares / totalValue`. In this case, `totalValue` is non-zero and `totalShares` is zero, so it performs `amount * 0 / totalValue` and returns zero.
3. The victim has `transferFrom` called moving their funds into Grove Basin, but they receive zero shares so they cannot recover any of their underlying assets. This renders Grove Basin unusable for all users since this issue will persist. `totalShares` can never be increased in this state.

The deployment library (`deploy/GroveBasinDeploy.sol`) in this repo contains logic for the deployer to perform this initial deposit, so it is **HIGHLY RECOMMENDED** to use this deployment library when deploying Grove Basin. Reasoning for the technical implementation approach taken is outlined in more detail [here](https://github.com/marsfoundation/spark-psm/pull/2).

## Grove Basin Contract Details

### State Variables and Immutables

- **`usdc`**: IERC20 interface of USDC.
- **`collateralToken`**: IERC20 interface of the collateral token. The collateral token is the underlying asset that can be redeemed for the tokenized credit asset.
- **`creditToken`**: IERC20 interface of the tokenized credit asset. Supports both rebasing and yield-accruing tokens.
- **`pocket`**: Address that holds custody of USDC. The `pocket` can deploy USDC to yield-bearing strategies. Defaulted to the address of Grove Basin itself.
- **`creditTokenRateProvider`**: Contract that returns a conversion rate between and creditToken and USD in 1e27 precision.
- **`totalShares`**: Total shares in Grove Basin. Shares represent the ownership of the underlying assets in Grove Basin.
- **`shares`**: Mapping of user addresses to their shares.

### Functions

#### Admin Functions

- **`setPocket`**: Sets the `pocket` address. Only the `owner` can call this function. This is a very important and sensitive action because it transfers the entire balance of USDC to the new `pocket` address. OZ Ownable is used for this function, and `owner` will always be set to the governance proxy.

#### Swap Functions

- **`swapExactIn`**: Allows swapping of assets based on current conversion rates, specifying an `amountIn` of the asset to swap. Ensures the derived output amount is above the `minAmountOut` specified by the user before executing the transfer and emitting the swap event. Includes a referral code.
- **`swapExactOut`**: Allows swapping of assets based on current conversion rates, specifying an `amountOut` of the asset to receive from the swap. Ensures the derived input amount is below the `maxAmountIn` specified by the user before executing the transfer and emitting the swap event. Includes a referral code.

#### Liquidity Provision Functions

- **`deposit`**: Deposits assets into Grove Basin, minting new shares. Includes a referral code.
- **`withdraw`**: Withdraws assets from Grove Basin by burning shares. Ensures the user has sufficient shares for the withdrawal and adjusts the total shares accordingly. Includes a referral code.

#### Redemption Functions
- **`initiateRedeem`**: Initiates a redemption of TBill for collateral. This function is only available to the `owner` of Grove Basin. It transfers the specified amount of TBill from the `pocket` to Grove Basin and emits a `RedeemInitiated` event.

#### Preview Functions

- **`previewDeposit`**: Estimates the number of shares minted for a given deposit amount.
- **`previewWithdraw`**: Estimates the number of shares burned and the amount of assets withdrawn for a specified amount.
- **`previewSwapExactIn`**: Estimates the amount of `assetOut` received for a given amount of `assetIn` in a swap.
- **`previewSwapExactOut`**: Estimates the amount of `assetIn` required to receive a given amount of `assetOut` in a swap.

#### Conversion Functions

NOTE: These functions do not round in the same way as preview functions, so they are meant to be used for general quoting purposes.

- **`convertToAssets`**: Converts shares to the equivalent amount of a specified asset.
- **`convertToAssetValue`**: Converts shares to their equivalent value in USD terms with 18 decimal precision.
- **`convertToShares`**: Converts asset values to shares based on the current exchange rate.

#### Asset Value Functions

- **`totalAssets`**: Returns the total value of all assets held by Grove Basin denominated in USD with 18 decimal precision.

### Events

- **`Swap`**: Emitted on asset swaps.
- **`Deposit`**: Emitted on asset deposits.
- **`Withdraw`**: Emitted on asset withdrawals.

## Running Tests

To run tests in this repo, run:

```bash
forge test
```
