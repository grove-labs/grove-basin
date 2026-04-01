// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { RedeemRequest } from "src/interfaces/ITokenRedeemer.sol";

interface IGroveBasin {

    /**********************************************************************************************/
    /*** Custom errors                                                                          ***/
    /**********************************************************************************************/

    error InvalidOwner();
    error InvalidLiquidityProvider();
    error ZeroTokenAddress();
    error DuplicateTokens();
    error PrecisionTooHigh();
    error ZeroRateProviderAddress();
    error RateProviderReturnsZero();
    error InvalidRateProvider();
    error InvalidToken();
    error InvalidSwapSizeBounds();
    error MinThresholdZero();
    error InvalidThresholdBounds();
    error MinFeeGreaterThanMaxFee();
    error MaxFeeExceedsBps();
    error InvalidPocket();
    error InvalidRedeemer();
    error RedeemerAlreadyAdded();
    error SwapSizeOutOfBounds();
    error Paused();
    error ThresholdOutOfBounds();
    error SameThreshold();
    error ZeroAmountIn();
    error ZeroReceiver();
    error AmountOutTooLow();
    error ZeroAmountOut();
    error AmountInTooHigh();
    error AlreadySeeded();
    error ZeroAmount();
    error NoNewShares();
    error NotLiquidityProvider();
    error CreditDepositsDisabled();
    error SwapSizeExceeded();
    error InvalidAsset();
    error InvalidSwap();
    error StaleRate();
    error PurchaseFeeOutOfBounds();
    error RedemptionFeeOutOfBounds();
    error RequestAlreadyExists();
    error InvalidRedeemRequest();

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev   Emitted when a rate provider is updated.
     *  @param token           Address of the token whose rate provider was changed.
     *  @param oldRateProvider Address of the old rate provider.
     *  @param newRateProvider Address of the new rate provider.
     */
    event RateProviderSet(address indexed token, address indexed oldRateProvider, address indexed newRateProvider);

    /**
     *  @dev   Emitted when the max swap size is set in the GroveBasin.
     *  @param oldMaxSwapSize Old max swap size.
     *  @param newMaxSwapSize New max swap size.
     */
    event MaxSwapSizeSet(uint256 oldMaxSwapSize, uint256 newMaxSwapSize);

    /**
     *  @dev   Emitted when the max swap size bounds are updated.
     *  @param oldLowerBound Previous lower bound for max swap size.
     *  @param oldUpperBound Previous upper bound for max swap size.
     *  @param newLowerBound New lower bound for max swap size.
     *  @param newUpperBound New upper bound for max swap size.
     */
    event MaxSwapSizeBoundsSet(
        uint256 oldLowerBound,
        uint256 oldUpperBound,
        uint256 newLowerBound,
        uint256 newUpperBound
    );

    /**
     *  @dev   Emitted when the staleness threshold is updated.
     *  @param oldThreshold Previous staleness threshold in seconds.
     *  @param newThreshold New staleness threshold in seconds.
     */
    event StalenessThresholdSet(uint256 oldThreshold, uint256 newThreshold);

    /**
     *  @dev   Emitted when the staleness threshold bounds are updated.
     *  @param oldMinThreshold Previous minimum staleness threshold in seconds.
     *  @param oldMaxThreshold Previous maximum staleness threshold in seconds.
     *  @param newMinThreshold New minimum staleness threshold in seconds.
     *  @param newMaxThreshold New maximum staleness threshold in seconds.
     */
    event StalenessThresholdBoundsSet(
        uint256 oldMinThreshold,
        uint256 oldMaxThreshold,
        uint256 newMinThreshold,
        uint256 newMaxThreshold
    );

    /**
     *  @dev   Emitted when the fee bounds are set by governance.
     *  @param oldMinFee Old minimum fee in BPS.
     *  @param oldMaxFee Old maximum fee in BPS.
     *  @param newMinFee New minimum fee in BPS.
     *  @param newMaxFee New maximum fee in BPS.
     */
    event FeeBoundsSet(uint256 oldMinFee, uint256 oldMaxFee, uint256 newMinFee, uint256 newMaxFee);

