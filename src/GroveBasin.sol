// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Math }          from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IGroveBasin }                   from "./interfaces/IGroveBasin.sol";
import { IGroveBasinPocket }             from "./interfaces/IGroveBasinPocket.sol";
import { IGroveRateProvider }             from "./interfaces/IGroveRateProvider.sol";
import { ITokenRedeemer, RedeemRequest } from "./interfaces/ITokenRedeemer.sol";

/**
 * @title  GroveBasin
 * @notice Multi-asset liquidity pool that facilitates swaps between a swap token, collateral
 *         token, and a yield-bearing credit token. Liquidity providers deposit assets in exchange
 *         for shares that represent pro-rata ownership of the pool's total value.
 * @dev    Uses AccessControl for role-based permissioning across owner, manager
 *         admin, manager, liquidity provider, and redeemer roles. Asset values are determined by
 *         external rate providers that return conversion rates. Swap token
 *         custody can be delegated to a pocket contract for yield generation.
 */
contract GroveBasin is IGroveBasin, AccessControl {

    using SafeERC20 for IERC20;

    uint256 public constant override BPS = 100_00;

    bytes32 public constant override OWNER_ROLE              = DEFAULT_ADMIN_ROLE;
    bytes32 public constant override MANAGER_ADMIN_ROLE      = keccak256("MANAGER_ADMIN_ROLE");
    bytes32 public constant override MANAGER_ROLE            = keccak256("MANAGER_ROLE");
    bytes32 public constant override PAUSER_ROLE             = keccak256("PAUSER_ROLE");
    bytes32 public constant override REDEEMER_ROLE           = keccak256("REDEEMER_ROLE");
    bytes32 public constant override REDEEMER_CONTRACT_ROLE  = keccak256("REDEEMER_CONTRACT_ROLE");

    /// @dev Pause keys
    bytes4 public constant PAUSED_SWAP_CREDIT_TO_COLLATERAL = bytes4(keccak256("PAUSED_SWAP_CREDIT_TO_COLLATERAL"));
    bytes4 public constant PAUSED_SWAP_CREDIT_TO_SWAP       = bytes4(keccak256("PAUSED_SWAP_CREDIT_TO_SWAP"));
    bytes4 public constant PAUSED_SWAP_COLLATERAL_TO_CREDIT = bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"));
    bytes4 public constant PAUSED_SWAP_SWAP_TO_CREDIT       = bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"));
    bytes4 public constant PAUSED_DEPOSIT_CREDIT            = bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"));

    uint256 internal immutable _swapTokenPrecision;
    uint256 internal immutable _collateralTokenPrecision;
    uint256 internal immutable _creditTokenPrecision;

    address public override immutable liquidityProvider;

    address public override immutable swapToken;
    address public override immutable collateralToken;
    address public override immutable creditToken;

    address public override swapTokenRateProvider;
    address public override collateralTokenRateProvider;
    address public override creditTokenRateProvider;

    address public override pocket;

    uint256 public override totalShares;
    uint256 public override pendingCreditTokenBalance;

    uint256 public override maxSwapSize;
    uint256 public override maxSwapSizeLowerBound;
    uint256 public override maxSwapSizeUpperBound;

    uint256 public override purchaseFee;
    uint256 public override redemptionFee;
    uint256 public override minFee;
    uint256 public override maxFee;

    uint256 public override stalenessThreshold;
    uint256 public override minStalenessThreshold;
    uint256 public override maxStalenessThreshold;
    
    address public override feeClaimer;

    /// @dev Mapping of pause keys to pause state. Keys can be function selectors or arbitrary
    ///      bytes4 values. bytes4(0) is reserved for global pause.
    mapping(bytes4 pauseKey   => bool isPaused)         public override paused;
    mapping(address user      => uint256 shares)        public override shares;
    mapping(bytes32 requestId => RedeemRequest request) public override redeemRequests;
    mapping(address redeemer  => uint256 count)         public override pendingRedemptions;

    constructor(
        address owner_,
        address liquidityProvider_,
        address swapToken_,
        address collateralToken_,
        address creditToken_,
        address swapTokenRateProvider_,
        address collateralTokenRateProvider_,
        address creditTokenRateProvider_
    ) {
        if (owner_ == address(0)) revert InvalidOwner();
        _grantRole(OWNER_ROLE, owner_);

        if (liquidityProvider_ == address(0)) revert InvalidLiquidityProvider();
        if (
            swapToken_       == address(0) ||
            collateralToken_ == address(0) ||
            creditToken_     == address(0)
        ) revert ZeroTokenAddress();

        if (
            swapToken_       == collateralToken_ ||
            swapToken_       == creditToken_     ||
            collateralToken_ == creditToken_
        ) revert DuplicateTokens();

        liquidityProvider = liquidityProvider_;

        swapToken       = swapToken_;
        collateralToken = collateralToken_;
        creditToken     = creditToken_;

        _swapTokenPrecision       = 10 ** IERC20(swapToken_).decimals();
        _collateralTokenPrecision = 10 ** IERC20(collateralToken_).decimals();
        _creditTokenPrecision     = 10 ** IERC20(creditToken_).decimals();

        // Necessary to ensure rounding works as expected
        if (
            _creditTokenPrecision     > 1e18 ||
            _swapTokenPrecision       > 1e18 ||
            _collateralTokenPrecision > 1e18
        ) revert PrecisionTooHigh();

        // Setup Rate Providers
        if (
            swapTokenRateProvider_       == address(0) ||
            collateralTokenRateProvider_ == address(0) ||
            creditTokenRateProvider_     == address(0)
        ) revert ZeroRateProviderAddress();

        if (
            IGroveRateProvider(swapTokenRateProvider_).getConversionRate()       == 0 ||
            IGroveRateProvider(collateralTokenRateProvider_).getConversionRate() == 0 ||
            IGroveRateProvider(creditTokenRateProvider_).getConversionRate()     == 0
        ) revert RateProviderReturnsZero();

        swapTokenRateProvider       = swapTokenRateProvider_;
        collateralTokenRateProvider = collateralTokenRateProvider_;
        creditTokenRateProvider     = creditTokenRateProvider_;

        // Set default values
        pocket                = address(this);
        maxSwapSize           = 50_000_000e18;
        maxSwapSizeLowerBound = 0;
        maxSwapSizeUpperBound = 1_000_000_000e18;
        minStalenessThreshold = 5 minutes;
        maxStalenessThreshold = 2 weeks;
        stalenessThreshold    = minStalenessThreshold;

        _setRoleAdmin(MANAGER_ROLE,           MANAGER_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE,            MANAGER_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_CONTRACT_ROLE, MANAGER_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_ROLE,          MANAGER_ADMIN_ROLE);
    }

    /**********************************************************************************************/
    /*** Manager admin functions                                                                ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function setRateProvider(address token, address newRateProvider) external override onlyRole(MANAGER_ADMIN_ROLE) {
        if (newRateProvider == address(0))                               revert InvalidRateProvider();
        if (IGroveRateProvider(newRateProvider).getConversionRate() == 0) revert RateProviderReturnsZero();

        address oldRateProvider;

        if (token == swapToken) {
            oldRateProvider             = swapTokenRateProvider;
            swapTokenRateProvider       = newRateProvider;
        } else if (token == collateralToken) {
            oldRateProvider             = collateralTokenRateProvider;
            collateralTokenRateProvider = newRateProvider;
        } else if (token == creditToken) {
            oldRateProvider             = creditTokenRateProvider;
            creditTokenRateProvider     = newRateProvider;
        } else {
            revert InvalidToken();
        }

        emit RateProviderSet(token, oldRateProvider, newRateProvider);
    }

    /// @inheritdoc IGroveBasin
    function setMaxSwapSizeBounds(uint256 newLowerBound, uint256 newUpperBound)
        external override onlyRole(MANAGER_ADMIN_ROLE)
    {
        if (newLowerBound > newUpperBound) revert InvalidSwapSizeBounds();

        uint256 oldLowerBound = maxSwapSizeLowerBound;
        uint256 oldUpperBound = maxSwapSizeUpperBound;

        maxSwapSizeLowerBound = newLowerBound;
        maxSwapSizeUpperBound = newUpperBound;

        emit MaxSwapSizeBoundsSet(oldLowerBound, oldUpperBound, newLowerBound, newUpperBound);

        uint256 currentMaxSwapSize = maxSwapSize;
        if (currentMaxSwapSize < newLowerBound) {
            maxSwapSize = newLowerBound;    
        } else if (currentMaxSwapSize > newUpperBound) {
            maxSwapSize = newUpperBound;
        }

        emit MaxSwapSizeSet(currentMaxSwapSize, maxSwapSize);
    }

    /// @inheritdoc IGroveBasin
    function setStalenessThresholdBounds(uint256 newMinThreshold, uint256 newMaxThreshold)
        external override onlyRole(MANAGER_ADMIN_ROLE)
    {
        if (newMinThreshold == 0)              revert MinThresholdZero();
        if (newMinThreshold > newMaxThreshold) revert InvalidThresholdBounds();

        uint256 oldMinThreshold = minStalenessThreshold;
        uint256 oldMaxThreshold = maxStalenessThreshold;

        minStalenessThreshold = newMinThreshold;
        maxStalenessThreshold = newMaxThreshold;

        emit StalenessThresholdBoundsSet(oldMinThreshold, oldMaxThreshold, newMinThreshold, newMaxThreshold);

        uint256 threshold = stalenessThreshold;
        if (threshold < newMinThreshold) {
            stalenessThreshold = newMinThreshold;
        } else if (threshold > newMaxThreshold) {
            stalenessThreshold = newMaxThreshold;
        }

        emit StalenessThresholdSet(threshold, stalenessThreshold);
    }

    /// @inheritdoc IGroveBasin
    function setFeeBounds(uint256 newMinFee, uint256 newMaxFee) external override onlyRole(MANAGER_ADMIN_ROLE) {
        if (newMinFee > newMaxFee) revert MinFeeGreaterThanMaxFee();
        if (newMaxFee >= BPS)       revert MaxFeeExceedsBps();

        if (
            purchaseFee    < newMinFee || purchaseFee    > newMaxFee ||
            redemptionFee  < newMinFee || redemptionFee  > newMaxFee
        ) revert CurrentFeeOutOfNewBounds();

        uint256 oldMinFee = minFee;
        uint256 oldMaxFee = maxFee;

        minFee = newMinFee;
        maxFee = newMaxFee;

        emit FeeBoundsSet(oldMinFee, oldMaxFee, newMinFee, newMaxFee);
    }

    /// @inheritdoc IGroveBasin
    function setPocket(address newPocket) external override onlyRole(MANAGER_ADMIN_ROLE) {
        address pocket_ = pocket;

        if (newPocket == address(0) || newPocket == pocket_) revert InvalidPocket();

        _withdrawLiquidityInPocket(_getAvailableBalance(swapToken), swapToken);

        uint256 amountToTransfer = IERC20(swapToken).balanceOf(pocket_);

        if (!_hasPocket()) {
            IERC20(swapToken).safeTransfer(newPocket, amountToTransfer);
        } else {
            IERC20(swapToken).safeTransferFrom(pocket_, newPocket, amountToTransfer);
        }

        pocket = newPocket;

        emit PocketSet(pocket_, newPocket, amountToTransfer);
    }

    /// @inheritdoc IGroveBasin
    function addTokenRedeemer(address redeemer) external override onlyRole(MANAGER_ADMIN_ROLE) {
        if (redeemer == address(0))                        revert InvalidRedeemer();
        if (!_grantRole(REDEEMER_CONTRACT_ROLE, redeemer)) revert RedeemerAlreadyAdded();

        ITokenRedeemer(redeemer).setUp(address(this));

        emit TokenRedeemerAdded(redeemer);
    }

    /// @inheritdoc IGroveBasin
    function removeTokenRedeemer(address redeemer) external override onlyRole(MANAGER_ADMIN_ROLE) {
        if (!hasRole(REDEEMER_CONTRACT_ROLE, redeemer)) revert InvalidRedeemer();
        if (pendingRedemptions[redeemer] > 0)           revert PendingRedemptions();

        try ITokenRedeemer(redeemer).tearDown(address(this)) {} catch {}

        _revokeRole(REDEEMER_CONTRACT_ROLE, redeemer);

        emit TokenRedeemerRemoved(redeemer);
    }

    /// @inheritdoc IGroveBasin
    function setFeeClaimer(address newFeeClaimer) external override onlyRole(MANAGER_ADMIN_ROLE) {
        address oldFeeClaimer = feeClaimer;
        feeClaimer = newFeeClaimer;
        emit FeeClaimerSet(oldFeeClaimer, newFeeClaimer);
    }


    /**********************************************************************************************/
    /*** Owner functions                                                                        ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function setPurchaseFee(uint256 newPurchaseFee) external override onlyRole(OWNER_ROLE) {
        _setPurchaseFee(newPurchaseFee);
    }

    /// @inheritdoc IGroveBasin
    function setRedemptionFee(uint256 newRedemptionFee) external override onlyRole(OWNER_ROLE) {
        _setRedemptionFee(newRedemptionFee);
    }

    /**********************************************************************************************/
    /*** Redeemer functions                                                                     ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function initiateRedeem(address redeemer, uint256 creditTokenAmount) external override onlyRole(REDEEMER_ROLE) returns (bytes32 redeemRequestId) {
        _checkPaused(msg.sig);
        return _initiateRedeem(redeemer, creditTokenAmount);
    }

    /// @inheritdoc IGroveBasin
    function completeRedeem(bytes32 redeemRequestId) external override onlyRole(REDEEMER_ROLE) {
        _completeRedeem(redeemRequestId);
    }

    /**********************************************************************************************/
    /*** Manager functions                                                                      ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function setMaxSwapSize(uint256 newMaxSwapSize) external override onlyRole(MANAGER_ROLE) {
        if (newMaxSwapSize < maxSwapSizeLowerBound || newMaxSwapSize > maxSwapSizeUpperBound) revert SwapSizeOutOfBounds();

        uint256 oldMaxSwapSize = maxSwapSize;
        maxSwapSize            = newMaxSwapSize;
        emit MaxSwapSizeSet(oldMaxSwapSize, newMaxSwapSize);
    }

    /// @inheritdoc IGroveBasin
    function setStalenessThreshold(uint256 newThreshold)
        external override onlyRole(MANAGER_ROLE)
    {
        if (newThreshold < minStalenessThreshold || newThreshold > maxStalenessThreshold) revert ThresholdOutOfBounds();

        uint256 oldThreshold = stalenessThreshold;

        if (newThreshold == oldThreshold) revert SameThreshold();

        stalenessThreshold = newThreshold;
        emit StalenessThresholdSet(oldThreshold, newThreshold);
    }

    /**********************************************************************************************/
    /*** Pauser functions                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function setPaused(bytes4 key, bool state) external override onlyRole(PAUSER_ROLE) {
        paused[key] = state;
        emit PausedSet(key, state);
    }

    /**********************************************************************************************/
    /*** Fee calculation functions                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function calculatePurchaseFee(uint256 amount) external view override returns (uint256) {
        return _calculateFee(amount, purchaseFee);
    }

    /// @inheritdoc IGroveBasin
    function calculateRedemptionFee(uint256 amount) external view override returns (uint256) {
        return _calculateFee(amount, redemptionFee);
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    )
        external override returns (uint256 amountOut)
    {
        _checkPaused(msg.sig);
        _checkPaused(_getSwapPauseKey(assetIn, assetOut));
        if (amountIn == 0)          revert ZeroAmountIn();
        if (receiver == address(0)) revert ZeroReceiver();

        if (_getAssetValue(assetIn, amountIn, false) > maxSwapSize) revert SwapSizeExceeded();

        uint256 grossOut = _getSwapQuote(assetIn, assetOut, amountIn, false);
        uint256 fee      = previewSwapExactInFee(assetOut, grossOut);

        amountOut = grossOut - fee;

        if (amountOut < minAmountOut) revert AmountOutTooLow();

        _accrueFeeShares(assetOut, fee);

        _withdrawLiquidityInPocket(amountOut, assetOut);
        _pullAsset(assetIn, amountIn);
        _pushAsset(assetOut, receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    /// @inheritdoc IGroveBasin
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    )
        external override returns (uint256 amountIn)
    {
        _checkPaused(msg.sig);
        _checkPaused(_getSwapPauseKey(assetIn, assetOut));
        if (amountOut == 0)         revert ZeroAmountOut();
        if (receiver == address(0)) revert ZeroReceiver();

        uint256 fee = previewSwapExactOutFee(assetOut, amountOut);

        amountIn = _getSwapQuote(assetOut, assetIn, amountOut + fee, true);

        if (_getAssetValue(assetIn, amountIn, false) > maxSwapSize) revert SwapSizeExceeded();
        if (amountIn > maxAmountIn)                                 revert AmountInTooHigh();

        _accrueFeeShares(assetOut, fee);

        _withdrawLiquidityInPocket(amountOut, assetOut);
        _pullAsset(assetIn, amountIn);
        _pushAsset(assetOut, receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function depositInitial(address asset, uint256 assetsToDeposit)
        external override returns (uint256 newShares)
    {
        if (totalShares != 0)                                 revert AlreadySeeded();
        if (assetsToDeposit < 10 ** IERC20(asset).decimals()) revert InsufficientInitialDeposit();

        newShares = previewDeposit(asset, assetsToDeposit);

        if (newShares == 0) revert NoNewShares();

        shares[address(0)] += newShares;
        totalShares        += newShares;

        _pullAsset(asset, assetsToDeposit);
        _depositLiquidityInPocket(assetsToDeposit, asset);

        emit Deposit(asset, msg.sender, address(0), assetsToDeposit, newShares);
    }

    /// @inheritdoc IGroveBasin
    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external override returns (uint256 newShares)
    {
        _checkPaused(msg.sig);
        if (assetsToDeposit == 0)            revert ZeroAmount();
        if (msg.sender != liquidityProvider) revert NotLiquidityProvider();

        newShares = previewDeposit(asset, assetsToDeposit);

        if (newShares == 0) revert NoNewShares();

        shares[receiver] += newShares;
        totalShares      += newShares;

        _pullAsset(asset, assetsToDeposit);
        _depositLiquidityInPocket(assetsToDeposit, asset);

        emit Deposit(asset, msg.sender, receiver, assetsToDeposit, newShares);
    }

    /// @inheritdoc IGroveBasin
    function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
        external override returns (uint256 assetsWithdrawn)
    {
        if (maxAssetsToWithdraw == 0) revert ZeroAmount();

        uint256 sharesToBurn;

        ( sharesToBurn, assetsWithdrawn ) = previewWithdraw(asset, maxAssetsToWithdraw);

        // `previewWithdraw` ensures that `sharesToBurn` <= `shares[msg.sender]`
        unchecked {
            shares[msg.sender] -= sharesToBurn;
            totalShares        -= sharesToBurn;
        }

        _withdrawLiquidityInPocket(assetsWithdrawn, asset);
        _pushAsset(asset, receiver, assetsWithdrawn);

        emit Withdraw(asset, msg.sender, receiver, assetsWithdrawn, sharesToBurn);
    }

    /**********************************************************************************************/
    /*** Deposit/withdraw preview functions                                                     ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function previewDeposit(address asset, uint256 assetsToDeposit)
        public view override returns (uint256)
    {
        if (asset == creditToken) _checkPaused(PAUSED_DEPOSIT_CREDIT);

        // Convert amount to 1e18 precision denominated in value of USD then convert to shares.
        // NOTE: Don't need to check valid asset here since `_getAssetValue` will revert if invalid
        return convertToShares(_getAssetValue(asset, assetsToDeposit, false));  // Round down
    }

    /// @inheritdoc IGroveBasin
    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
    {
        _requireValidAsset(asset);
        uint256 assetBalance = _getAvailableBalance(asset);

        assetsWithdrawn = assetBalance < maxAssetsToWithdraw
            ? assetBalance
            : maxAssetsToWithdraw;

        // Get shares to burn, rounding up for both calculations
        // NOTE: Don't need to check valid asset here since `_getAssetValue` will revert if invalid
        sharesToBurn = _convertToSharesRoundUp(_getAssetValue(asset, assetsWithdrawn, true));

        uint256 userShares = shares[msg.sender];

        if (sharesToBurn > userShares) {
            assetsWithdrawn = convertToAssets(asset, userShares);
            sharesToBurn    = userShares;
        }
    }

    /**********************************************************************************************/
    /*** Swap preview functions                                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function previewSwapExactIn(address assetIn, address assetOut, uint256 amountIn)
        public view override returns (uint256 amountOut)
    {
        if (_getAssetValue(assetIn, amountIn, false) > maxSwapSize) revert SwapSizeExceeded();

        amountOut = _getSwapQuote(assetIn, assetOut, amountIn, false);
        amountOut -= previewSwapExactInFee(assetOut, amountOut);
    }

    /// @inheritdoc IGroveBasin
    function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
        public view override returns (uint256 amountIn)
    {
        amountOut += previewSwapExactOutFee(assetOut, amountOut);
        amountIn   = _getSwapQuote(assetOut, assetIn, amountOut, true);

        if (_getAssetValue(assetIn, amountIn, false) > maxSwapSize) revert SwapSizeExceeded();
    }
    
    /// @dev Returns the fee that will be deducted from a gross output amount (ExactIn). Rounds up.
    function previewSwapExactInFee(address assetOut, uint256 amountOut)
        public view returns (uint256)
    {
        if (assetOut == creditToken) {
            return _calculateFee(amountOut, purchaseFee);
        }
        return _calculateFee(amountOut, redemptionFee);
    }

    /// @dev Returns the fee that must be added to a net output amount to get the gross output (ExactOut). Rounds up.
    function previewSwapExactOutFee(address assetOut, uint256 amountOut)
        public view returns (uint256)
    {
        if (assetOut == creditToken) {
            return _getGrossAmountFromNet(amountOut, purchaseFee) - amountOut;
        }
        return _getGrossAmountFromNet(amountOut, redemptionFee) - amountOut;
    }

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function convertToAssets(address asset, uint256 numShares)
        public view override returns (uint256)
    {
        _requireValidAsset(asset);

        uint256 assetValue = convertToAssetValue(numShares);

        ( uint256 rate, uint256 ratePrecision, uint256 tokenPrecision ) =
            _getTokenRateAndPrecision(asset);

        return Math.mulDiv(
            assetValue * tokenPrecision,
            ratePrecision,
            rate * 1e18
        );
    }

    /// @inheritdoc IGroveBasin
    function convertToAssetValue(uint256 numShares) public view override returns (uint256) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ != 0) {
            return numShares * totalAssets() / totalShares_;
        }
        return numShares;
    }

    /// @inheritdoc IGroveBasin
    function convertToShares(uint256 assetValue) public view override returns (uint256) {
        uint256 totalAssets_ = totalAssets();
        if (totalAssets_ != 0) {
            return assetValue * totalShares / totalAssets_;
        }
        return assetValue;
    }

    /// @inheritdoc IGroveBasin
    function convertToShares(address asset, uint256 assets) public view override returns (uint256) {
        return convertToShares(_getAssetValue(asset, assets, false));  // Round down
    }

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    /// @dev pendingCreditTokenBalance is an estimate of the value that Basin is due to receive, not a firm amount.
    function totalAssets() public view override returns (uint256) {
        return _getAssetValue(
                    swapToken, _getAvailableBalance(swapToken), false  // Round down
                )
            +  _getAssetValue(
                    collateralToken, _getAvailableBalance(collateralToken), false  // Round down
                )
            +  _getAssetValue(
                    creditToken,
                    _getAvailableBalance(address(creditToken)) + pendingCreditTokenBalance,
                    false // Round down
                );
    }

    /**********************************************************************************************/
    /*** AccessControl overrides                                                                ***/
    /**********************************************************************************************/

    /// @dev Extends revokeRole to allow PAUSER_ROLE holders to revoke MANAGER_ROLE and REDEEMER_ROLE.
    function revokeRole(bytes32 role, address account) public override {
        if (
            (role == MANAGER_ROLE || role == REDEEMER_ROLE) &&
            hasRole(PAUSER_ROLE, msg.sender)
        ) {
            _revokeRole(role, account);
            return;
        }
        super.revokeRole(role, account);
    }

    /**********************************************************************************************/
    /*** Internal valuation functions (deposit/withdraw)                                        ***/
    /**********************************************************************************************/

    /// @dev Returns the USD value of `amount` of `asset` in 1e18 precision.
    function _getAssetValue(address asset, uint256 amount, bool roundUp) internal view returns (uint256) {
        _requireValidAsset(asset);

        ( uint256 rate, uint256 ratePrecision, uint256 tokenPrecision ) =
            _getTokenRateAndPrecision(asset);
        
        return Math.mulDiv(
            amount * rate,
            1e18,
            ratePrecision * tokenPrecision,
            roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor
        );
    }

    /**********************************************************************************************/
    /*** Internal preview functions (swaps)                                                     ***/
    /**********************************************************************************************/

    /// @dev Returns the conversion rate, rate precision, and token precision for a supported asset.
    function _getTokenRateAndPrecision(address token)
        internal view returns (uint256 rate, uint256 ratePrecision, uint256 tokenPrecision)
    {
        if (token == swapToken) {
            return (
                _getConversionRate(swapTokenRateProvider),
                IGroveRateProvider(swapTokenRateProvider).getRatePrecision(),
                _swapTokenPrecision
            );
        }
        if (token == collateralToken) {
            return (
                _getConversionRate(collateralTokenRateProvider),
                IGroveRateProvider(collateralTokenRateProvider).getRatePrecision(),
                _collateralTokenPrecision
            );
        }
        return (
            _getConversionRate(creditTokenRateProvider),
            IGroveRateProvider(creditTokenRateProvider).getRatePrecision(),
            _creditTokenPrecision
        );
    }

    /// @dev Converts `amount` of tokenIn to tokenOut using their rates and precisions.
    ///      Consolidates the four precision values (all powers of 10) into a single net scalar
    ///      applied to either the numerator or denominator, keeping a single mulDiv call.
    ///      
    ///      result =  amount * rateIn  * tokenPrecisionOut * ratePrecisionOut
    ///               --------------------------------------------------------
    ///                         rateOut * tokenPrecisionIn  * ratePrecisionIn
    function _convert(
        uint256 amount,
        uint256 rateIn,
        uint256 ratePrecisionIn,
        uint256 tokenPrecisionIn,
        uint256 rateOut,
        uint256 ratePrecisionOut,
        uint256 tokenPrecisionOut,
        bool    roundUp
    )
        internal pure returns (uint256)
    {
        uint256 numeratorPrecision   = tokenPrecisionOut * ratePrecisionOut;
        uint256 denominatorPrecision = tokenPrecisionIn  * ratePrecisionIn;

        if (numeratorPrecision >= denominatorPrecision) {
            uint256 scalar = numeratorPrecision / denominatorPrecision;

            if (!roundUp) return Math.mulDiv(amount, rateIn * scalar, rateOut);

            return Math.mulDiv(amount, rateIn * scalar, rateOut, Math.Rounding.Ceil);
        }

        uint256 scalar = denominatorPrecision / numeratorPrecision;

        if (!roundUp) return Math.mulDiv(
            amount,
            rateIn,
            rateOut * scalar
        );

        return Math.mulDiv(
            amount,
            rateIn,
            rateOut * scalar,
            Math.Rounding.Ceil
        );
    }

    /// @dev Converts `amount` of `asset` into `quoteAsset` terms using rate providers.
    function _getSwapQuote(address asset, address quoteAsset, uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        _requireValidAsset(asset);
        _requireValidAsset(quoteAsset);

        if (asset == quoteAsset)                                       revert InvalidAsset();
        if (asset == swapToken       && quoteAsset == collateralToken) revert InvalidSwap();
        if (asset == collateralToken && quoteAsset == swapToken)       revert InvalidSwap();

        (uint256 rateIn,  uint256 ratePrecisionIn,  uint256 tokenPrecisionIn)  = _getTokenRateAndPrecision(asset);
        (uint256 rateOut, uint256 ratePrecisionOut, uint256 tokenPrecisionOut) = _getTokenRateAndPrecision(quoteAsset);

        return _convert(
            amount,
            rateIn,  ratePrecisionIn,  tokenPrecisionIn,
            rateOut, ratePrecisionOut, tokenPrecisionOut,
            roundUp
        );
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    /// @dev Converts a fee amount in `asset` terms to shares and assigns them to the fee claimer.
    function _accrueFeeShares(address asset, uint256 feeAmount) internal {
        if (feeAmount == 0) return;

        address feeClaimer_ = feeClaimer;
        if (feeClaimer_ == address(0)) return;

        uint256 feeValue  = _getAssetValue(asset, feeAmount, true);
        uint256 feeShares = _convertToSharesRoundUp(feeValue);

        if (feeShares == 0) return;

        shares[feeClaimer_] += feeShares;
        totalShares         += feeShares;

        emit FeeSharesAccrued(feeClaimer_, feeShares);
    }

    /// @dev Converts asset value to shares, rounding up. Used for withdrawal share calculations.
    function _convertToSharesRoundUp(uint256 assetValue) internal view returns (uint256) {
        uint256 totalValue = totalAssets();
        if (totalValue != 0) {
            return Math.ceilDiv(assetValue * totalShares, totalValue);
        }
        return assetValue;
    }

    /// @dev Fetches the conversion rate from a rate provider and reverts if stale.
    function _getConversionRate(address rateProvider) internal view returns (uint256 rate) {
        uint256 lastUpdated;
        (rate, lastUpdated) = IGroveRateProvider(rateProvider).getConversionRateWithAge();

        if (block.timestamp - lastUpdated > stalenessThreshold) revert StaleRate();
    }

    /**
     * @dev Withdraws liquidity from the pocket if one is configured. For swap tokens, tokens
     *      remain in the pocket after withdraw since `_pushAsset` uses `transferFrom`. For
     *      collateral tokens, the deficit is pulled back to Basin.
     */
    function _withdrawLiquidityInPocket(uint256 amount, address asset) internal {
        if (!_hasPocket()) return;

        if (asset == swapToken) {
            IGroveBasinPocket(pocket).withdrawLiquidity(amount, asset);
        } else if (asset == collateralToken) {
            uint256 basinBalance = IERC20(asset).balanceOf(address(this));

            if (basinBalance < amount) {
                uint256 deficit = amount - basinBalance;
                uint256 drawn = IGroveBasinPocket(pocket).withdrawLiquidity(deficit, asset);
                IERC20(asset).safeTransferFrom(pocket, address(this), drawn);
            }
        }
    }

    /// @dev Deposits swap token liquidity into the pocket if one is configured.
    ///      Wrapped in try-catch so that if the pocket's deposit fails, the tokens
    ///      remain in the pocket for the manager to deposit at a later time.
    function _depositLiquidityInPocket(uint256 amount, address asset) internal {
        if (asset == swapToken && _hasPocket()) {
            try IGroveBasinPocket(pocket).depositLiquidity(amount, asset) {}
            catch {
                emit DepositLiquidityFailed(pocket, asset, amount);
            }
        }
    }

    /// @dev Returns the available balance of `asset`, querying the pocket for swap tokens.
    function _getAvailableBalance(address asset) internal view returns (uint256) {
        if (asset == swapToken && _hasPocket()) {
            return IGroveBasinPocket(pocket).availableBalance(asset);
        }

        return IERC20(asset).balanceOf(_getAssetCustodian(asset));
    }

    /// @dev Returns true if an external pocket is configured (i.e., pocket != address(this)).
    function _hasPocket() internal view returns (bool) {
        return pocket != address(this);
    }

    /// @dev Reverts if `asset` is not one of the three supported tokens.
    function _requireValidAsset(address asset) internal view {
        if (asset != swapToken && asset != collateralToken && asset != creditToken) revert InvalidAsset();
    }

    /// @dev Reverts if the global pause or the given key is active.
    function _checkPaused(bytes4 key) internal view {
        if (paused[bytes4(0)] || paused[key]) revert Paused();
    }

    /// @dev Returns the direction-specific pause key for a swap, or bytes4(0) if none applies.
    function _getSwapPauseKey(address assetIn, address assetOut) internal view returns (bytes4) {
        if (assetIn == creditToken) {
            if (assetOut == collateralToken) return PAUSED_SWAP_CREDIT_TO_COLLATERAL;
            if (assetOut == swapToken)       return PAUSED_SWAP_CREDIT_TO_SWAP;
        } else if (assetOut == creditToken) {
            if (assetIn == collateralToken) return PAUSED_SWAP_COLLATERAL_TO_CREDIT;
            if (assetIn == swapToken)       return PAUSED_SWAP_SWAP_TO_CREDIT;
        }
        return bytes4(0);
    }

    /// @dev Returns the address holding custody of `asset` (pocket for swap tokens, Basin otherwise).
    function _getAssetCustodian(address asset) internal view returns (address custodian) {
        custodian = asset == swapToken ? pocket : address(this);
    }

    /// @dev Transfers `amount` of `asset` from `msg.sender` to the asset's custodian.
    function _pullAsset(address asset, uint256 amount) internal {
        IERC20(asset).safeTransferFrom(msg.sender, _getAssetCustodian(asset), amount);
    }

    /// @dev Transfers `amount` of `asset` to `receiver`, pulling from pocket if needed.
    function _pushAsset(address asset, address receiver, uint256 amount) internal {
        if (asset == swapToken && _hasPocket()) {
            IERC20(asset).safeTransferFrom(pocket, receiver, amount);
        } else {
            IERC20(asset).safeTransfer(receiver, amount);
        }
    }

    /// @dev Approves and sends credit tokens to the redeemer to initiate an async redemption.
    function _initiateRedeem(address redeemer, uint256 creditTokenAmount) internal returns (bytes32 redeemRequestId) {
        if (!hasRole(REDEEMER_CONTRACT_ROLE, redeemer)) revert InvalidRedeemer();

        uint256 collateralTokenAmount = _getSwapQuote(creditToken, collateralToken, creditTokenAmount, false);

        RedeemRequest memory request = RedeemRequest({
            blockNumber          : block.number,
            redeemer             : redeemer,
            creditTokenAmount    : creditTokenAmount,
            collateralTokenAmount: collateralTokenAmount
        });

        redeemRequestId = keccak256(abi.encode(request));
        if (redeemRequests[redeemRequestId].creditTokenAmount != 0) revert RequestAlreadyExists();

        redeemRequests[redeemRequestId]  = request;
        pendingCreditTokenBalance       += creditTokenAmount;
        pendingRedemptions[redeemer]++;

        IERC20(creditToken).safeApprove(redeemer, creditTokenAmount);
        ITokenRedeemer(redeemer).initiateRedeem(creditTokenAmount);
        IERC20(creditToken).safeApprove(redeemer, 0);

        emit RedeemInitiated(redeemer, msg.sender, creditTokenAmount);
    }

    /// @dev Completes an async redemption, decreasing the pending credit token balance.
    function _completeRedeem(bytes32 redeemRequestId) internal {
        RedeemRequest memory request = redeemRequests[redeemRequestId];
        if (request.creditTokenAmount == 0) revert InvalidRedeemRequest();
        if (!hasRole(REDEEMER_CONTRACT_ROLE, request.redeemer)) revert InvalidRedeemer();

        delete redeemRequests[redeemRequestId];
        pendingCreditTokenBalance -= request.creditTokenAmount;
        pendingRedemptions[request.redeemer]--;

        uint256 collateralTokenReturned = ITokenRedeemer(request.redeemer).completeRedeem(request);

        emit RedeemCompleted(request.redeemer, msg.sender, collateralTokenReturned);
    }

    /// @dev Calculates a fee on `amount` in basis points.
    function _calculateFee(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return Math.ceilDiv(amount * fee, BPS);
    }

    /// @dev Computes the gross amount before fee that yields `netAmount` after fee deduction.
    ///      Inverse of: netAmount = grossAmount - grossAmount * fee / BPS
    function _getGrossAmountFromNet(uint256 netAmount, uint256 fee) internal pure returns (uint256) {
        if (fee == 0) return netAmount;
        return Math.ceilDiv(netAmount * BPS, BPS - fee);
    }

    /// @dev Sets the purchase fee, enforcing it is within [minFee, maxFee].
    function _setPurchaseFee(uint256 newPurchaseFee) internal {
        if (newPurchaseFee < minFee || newPurchaseFee > maxFee) revert PurchaseFeeOutOfBounds();

        uint256 oldPurchaseFee = purchaseFee;
        purchaseFee = newPurchaseFee;

        emit PurchaseFeeSet(oldPurchaseFee, newPurchaseFee);
    }

    /// @dev Sets the redemption fee, enforcing it is within [minFee, maxFee].
    function _setRedemptionFee(uint256 newRedemptionFee) internal {
        if (newRedemptionFee < minFee || newRedemptionFee > maxFee) revert RedemptionFeeOutOfBounds();

        uint256 oldRedemptionFee = redemptionFee;
        redemptionFee = newRedemptionFee;

        emit RedemptionFeeSet(oldRedemptionFee, newRedemptionFee);
    }
}
