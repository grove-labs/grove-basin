// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

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

    error InvalidToken();
    error InvalidSwapSizeBounds();
    error MinThresholdZero();
    error InvalidThresholdBounds();
    error MinFeeGreaterThanMaxFee();
    error MaxFeeExceedsBps();
    error CurrentFeeOutOfNewBounds();
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
    error InsufficientInitialDeposit();
    error ZeroAmount();
    error NoNewShares();
    error NotLiquidityProvider();
    error SwapSizeExceeded();
    error InvalidAsset();
    error InvalidSwap();
    error StaleRate();
    error PurchaseFeeOutOfBounds();
    error RedemptionFeeOutOfBounds();
    error RequestAlreadyExists();
    error InvalidRedeemRequest();
    error PendingRedemptions();
    error InsufficientFunds();
    error NotAllowlisted();
    error LpTokenDepositNotAllowed();
    error NotAuthorizedToRemoveLp();
    error ArrayLengthMismatch();

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
     *  @param redeemer        Address of the redeemer contract.
     *  @param caller          Address of the caller that initiated the redemption.
     *  @param amount          Amount of credit tokens sent to the redeemer.
     *  @param redeemRequestId Identifier of the created redeem request.
     */
    event RedeemInitiated(address indexed redeemer, address indexed caller, uint256 amount, bytes32 indexed redeemRequestId);

    /**
     *  @dev   Emitted when a credit token redemption is completed via a redeemer.
     *  @param redeemer        Address of the redeemer contract.
     *  @param caller          Address of the caller that completed the redemption.
     *  @param amount          Amount of collateral tokens returned from the redeemer.
     *  @param redeemRequestId Identifier of the completed redeem request.
     */
    event RedeemCompleted(address indexed redeemer, address indexed caller, uint256 amount, bytes32 indexed redeemRequestId);

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
     *  @dev   Emitted when a pocket's depositLiquidity call fails. The tokens remain in the
     *         pocket for the manager to deposit at a later time.
     *  @param pocket Address of the pocket that failed.
     *  @param asset  Address of the asset that was being deposited.
     *  @param amount Amount that failed to deposit.
     */
    event DepositLiquidityFailed(address indexed pocket, address indexed asset, uint256 amount);

    /**
     *  @dev   Emitted when a pause flag is set or unset.
     *  @param key    The pause key being toggled. Can be a function selector, an arbitrary
     *                bytes4 key, or bytes4(0) for the global pause.
     *  @param paused Whether the key is paused.
     */
    event PausedSet(bytes4 indexed key, bool paused);

    /**
     *  @dev   Emitted when a liquidity provider is added via addLiquidityProvider.
     *  @param provider Address of the liquidity provider.
     */
    event LiquidityProviderAdded(address indexed provider);

    /**
     *  @dev   Emitted when a liquidity provider is removed via removeLiquidityProvider.
     *  @param provider Address of the liquidity provider.
     */
    event LiquidityProviderRemoved(address indexed provider);

    /**
     *  @dev   Emitted when a deposit allowance is toggled for an LP and token.
     *  @param provider Address of the liquidity provider.
     *  @param token    Address of the token.
     *  @param allowed  Whether the LP is allowed to deposit the token.
     */
    event LpDepositAllowedSet(address indexed provider, address indexed token, bool allowed);

    /**
     *  @dev   Emitted when the allowlist flag for a route key is toggled.
     *  @param routeKey The route key being toggled, or GLOBAL_ROUTE_KEY for the global allowlist.
     *  @param enabled  Whether the route key is restricted to allowlisted callers.
     */
    event SwapAllowlistEnabledSet(bytes32 indexed routeKey, bool enabled);

    /**
     *  @dev   Emitted when a caller is added to or removed from the allowlist of a route.
     *  @param routeKey The route key whose allowlist changed, or GLOBAL_ROUTE_KEY for the global
     *                  allowlist.
     *  @param caller   Address whose allowlist entry changed.
     *  @param allowed  Whether the caller is allowlisted for the route.
     */
    event SwapAllowlistSet(bytes32 indexed routeKey, address indexed caller, bool allowed);

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
     *          token in the GroveBasin and can deploy it to an external venue. Settable by the manager admin.
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
     *  @dev    Returns the role identifier for the allowlist manager role. Addresses with this
     *          role can add and remove callers from the swap allowlist.
     *  @return The bytes32 role identifier.
     */
    function ALLOWLIST_MANAGER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the manager admin role. This role can update
     *          bounds, oracle values, set the pocket, set the fee claimer, unpause, toggle the
     *          swap allowlist gates, and add or remove token redeemers. It is also the role admin
     *          of MANAGER_ROLE, ALLOWLIST_MANAGER_ROLE, PAUSER_ROLE, REDEEMER_ROLE,
     *          REDEEMER_CONTRACT_ROLE, and LIQUIDITY_PROVIDER_ROLE, so it can grant and revoke
     *          all six through the inherited AccessControl functions.
     *  @return The bytes32 role identifier.
     */
    function MANAGER_ADMIN_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the liquidity provider role. Addresses with this
     *          role are the only ones allowed to call `deposit`. Administered by
     *          MANAGER_ADMIN_ROLE and also revocable by PAUSER_ROLE. Revoking the role only stops
     *          new deposits: withdrawals are gated on share ownership, so a revoked provider keeps
     *          access to the shares it already holds.
     *  @return The bytes32 role identifier.
     */
    function LIQUIDITY_PROVIDER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Pause key for credit-to-collateral swaps.
     *  @return The bytes4 pause key.
     */
    function PAUSED_SWAP_CREDIT_TO_COLLATERAL() external view returns (bytes4);

    /**
     *  @dev    Pause key for credit-to-swap swaps.
     *  @return The bytes4 pause key.
     */
    function PAUSED_SWAP_CREDIT_TO_SWAP() external view returns (bytes4);

    /**
     *  @dev    Pause key for collateral-to-credit swaps.
     *  @return The bytes4 pause key.
     */
    function PAUSED_SWAP_COLLATERAL_TO_CREDIT() external view returns (bytes4);

    /**
     *  @dev    Pause key for swap-to-credit swaps.
     *  @return The bytes4 pause key.
     */
    function PAUSED_SWAP_SWAP_TO_CREDIT() external view returns (bytes4);



    /**
     *  @dev    Returns whether a specific pause key is active. Pause keys can be function
     *          selectors or arbitrary bytes4 keys. Use bytes4(0) to check the global pause.
     *  @param  key The pause key (function selector, arbitrary key, or bytes4(0) for global pause).
     *  @return Whether the key is paused.
     */
    function paused(bytes4 key) external view returns (bool);

    /**
     *  @dev    Returns the role identifier for the pauser role. Addresses with this role can call
     *          setPaused, and can revoke MANAGER_ROLE, ALLOWLIST_MANAGER_ROLE, REDEEMER_ROLE,
     *          and LIQUIDITY_PROVIDER_ROLE through the inherited AccessControl `revokeRole`
     *          function, which the implementation overrides to grant this role that capability.
     *  @return The bytes32 role identifier.
     */
    function PAUSER_ROLE() external view returns (bytes32);

    /**
     *  @dev    Returns the role identifier for the redeemer role. Addresses with this role
     *          can call initiateRedeem and completeRedeem.
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
     *  @dev    Returns the number of pending redemptions for a given token redeemer.
     *  @param  redeemer The address of the token redeemer.
     *  @return The number of pending redemptions.
     */
    function pendingRedemptions(address redeemer) external view returns (uint256);

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

    /**
     *  @dev    Returns the route key reserved for the global allowlist, which gates every route
     *          that carries no gate of its own.
     *  @return The global route key.
     */
    function GLOBAL_ROUTE_KEY() external view returns (bytes32);

    /**
     *  @dev    Returns whether a route key is restricted to allowlisted callers. Use
     *          GLOBAL_ROUTE_KEY to check the global allowlist, which gates every route that
     *          carries no gate of its own.
     *  @param  routeKey The route key, or GLOBAL_ROUTE_KEY for the global allowlist.
     *  @return Whether the route key is restricted to allowlisted callers.
     */
    function swapAllowlistEnabled(bytes32 routeKey) external view returns (bool);

    /**
     *  @dev    Returns whether a caller is allowlisted for a route key. Entries are retained while
     *          a route is ungated and take effect again as soon as the route is gated. Entries
     *          under GLOBAL_ROUTE_KEY form the set applied to every route that carries no gate of
     *          its own.
     *  @param  routeKey The route key.
     *  @param  caller   Address to query.
     *  @return Whether the caller is allowlisted for the route key.
     */
    function swapAllowlist(bytes32 routeKey, address caller) external view returns (bool);

    /**
     *  @dev    Returns whether a liquidity provider is allowed to deposit a given token.
     *          By default all entries are false, meaning an LP with LIQUIDITY_PROVIDER_ROLE cannot
     *          deposit any token until explicitly allowed. When true, the LP can deposit that
     *          token. Granting the role via the inherited AccessControl grantRole leaves the
     *          mapping at its default (no tokens allowed); use addLiquidityProvider to grant the
     *          role and set allowed tokens atomically.
     *  @param  provider Address of the liquidity provider.
     *  @param  token    Address of the token (swapToken, collateralToken, or creditToken).
     *  @return Whether the LP is allowed to deposit the token.
     */
    function lpDepositAllowed(address provider, address token) external view returns (bool);

    /**
     *  @dev    Returns the route key for a swap direction. Routes are unidirectional, so the key
     *          for (assetIn, assetOut) is distinct from the key for (assetOut, assetIn).
     *  @param  assetIn  Address of the asset swapped in on the route.
     *  @param  assetOut Address of the asset swapped out on the route.
     *  @return The route key.
     */
    function getSwapRouteKey(address assetIn, address assetOut) external pure returns (bytes32);

    /**
     *  @dev    Returns whether `caller` may swap along a route. A gated route reads only its own
     *          allowlist, superseding the global one; otherwise the global allowlist applies while
     *          it is enabled. Always true while neither gate covers the route.
     *  @param  assetIn  Address of the asset swapped in on the route.
     *  @param  assetOut Address of the asset swapped out on the route.
     *  @param  caller   Address to query.
     *  @return Whether the caller may swap along the route.
     */
    function isSwapCallerAllowlisted(address assetIn, address assetOut, address caller)
        external view returns (bool);

    /**********************************************************************************************/
    /*** Manager admin functions                                                                ***/
    /**********************************************************************************************/

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
     *          MANAGER_ADMIN_ROLE. Reverts if current fees are outside the new bounds;
     *          OWNER_ROLE must adjust fees first.
     *  @param  newMinFee New minimum fee in BPS.
     *  @param  newMaxFee New maximum fee in BPS.
     */
    function setFeeBounds(uint256 newMinFee, uint256 newMaxFee) external;

    /**
     *  @dev    Sets the address of the pocket, an address that holds custody of the swap token in
     *          the GroveBasin and can deploy it to an external venue. If an external pocket is
     *          configured, this function first pulls its swap token liquidity back from the venue
     *          into that pocket and then transfers the balance from the existing pocket to the new
     *          pocket, so the tokens moved are held by the existing pocket rather than by the
     *          GroveBasin. Only when the GroveBasin itself is the existing pocket is the balance
     *          held by the GroveBasin transferred. Callable only by MANAGER_ADMIN_ROLE.
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
     *  @dev   Removes a token redeemer from the basin. Attempts to call the redeemer's tearDown
     *         function, ignoring any revert so that a misbehaving redeemer cannot block its own
     *         removal, and revokes the REDEEMER_CONTRACT_ROLE. A successful removal therefore does
     *         not imply that tearDown succeeded. Callable only by the MANAGER_ADMIN_ROLE.
     *  @param redeemer Address of the token redeemer to remove.
     */
    function removeTokenRedeemer(address redeemer) external;

    /**
     *  @dev   Adds a liquidity provider, granting LIQUIDITY_PROVIDER_ROLE and setting which
     *         tokens the LP is allowed to deposit. By default (empty allowedTokens), the LP
     *         cannot deposit any token. Callable only by MANAGER_ADMIN_ROLE.
     *  @param provider      Address to grant LIQUIDITY_PROVIDER_ROLE.
     *  @param allowedTokens Tokens the LP is allowed to deposit. Each must be a supported asset.
     *                       Empty means no tokens allowed.
     */
    function addLiquidityProvider(address provider, address[] calldata allowedTokens) external;

    /**
     *  @dev   Batch-updates whether a liquidity provider is allowed to deposit specific tokens.
     *         Callable only by MANAGER_ADMIN_ROLE.
     *  @param provider Address of the liquidity provider.
     *  @param tokens   Tokens to update (each must be a supported asset).
     *  @param allowed  Parallel array of booleans; true to allow, false to disallow.
     */
    function setLpDepositAllowed(address provider, address[] calldata tokens, bool[] calldata allowed) external;

    /**
     *  @dev   Removes a liquidity provider, revoking LIQUIDITY_PROVIDER_ROLE. Deposit allowances
     *         are intentionally preserved so the removed LP can still withdraw assets
     *         corresponding to shares it already holds. Callable by MANAGER_ADMIN_ROLE or
     *         PAUSER_ROLE.
     *  @param provider Address to revoke LIQUIDITY_PROVIDER_ROLE from.
     */
    function removeLiquidityProvider(address provider) external;

    /**
     *  @dev   Enables or disables the global allowlist, which gates every route that carries no
     *         gate of its own. Disabled on deployment. Callable only by MANAGER_ADMIN_ROLE.
     *  @param enabled Whether to restrict every route to allowlisted callers.
     */
    function setGlobalSwapAllowlistEnabled(bool enabled) external;

    /**
     *  @dev   Enables or disables the allowlist of a single route, superseding the global allowlist
     *         on that route. Routes are unidirectional, so gating (assetIn, assetOut) leaves
     *         (assetOut, assetIn) untouched. All routes are ungated on deployment. Callable only by
     *         MANAGER_ADMIN_ROLE. Reverts if either asset is not a basin asset.
     *  @param assetIn  Address of the asset swapped in on the route.
     *  @param assetOut Address of the asset swapped out on the route.
     *  @param enabled  Whether to restrict the route to allowlisted callers.
     */
    function setSwapAllowlistEnabled(address assetIn, address assetOut, bool enabled) external;

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
     *  @dev   Sets a pause flag. Pause keys can be function selectors or arbitrary
     *         bytes4 keys. Use bytes4(0) to set the global pause (pauses all pausable functions).
     *         Use setUnpaused to unpause.
     *  @param key The pause key (function selector, arbitrary key, or bytes4(0) for global pause).
     */
    function setPaused(bytes4 key) external;

    /**
     *  @dev   Unsets a pause flag. Callable only by MANAGER_ADMIN_ROLE.
     *  @param key The pause key to unpause (function selector, arbitrary key, or bytes4(0) for global pause).
     */
    function setUnpaused(bytes4 key) external;

    /**
     *  @dev   Sets the staleness threshold in seconds. Must be within
     *         [minStalenessThreshold, maxStalenessThreshold]. Callable only by MANAGER_ROLE.
     *  @param newThreshold The new staleness threshold in seconds.
     */
    function setStalenessThreshold(uint256 newThreshold) external;

    /**********************************************************************************************/
    /*** Allowlist manager functions                                                            ***/
    /**********************************************************************************************/

    /**
     *  @dev   Adds a caller to the allowlist of a route key. A route entry takes effect only while
     *         that route is gated; a GLOBAL_ROUTE_KEY entry takes effect only while the global
     *         allowlist is enabled and the route carries no gate of its own. Callable only by
     *         ALLOWLIST_MANAGER_ROLE.
     *  @param routeKey The route key, obtained from `getSwapRouteKey`, or GLOBAL_ROUTE_KEY.
     *  @param caller   Address to add to the allowlist.
     */
    function addToSwapAllowlist(bytes32 routeKey, address caller) external;

    /**
     *  @dev   Removes a caller from the allowlist of a route key. Callable only by
     *         ALLOWLIST_MANAGER_ROLE.
     *  @param routeKey The route key, obtained from `getSwapRouteKey`.
     *  @param caller   Address to remove from the allowlist.
     */
    function removeFromSwapAllowlist(bytes32 routeKey, address caller) external;

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
     *  @dev    Deposits an amount of a given asset into the GroveBasin. Only callable by
     *          LIQUIDITY_PROVIDER_ROLE holders. Must be one of the supported assets in order to
     *          succeed. The amount deposited is converted to shares based on the current exchange
     *          rate.
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

    /**
     * @dev    View function that returns the fee deducted from the gross output amount of an
     *         exactIn swap, using purchaseFee when assetOut is the credit token and redemptionFee
     *         otherwise. Rounds up. The quote returned by previewSwapExactIn is net of this fee.
     * @param  assetOut  Address of the ERC-20 asset to swap out.
     * @param  amountOut Gross amount of the asset out, before the fee is deducted.
     * @return fee       Fee amount in assetOut terms.
     */
    function previewSwapExactInFee(address assetOut, uint256 amountOut)
        external view returns (uint256 fee);

    /**
     * @dev    View function that returns the fee added to a net output amount to derive the gross
     *         output amount of an exactOut swap, using purchaseFee when assetOut is the credit
     *         token and redemptionFee otherwise. Rounds up. previewSwapExactOut prices the gross
     *         amount that includes this fee.
     * @param  assetOut  Address of the ERC-20 asset to swap out.
     * @param  amountOut Net amount of the asset out to be received from the swap.
     * @return fee       Fee amount in assetOut terms.
     */
    function previewSwapExactOutFee(address assetOut, uint256 amountOut)
        external view returns (uint256 fee);

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
     *  @return assetValue Normalized USD value of assets in 1e18 precision.
     */
    function convertToAssetValue(uint256 numShares) external view returns (uint256);

    /**
     *  @dev    View function that converts an amount of assetValue (normalized USD value in 1e18
     *          precision) to shares in the GroveBasin based on the current exchange rate. Note that
     *          this rounds down on calculation so is intended to be used for quoting the current
     *          exchange rate.
     *  @param  assetValue Normalized USD value in 1e18 precision.
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
     *  @dev    Returns the USD value of `amount` of `asset` in 1e18 precision.
     *          Reverts with `InvalidAsset` if `asset` is not one of the supported tokens.
     *  @param  asset   Address of the ERC-20 asset to value.
     *  @param  amount  Amount of the asset in asset-native units.
     *  @param  roundUp Whether to round up the result.
     *  @return The normalized USD value in 1e18 precision.
     */
    function getAssetValue(address asset, uint256 amount, bool roundUp) external view returns (uint256);

    /**
     *  @dev View function that returns the total value of the balance of all assets currently held
     *       by the GroveBasin, including the estimated value of pending credit tokens from
     *       redemptions, as a normalized USD value in 1e18 precision. Note:
     *       pendingCreditTokenBalance is an estimate of the value that Basin is due to receive,
     *       not a firm amount.
     */
    function totalAssets() external view returns (uint256);

}