    /**
     *  @dev   Emitted when the purchase fee is set.
     *  @param oldPurchaseFee Old purchase fee in BPS.
     *  @param newPurchaseFee New purchase fee in BPS.
     */
    event PurchaseFeeSet(uint256 oldPurchaseFee, uint256 newPurchaseFee);

    /**
     *  @dev   Emitted when the redemption fee is set.
     *  @param oldRedemptionFee Old redemption fee in BPS.
     *  @param newRedemptionFee New redemption fee in BPS.
     */
    event RedemptionFeeSet(uint256 oldRedemptionFee, uint256 newRedemptionFee);

    /**
     *  @dev   Emitted when a new pocket is set in the GroveBasin, transferring the balance of the
     *         swap token of the old pocket to the new pocket.
     *  @param oldPocket         Address of the old `pocket`.
     *  @param newPocket         Address of the new `pocket`.
     *  @param amountTransferred Amount of swap token transferred from the old pocket to the new pocket.
     */
    event PocketSet(
        address indexed oldPocket,
        address indexed newPocket,
        uint256 amountTransferred
    );

    /**
     *  @dev   Emitted when an asset is swapped in the GroveBasin.
     *  @param assetIn       Address of the asset swapped in.
     *  @param assetOut      Address of the asset swapped out.
     *  @param sender        Address of the sender of the swap.
     *  @param receiver      Address of the receiver of the swap.
     *  @param amountIn      Amount of the asset swapped in.
     *  @param amountOut     Amount of the asset swapped out.
     *  @param referralCode  Referral code for the swap.
     */
    event Swap(
        address indexed assetIn,
        address indexed assetOut,
        address sender,
        address indexed receiver,
        uint256 amountIn,
        uint256 amountOut,
        uint256 referralCode
    );

    /**
     *  @dev   Emitted when the credit token deposits disabled flag is set.
     *  @param disabled Whether credit token deposits are disabled.
     */
    event CreditTokenDepositsDisabledSet(bool disabled);

    /**
     *  @dev   Emitted when a token redeemer is added to the basin.
     *  @param redeemer Address of the redeemer contract.
     */
    event TokenRedeemerAdded(address indexed redeemer);

    /**
     *  @dev   Emitted when a token redeemer is removed from the basin.
     *  @param redeemer Address of the redeemer contract.
     */
    event TokenRedeemerRemoved(address indexed redeemer);

    /**
     *  @dev   Emitted when a credit token redemption is initiated via a redeemer.
     *  @param redeemer Address of the redeemer contract.
     *  @param caller   Address of the caller that initiated the redemption.
     *  @param amount   Amount of credit tokens sent to the redeemer.
     */
    event RedeemInitiated(address indexed redeemer, address indexed caller, uint256 amount);

    /**
     *  @dev   Emitted when a credit token redemption is completed via a redeemer.
     *  @param redeemer Address of the redeemer contract.
     *  @param caller   Address of the caller that completed the redemption.
     *  @param amount   Amount passed to the redeemer's completeRedeem.
     */
    event RedeemCompleted(address indexed redeemer, address indexed caller, uint256 amount);

    /**
     *  @dev   Emitted when fee shares are accrued to the fee claimer during a swap.
     *  @param claimer Address of the fee claimer.
     *  @param shares  Number of shares accrued.
     */
    event FeeSharesAccrued(address indexed claimer, uint256 shares);

    /**
     *  @dev   Emitted when the fee claimer address is updated.
     *  @param oldFeeClaimer Previous fee claimer address.
     *  @param newFeeClaimer New fee claimer address.
     */
    event FeeClaimerSet(address indexed oldFeeClaimer, address indexed newFeeClaimer);

    /**
     *  @dev   Emitted when a function pause flag is set or unset.
     *  @param sig    The function selector being paused/unpaused (bytes4(0) for global pause).
     *  @param paused Whether the function is paused.
     */
    event PausedSet(bytes4 indexed sig, bool paused);

    /**
     *  @dev   Emitted when an asset is deposited into the GroveBasin.
     *  @param asset           Address of the asset deposited.
     *  @param user            Address of the user that deposited the asset.
     *  @param receiver        Address of the receiver of the resulting shares from the deposit.
     *  @param assetsDeposited Amount of the asset deposited.
     *  @param sharesMinted    Number of shares minted to the user.
     */
    event Deposit(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsDeposited,
        uint256 sharesMinted
    );

    /**
     *  @dev   Emitted when an asset is withdrawn from the GroveBasin.
     *  @param asset           Address of the asset withdrawn.
     *  @param user            Address of the user that withdrew the asset.
     *  @param receiver        Address of the receiver of the withdrawn assets.
     *  @param assetsWithdrawn Amount of the asset withdrawn.
     *  @param sharesBurned    Number of shares burned from the user.
     */
    event Withdraw(
        address indexed asset,
        address indexed user,
        address indexed receiver,
        uint256 assetsWithdrawn,
        uint256 sharesBurned
    );

    /**********************************************************************************************/
    /*** State variables and immutables                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the address of the swap token.
     *  @return The address of the swap token.
     */
    function swapToken() external view returns (address);

    /**
     *  @dev    Returns the address of the collateral token.
     *  @return The address of the collateral token.
     */
    function collateralToken() external view returns (address);

    /**
     *  @dev    Returns the address of the credit token. This asset is the yield-bearing asset in
     *          the GroveBasin. The value of this asset is queried from the rate provider.
     *  @return The address of the credit token.
     */
    function creditToken() external view returns (address);

    /**
     *  @dev    Returns the maximum value of a swap in 1e18 precision. Settable by the manager.
     *  @return The maximum swap size in 1e18 precision.
     */
    function maxSwapSize() external view returns (uint256);

    /**
     *  @dev    Returns the lower bound for max swap size in 1e18 precision.
     *  @return The lower bound for max swap size in 1e18 precision.
     */
    function maxSwapSizeLowerBound() external view returns (uint256);

    /**
     *  @dev    Returns the upper bound for max swap size in 1e18 precision.
     *  @return The upper bound for max swap size in 1e18 precision.
     */
    function maxSwapSizeUpperBound() external view returns (uint256);

    /**
     *  @dev    Returns the staleness threshold in seconds. If the oracle's updatedAt timestamp is
     *          older than this threshold, operations using that oracle will revert.
     *  @return The staleness threshold in seconds.
     */
    function stalenessThreshold() external view returns (uint256);

    /**
     *  @dev    Returns the minimum allowed staleness threshold in seconds.
     *  @return The minimum staleness threshold in seconds.
     */
    function minStalenessThreshold() external view returns (uint256);

    /**
     *  @dev    Returns the maximum allowed staleness threshold in seconds.
     *  @return The maximum staleness threshold in seconds.
     */
    function maxStalenessThreshold() external view returns (uint256);

    /**
     *  @dev    Returns the address of the pocket, an address that holds custody of the swap
     *          token in the GroveBasin and can deploy it to yield-bearing strategies. Settable by the owner.
     *  @return The address of the pocket.
     */
    function pocket() external view returns (address);

    /**
     *  @dev    Returns the address of the swap token rate provider, a contract that provides
     *          the price of the swap token in USD terms.
     *  @return The address of the swap token rate provider.
     */
    function swapTokenRateProvider() external view returns (address);

    /**
     *  @dev    Returns the address of the collateral token rate provider, a contract that provides
     *          the price of the collateral token in USD terms.
     *  @return The address of the collateral token rate provider.
     */
    function collateralTokenRateProvider() external view returns (address);

    /**
     *  @dev    Returns the address of the credit token rate provider, a contract that provides the
     *          conversion rate between the credit token and USD.
     *  @return The address of the credit token rate provider.
     */
    function creditTokenRateProvider() external view returns (address);

    /**
     *  @dev    Returns the total number of shares in the GroveBasin. Shares represent ownership of the
     *          assets in the GroveBasin and can be converted to assets at any time.
     *  @return The total number of shares.
     */
    function totalShares() external view returns (uint256);

    /**
     *  @dev    Returns the number of shares held by a specific user.
     *  @param  user The address of the user.
     *  @return The number of shares held by the user.
     */
    function shares(address user) external view returns (uint256);

    /**
     *  @dev    Returns the basis points denominator (10,000 = 100%).
     *  @return The BPS denominator.
     */
    function BPS() external view returns (uint256);

    /**
     *  @dev    Returns the role identifier for the owner role (equivalent to DEFAULT_ADMIN_ROLE).
     *  @return The bytes32 role identifier.
     */
    function OWNER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the manager role.
     *  @return The bytes32 role identifier.
     */
    function MANAGER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the manager admin role. This role can update
     *          bounds, oracle values, set the pocket, and grant/revoke the MANAGER_ROLE.
     *  @return The bytes32 role identifier.
     */
    function MANAGER_ADMIN_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the address of the single immutable liquidity provider that is the only
     *          address allowed to deposit assets, including the initial seed deposit.
     *  @return The address of the liquidity provider.
     */
    function liquidityProvider() external view returns (address);

    /**
     *  @dev    Returns whether credit token deposits are disabled.
     *  @return Whether credit token deposits are disabled.
     */
    function creditTokenDepositsDisabled() external view returns (bool);

    /**
     *  @dev    Returns whether a specific function is paused by its selector.
     *          Use bytes4(0) to check if the global pause is enabled.
     *  @param  sig The function selector (bytes4(0) for global pause).
     *  @return Whether the function is paused.
     */
    function paused(bytes4 sig) external view returns (bool);

    /**
     *  @dev    Returns the role identifier for the pauser role. Addresses with this role
     *          can call setPaused and revoke MANAGER_ROLE and REDEEMER_ROLE.
     *  @return The bytes32 role identifier.
     */
    function PAUSER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the redeemer role. Addresses with this role
     *          can call initiateRedeem.
     *  @return The bytes32 role identifier.
     */
    function REDEEMER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the redeemer contract role. Addresses with this
     *          role can be used as redeemer targets in initiateRedeem and completeRedeem.
     *  @return The bytes32 role identifier.
     */
    function REDEEMER_CONTRACT_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the total credit token amount from pending redemptions. This is an estimate
     *          of the value that Basin is due to receive, not a firm amount.
     *  @return The credit token amount from pending redemptions.
     */
    function pendingCreditTokenBalance() external view returns (uint256);

    /**
     *  @dev    Returns the address that accrues fee shares on every swap. The fee claimer can
     *          withdraw their shares like any other shareholder. Note: if the fee claimer is
     *          changed via `setFeeClaimer`, the previous claimer may still hold unclaimed shares.
     *  @return The fee claimer address.
     */
    function feeClaimer() external view returns (address);
    
    /**
     *  @dev    Returns the redeem request for a specific request ID.
     *  @param  redeemRequestId The keccak256 hash of the RedeemRequest struct.
     *  @return blockNumber The block number at initiation.
     *  @return redeemer The address of the redeemer contract.
     *  @return creditTokenAmount The amount of credit tokens redeemed.
     *  @return collateralTokenAmount The estimated collateral token amount.
     */
    function redeemRequests(bytes32 redeemRequestId) external view returns (
        uint256 blockNumber,
        address redeemer,
        uint256 creditTokenAmount,
        uint256 collateralTokenAmount
    );

    /**
     *  @dev    Returns the current purchase fee in BPS. Applied when buying credit tokens.
     *  @return The purchase fee in BPS.
     */
    function purchaseFee() external view returns (uint256);

    /**
     *  @dev    Returns the current redemption fee in BPS. Applied when redeeming credit tokens.
     *  @return The redemption fee in BPS.
     */
    function redemptionFee() external view returns (uint256);

    /**
     *  @dev    Returns the minimum allowed fee in BPS.
     *  @return The minimum fee bound in BPS.
     */
    function minFee() external view returns (uint256);

    /**
     *  @dev    Returns the maximum allowed fee in BPS.
     *  @return The maximum fee bound in BPS.
     */
    function maxFee() external view returns (uint256);

    /**********************************************************************************************/
    /*** Manager admin functions                                                                ***/
    /**********************************************************************************************/

    /**
     *  @dev    Sets whether credit token deposits are disabled. Callable only by MANAGER_ADMIN_ROLE.
     *  @param  disabled Whether to disable credit token deposits.
     */
    function setCreditTokenDepositsDisabled(bool disabled) external;

    /**
     *  @dev    Sets the rate provider for a given token. The token must be one of the supported
     *          assets (swapToken, collateralToken, creditToken). The new rate provider must return
     *          a non-zero conversion rate. Callable only by MANAGER_ADMIN_ROLE.
     *  @param  token           Address of the token whose rate provider is being updated.
     *  @param  newRateProvider  Address of the new rate provider.
     */
    function setRateProvider(address token, address newRateProvider) external;

    /**
     *  @dev   Sets the max swap size bounds. If the current max swap size is outside
     *         the new bounds, it is clamped. Callable only by MANAGER_ADMIN_ROLE.
     *  @param newLowerBound The new lower bound for max swap size in 1e18 precision.
     *  @param newUpperBound The new upper bound for max swap size in 1e18 precision.
     */
    function setMaxSwapSizeBounds(uint256 newLowerBound, uint256 newUpperBound) external;

    /**
     *  @dev   Sets the staleness threshold bounds. The min must be > 0 and <= max.
     *         If the current staleness threshold is outside the new bounds, it is clamped.
     *         Callable only by MANAGER_ADMIN_ROLE.
     *  @param newMinThreshold The new minimum staleness threshold in seconds.
     *  @param newMaxThreshold The new maximum staleness threshold in seconds.
     */
    function setStalenessThresholdBounds(uint256 newMinThreshold, uint256 newMaxThreshold) external;

    /**
     *  @dev    Sets the fee bounds for both purchase and redemption fees. Callable only by
     *          MANAGER_ADMIN_ROLE. If current fees are outside the new bounds,
     *          they are clamped to the nearest bound.
     *  @param  newMinFee New minimum fee in BPS.
     *  @param  newMaxFee New maximum fee in BPS.
     */
    function setFeeBounds(uint256 newMinFee, uint256 newMaxFee) external;

    /**
     *  @dev    Sets the address of the pocket, an address that holds custody of the swap token
     *          in the GroveBasin and can deploy it to yield-bearing strategies. This function will
     *          transfer the balance of the swap token in the GroveBasin to the new pocket.
     *          Callable only by MANAGER_ADMIN_ROLE.
     *  @param  newPocket Address of the new pocket.
     */
    function setPocket(address newPocket) external;

    /**
     *  @dev   Adds a token redeemer to the basin. Grants the REDEEMER_CONTRACT_ROLE and calls the
     *         redeemer's setUp function. Callable only by the MANAGER_ADMIN_ROLE.
     *  @param redeemer Address of the token redeemer to add.
     */
    function addTokenRedeemer(address redeemer) external;

    /**
     *  @dev   Removes a token redeemer from the basin. Calls the redeemer's tearDown function and
     *         revokes the REDEEMER_CONTRACT_ROLE. Callable only by the MANAGER_ADMIN_ROLE.
     *  @param redeemer Address of the token redeemer to remove.
     */
    function removeTokenRedeemer(address redeemer) external;

    /**********************************************************************************************/
    /*** Owner functions                                                                        ***/
    /**********************************************************************************************/

    /**
     *  @dev    Sets the purchase fee applied when buying credit tokens. Callable only by
     *          the OWNER_ROLE. Fee must be within [minFee, maxFee].
     *  @param  newPurchaseFee New purchase fee in BPS.
     */
    function setPurchaseFee(uint256 newPurchaseFee) external;

    /**
     *  @dev    Sets the redemption fee applied when redeeming credit tokens. Callable only by
     *          the OWNER_ROLE. Fee must be within [minFee, maxFee].
     *  @param  newRedemptionFee New redemption fee in BPS.
     */
    function setRedemptionFee(uint256 newRedemptionFee) external;

    /**********************************************************************************************/
    /*** Redeemer functions                                                                     ***/
    /**********************************************************************************************/

    /**
     *  @dev    Initiates a credit token redemption using a specific token redeemer.
     *          Callable only by the REDEEMER_ROLE.
     *  @param  redeemer          Address of the token redeemer to use.
     *  @param  creditTokenAmount Amount of credit tokens to redeem.
     *  @return redeemRequestId   The keccak256 hash of the RedeemRequest struct.
     */
    function initiateRedeem(address redeemer, uint256 creditTokenAmount) external returns (bytes32 redeemRequestId);

    /**
     *  @dev   Completes a credit token redemption using the redeemer from the stored request.
     *         Callable only by the REDEEMER_ROLE.
     *  @param redeemRequestId The keccak256 hash of the RedeemRequest struct.
     */
    function completeRedeem(bytes32 redeemRequestId) external;

    /**********************************************************************************************/
    /*** Manager functions                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev    Sets the maximum value of a swap in 1e18 precision. Must be within
     *          [maxSwapSizeLowerBound, maxSwapSizeUpperBound]. Callable only by MANAGER_ROLE.
     *  @param  newMaxSwapSize New max swap size in 1e18 precision.
     */
    function setMaxSwapSize(uint256 newMaxSwapSize) external;

    /**
     *  @dev   Sets or unsets a function pause flag by its selector. Callable only by PAUSER_ROLE.
     *         Use bytes4(0) to set the global pause (pauses all pausable functions).
     *  @param sig   The function selector to pause/unpause (bytes4(0) for global pause).
     *  @param state Whether to pause the function.
     */
    function setPaused(bytes4 sig, bool state) external;

    /**
     *  @dev   Sets the staleness threshold in seconds. Must be within
     *         [minStalenessThreshold, maxStalenessThreshold]. Callable only by MANAGER_ROLE.
     *  @param newThreshold The new staleness threshold in seconds.
     */
    function setStalenessThreshold(uint256 newThreshold) external;

    /**********************************************************************************************/
    /*** Fee claimer functions                                                                  ***/
    /**********************************************************************************************/

    /**
     *  @dev    Sets the address that accrues fee shares on swaps. Callable only by MANAGER_ADMIN_ROLE.
     *          Note: if the previous fee claimer holds shares, those shares remain; they are not
     *          transferred or burned. The previous claimer can still withdraw their shares.
     *  @param  newFeeClaimer The new fee claimer address.
     */
    function setFeeClaimer(address newFeeClaimer) external;

    /**********************************************************************************************/
    /*** Fee calculation functions                                                              ***/
    /**********************************************************************************************/

    /**
     *  @dev    View function that calculates the purchase fee for a given amount. Rounds up.
     *  @param  amount  The gross amount to calculate the fee on.
     *  @return fee     The fee amount that would be deducted.
     */
    function calculatePurchaseFee(uint256 amount) external view returns (uint256 fee);

    /**
     *  @dev    View function that calculates the redemption fee for a given amount. Rounds up.
     *  @param  amount  The gross amount to calculate the fee on.
     *  @return fee     The fee amount that would be deducted.
     */
    function calculateRedemptionFee(uint256 amount) external view returns (uint256 fee);

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Swaps a specified amount of assetIn for assetOut in the GroveBasin. The amount swapped is
     *          converted based on the current value of the two assets used in the swap. This
     *          function will revert if there is not enough balance in the GroveBasin to facilitate the
     *          swap. Both assets must be supported in the GroveBasin in order to succeed.
     *  @param  assetIn      Address of the ERC-20 asset to swap in.
     *  @param  assetOut     Address of the ERC-20 asset to swap out.
     *  @param  amountIn     Amount of the asset to swap in.
     *  @param  minAmountOut Minimum amount of the asset to receive.
     *  @param  receiver     Address of the receiver of the swapped assets.
     *  @param  referralCode Referral code for the swap.
     *  @return amountOut    Resulting amount of the asset that will be received in the swap.
     */
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);

    /**
     *  @dev    Swaps a derived amount of assetIn for a specific amount of assetOut in the GroveBasin. The
     *          amount swapped is converted based on the current value of the two assets used in
     *          the swap. This function will revert if there is not enough balance in the GroveBasin to
     *          facilitate the swap. Both assets must be supported in the GroveBasin in order to succeed.
     *  @param  assetIn      Address of the ERC-20 asset to swap in.
     *  @param  assetOut     Address of the ERC-20 asset to swap out.
     *  @param  amountOut    Amount of the asset to receive from the swap.
     *  @param  maxAmountIn  Max amount of the asset to use for the swap.
     *  @param  receiver     Address of the receiver of the swapped assets.
     *  @param  referralCode Referral code for the swap.
     *  @return amountIn     Resulting amount of the asset swapped in.
     */
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountIn);

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    /**
     *  @dev    Makes the initial seed deposit into the GroveBasin. Callable by anyone, but only
     *          once (when totalShares == 0). Shares are minted to the zero address. Must be
     *          one of the supported assets in order to succeed.
     *  @param  asset           Address of the ERC-20 asset to deposit.
     *  @param  assetsToDeposit Amount of the asset to deposit into the GroveBasin.
     *  @return newShares       Number of shares minted to the zero address.
     */
    function depositInitial(address asset, uint256 assetsToDeposit)
        external returns (uint256 newShares);

    /**
     *  @dev    Deposits an amount of a given asset into the GroveBasin. Only callable by the
     *          liquidity provider. Must be one of the supported assets in order to succeed.
     *          The amount deposited is converted to shares based on the current exchange rate.
     *  @param  asset           Address of the ERC-20 asset to deposit.
     *  @param  receiver        Address of the receiver of the resulting shares from the deposit.
     *  @param  assetsToDeposit Amount of the asset to deposit into the GroveBasin.
     *  @return newShares       Number of shares minted to the user.
     */
    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external returns (uint256 newShares);

    /**
     *  @dev    Withdraws an amount of a given asset from the GroveBasin up to `maxAssetsToWithdraw`.
     *          Must be one of the supported assets in order to succeed. The amount withdrawn is
     *          the minimum of the balance of the GroveBasin, the max amount, and the max amount of assets
     *          that the user's shares can be converted to.
     *  @param  asset               Address of the ERC-20 asset to withdraw.
     *  @param  receiver            Address of the receiver of the withdrawn assets.
     *  @param  maxAssetsToWithdraw Max amount that the user is willing to withdraw.
     *  @return assetsWithdrawn     Resulting amount of the asset withdrawn from the GroveBasin.
     */
    function withdraw(
        address asset,
        address receiver,
        uint256 maxAssetsToWithdraw
    ) external returns (uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Deposit/withdraw preview functions                                                     ***/
    /**********************************************************************************************/

    /**
     *  @dev    View function that returns the exact number of shares that would be minted for a
     *          given asset and amount to deposit.
     *  @param  asset  Address of the ERC-20 asset to deposit.
     *  @param  assets Amount of the asset to deposit into the GroveBasin.
     *  @return shares Number of shares to be minted to the user.
     */
    function previewDeposit(address asset, uint256 assets) external view returns (uint256 shares);

    /**
     *  @dev    View function that returns the exact number of assets that would be withdrawn and
     *          corresponding shares that would be burned in a withdrawal for a given asset and max
     *          withdraw amount. The amount returned is the minimum of the balance of the GroveBasin,
     *          the max amount, and the max amount of assets that the user's shares
     *          can be converted to.
     *  @param  asset               Address of the ERC-20 asset to withdraw.
     *  @param  maxAssetsToWithdraw Max amount that the user is willing to withdraw.
     *  @return sharesToBurn        Number of shares that would be burned in the withdrawal.
     *  @return assetsWithdrawn     Resulting amount of the asset withdrawn from the GroveBasin.
     */
    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        external view returns (uint256 sharesToBurn, uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Swap preview functions                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev    View function that returns the exact amount of assetOut that would be received for a
     *         given amount of assetIn in a swap. The amount returned is converted based on the
     *         current value of the two assets used in the swap.
     * @param  assetIn   Address of the ERC-20 asset to swap in.
     * @param  assetOut  Address of the ERC-20 asset to swap out.
     * @param  amountIn  Amount of the asset to swap in.
     * @return amountOut Amount of the asset that will be received in the swap.
     */
    function previewSwapExactIn(address assetIn, address assetOut, uint256 amountIn)
        external view returns (uint256 amountOut);

    /**
     * @dev    View function that returns the exact amount of assetIn that would be required to
     *         receive a given amount of assetOut in a swap. The amount returned is
     *         converted based on the current value of the two assets used in the swap.
     * @param  assetIn   Address of the ERC-20 asset to swap in.
     * @param  assetOut  Address of the ERC-20 asset to swap out.
     * @param  amountOut Amount of the asset to receive from the swap.
     * @return amountIn  Amount of the asset that is required to receive amountOut.
     */
    function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
        external view returns (uint256 amountIn);

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    /**
     *  @dev    View function that converts an amount of a given shares to the equivalent amount of
     *          assets for a specified asset.
     *  @param  asset     Address of the asset to use to convert.
     *  @param  numShares Number of shares to convert to assets.
     *  @return assets    Value of assets in asset-native units.
     */
    function convertToAssets(address asset, uint256 numShares) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of a given shares to the equivalent
     *          amount of assetValue.
     *  @param  numShares  Number of shares to convert to assetValue.
     *  @return assetValue Value of assets in swap token denominated in 18 decimals.
     */
    function convertToAssetValue(uint256 numShares) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of assetValue (18 decimal value denominated in
     *          swap token and collateral token) to shares in the GroveBasin based on the current
     *          exchange rate. Note that this rounds down on calculation so is intended to be used
     *          for quoting the current exchange rate.
     *  @param  assetValue 18 decimal value denominated in swap token (e.g., 1e6 swap token = 1e18)
     *  @return shares     Number of shares that the assetValue is equivalent to.
     */
    function convertToShares(uint256 assetValue) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of a given asset to shares in the GroveBasin based
     *          on the current exchange rate. Note that this rounds down on calculation so is
     *          intended to be used for quoting the current exchange rate.
     *  @param  asset  Address of the ERC-20 asset to convert to shares.
     *  @param  assets Amount of assets in asset-native units.
     *  @return shares Number of shares that the assetValue is equivalent to.
     */
    function convertToShares(address asset, uint256 assets) external view returns (uint256);

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    /**
     *  @dev View function that returns the total value of the balance of all assets currently held
     *       by the GroveBasin, including the estimated value of pending credit tokens from
     *       redemptions, converted to swap token/collateral token terms denominated in 18 decimal
     *       precision. Note: pendingCreditTokenBalance is an estimate of the value that Basin is
     *       due to receive, not a firm amount.
     */
    function totalAssets() external view returns (uint256);

}
