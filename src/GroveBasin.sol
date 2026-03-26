// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { AccessControlDefaultAdminRules } from "openzeppelin-contracts/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { Math }                           from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IGroveBasin }             from "src/interfaces/IGroveBasin.sol";
import { IGroveBasinPocket }       from "src/interfaces/IGroveBasinPocket.sol";
import { IRateProviderLike }       from "src/interfaces/IRateProviderLike.sol";
import { ITokenRedeemer }          from "src/interfaces/ITokenRedeemer.sol";

/**
 * @title  GroveBasin
 * @notice Multi-asset liquidity pool that facilitates swaps between a swap token, collateral
 *         token, and a yield-bearing credit token. Liquidity providers deposit assets in exchange
 *         for shares that represent pro-rata ownership of the pool's total value.
 * @dev    Uses AccessControlDefaultAdminRules for role-based permissioning across owner, manager
 *         admin, manager, liquidity provider, and redeemer roles. Asset values are determined by
 *         external rate providers that return conversion rates in 1e27 precision. Swap token
 *         custody can be delegated to a pocket contract for yield generation.
 */
contract GroveBasin is IGroveBasin, AccessControlDefaultAdminRules {

    using SafeERC20 for IERC20;

    uint256 public constant override BPS = 100_00;

    bytes32 public constant override OWNER_ROLE              = DEFAULT_ADMIN_ROLE;
    bytes32 public constant override MANAGER_ADMIN_ROLE      = keccak256("MANAGER_ADMIN_ROLE");
    bytes32 public constant override MANAGER_ROLE            = keccak256("MANAGER_ROLE");
    bytes32 public constant override REDEEMER_ROLE           = keccak256("REDEEMER_ROLE");
    bytes32 public constant override REDEEMER_CONTRACT_ROLE  = keccak256("REDEEMER_CONTRACT_ROLE");

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

    bool public override creditTokenDepositsDisabled;
    bool public override pausedSwapToCredit;
    bool public override pausedCreditToSwap;
    bool public override pausedCollateralToCredit;
    bool public override pausedCreditToCollateral;
    bool public override pausedDeposits;
    bool public override pausedInitiateRedeem;

    uint256 public override stalenessThreshold;
    uint256 public override totalShares;
    uint256 public override maxSwapSize;
    uint256 public override maxSwapSizeLowerBound;
    uint256 public override maxSwapSizeUpperBound;

    uint256 public override purchaseFee;
    uint256 public override redemptionFee;
    uint256 public override minFee;
    uint256 public override maxFee;

    uint256 public override minStalenessThreshold;
    uint256 public override maxStalenessThreshold;
    uint256 public override redeemedCreditTokenBalance;

    mapping(address user => uint256 shares) public override shares;

    constructor(
        address owner_,
        address liquidityProvider_,
        address swapToken_,
        address collateralToken_,
        address creditToken_,
        address swapTokenRateProvider_,
        address collateralTokenRateProvider_,
        address creditTokenRateProvider_
    ) AccessControlDefaultAdminRules(0, owner_) {
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
            IRateProviderLike(swapTokenRateProvider_).getConversionRate()       == 0 ||
            IRateProviderLike(collateralTokenRateProvider_).getConversionRate() == 0 ||
            IRateProviderLike(creditTokenRateProvider_).getConversionRate()     == 0
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
        maxStalenessThreshold = 48 hours;
        stalenessThreshold    = minStalenessThreshold;

        _setRoleAdmin(MANAGER_ROLE,           MANAGER_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_CONTRACT_ROLE, MANAGER_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_ROLE,          MANAGER_ADMIN_ROLE);
    }

    /**********************************************************************************************/
    /*** Manager admin functions                                                                ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function setCreditTokenDepositsDisabled(bool disabled) external override onlyRole(MANAGER_ADMIN_ROLE) {
        creditTokenDepositsDisabled = disabled;
        emit CreditTokenDepositsDisabledSet(disabled);
    }

    /// @inheritdoc IGroveBasin
    function setRateProvider(address token, address newRateProvider) external override onlyRole(MANAGER_ADMIN_ROLE) {
        if (newRateProvider == address(0))                               revert InvalidRateProvider();
        if (IRateProviderLike(newRateProvider).getConversionRate() == 0) revert RateProviderReturnsZero();

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
        if (newMaxFee > BPS)       revert MaxFeeExceedsBps();

        uint256 oldMinFee = minFee;
        uint256 oldMaxFee = maxFee;

        minFee = newMinFee;
        maxFee = newMaxFee;

        emit FeeBoundsSet(oldMinFee, oldMaxFee, newMinFee, newMaxFee);

        uint256 purchaseFee_ = purchaseFee;
        if (purchaseFee_ < newMinFee) {
            _setPurchaseFee(newMinFee);
        } else if (purchaseFee_ > newMaxFee) {
            _setPurchaseFee(newMaxFee);
        }

        uint256 redemptionFee_ = redemptionFee;
        if (redemptionFee_ < newMinFee) {
            _setRedemptionFee(newMinFee);
        } else if (redemptionFee_ > newMaxFee) {
            _setRedemptionFee(newMaxFee);
        }
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

        try ITokenRedeemer(redeemer).tearDown(address(this)) {} catch {}

        _revokeRole(REDEEMER_CONTRACT_ROLE, redeemer);

        emit TokenRedeemerRemoved(redeemer);
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
    /*** Redeemer functions                                                                        ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function initiateRedeem(address redeemer, uint256 creditTokenAmount) external override onlyRole(REDEEMER_ROLE) {
        _initiateRedeem(redeemer, creditTokenAmount);
    }

    /// @inheritdoc IGroveBasin
    function completeRedeem(address redeemer, uint256 creditTokenAmount) external override onlyRole(REDEEMER_ROLE) {
        _completeRedeem(redeemer, creditTokenAmount);
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
    function setPaused(bytes32 action, bool paused)
        external override onlyRole(MANAGER_ROLE)
    {
        if      (action == "swapToCredit")        pausedSwapToCredit        = paused;
        else if (action == "creditToSwap")        pausedCreditToSwap        = paused;
        else if (action == "collateralToCredit")  pausedCollateralToCredit  = paused;
        else if (action == "creditToCollateral")  pausedCreditToCollateral  = paused;
        else if (action == "deposits")            pausedDeposits            = paused;
        else if (action == "initiateRedeem")      pausedInitiateRedeem      = paused;
        else                                      revert InvalidAction();

        emit PausedSet(action, paused);
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
    /*** Fee calculation functions                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function calculatePurchaseFee(uint256 amount, bool roundUp) external view override returns (uint256) {
        return _calculateFee(amount, purchaseFee, roundUp);
    }

    /// @inheritdoc IGroveBasin
    function calculateRedemptionFee(uint256 amount, bool roundUp) external view override returns (uint256) {
        return _calculateFee(amount, redemptionFee, roundUp);
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
        if (amountIn == 0)          revert ZeroAmountIn();
        if (receiver == address(0)) revert ZeroReceiver();

        _checkSwapNotPaused(assetIn, assetOut);

        amountOut = previewSwapExactIn(assetIn, assetOut, amountIn);

        if (amountOut < minAmountOut) revert AmountOutTooLow();

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
        if (amountOut == 0)         revert ZeroAmountOut();
        if (receiver == address(0)) revert ZeroReceiver();

        _checkSwapNotPaused(assetIn, assetOut);

        amountIn = previewSwapExactOut(assetIn, assetOut, amountOut);

        if (amountIn > maxAmountIn) revert AmountInTooHigh();

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
        if (totalShares != 0)     revert AlreadySeeded();
        if (assetsToDeposit == 0) revert ZeroAmount();

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
        if (pausedDeposits)                  revert DepositsPaused();
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
        if (asset == creditToken && creditTokenDepositsDisabled) revert CreditDepositsDisabled();

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

        // Round down to get amountOut
        amountOut = _getSwapQuote(assetIn, assetOut, amountIn, false);

        // Assumes no stable-to-stable swap
        if (assetOut == creditToken) {
            amountOut -= _calculateFee(amountOut, purchaseFee, false);
        } else {
            amountOut -= _calculateFee(amountOut, redemptionFee, false);
        }
    }

    /// @inheritdoc IGroveBasin
    function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
        public view override returns (uint256 amountIn)
    {
        // Round up to get amountIn
        amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);

        if (_getAssetValue(assetIn, amountIn, false) > maxSwapSize) revert SwapSizeExceeded();

        // Assumes no stable-to-stable swap
        if (assetOut == creditToken) {
            amountIn += _calculateFee(amountIn, purchaseFee, true);
        } else {
            amountIn += _calculateFee(amountIn, redemptionFee, true);
        }
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

        if (asset == swapToken) {
            return assetValue
                * 1e9
                * _swapTokenPrecision
                / _getConversionRate(swapTokenRateProvider);
        }
        else if (asset == collateralToken) {
            // assetValue is in 1e18, rate is 1e27, precision is native decimals
            // amount = assetValue * 1e27 / rate * precision / 1e18 = assetValue * 1e9 * precision / rate
            return assetValue
                * 1e9
                * _collateralTokenPrecision
                / _getConversionRate(collateralTokenRateProvider);
        }

        return assetValue
            * 1e9
            * _creditTokenPrecision
            / _getConversionRate(creditTokenRateProvider);
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
    function totalAssets() public view override returns (uint256) {
        return _getSwapTokenValue(
                    _getAvailableBalance(swapToken)
                )
            +  _getCollateralTokenValue(
                    _getAvailableBalance(collateralToken)
                )
            +  _getCreditTokenValue(
                    _getAvailableBalance(creditToken), false // Round down
                );
    }

    /// @inheritdoc IGroveBasin
    function totalAssetsWithRedemptions() public view returns (uint256) {
        return totalAssets() + _getCreditTokenValue(redeemedCreditTokenBalance, false);
    }

    /**********************************************************************************************/
    /*** Internal valuation functions (deposit/withdraw)                                        ***/
    /**********************************************************************************************/

    /// @dev Returns the USD value of `amount` of `asset` in 1e18 precision.
    function _getAssetValue(address asset, uint256 amount, bool roundUp) internal view returns (uint256) {
        if      (asset == swapToken)       return _getSwapTokenValue(amount);
        else if (asset == collateralToken) return _getCollateralTokenValue(amount);
        else if (asset == creditToken)     return _getCreditTokenValue(amount, roundUp);
        else                               revert InvalidAsset();
    }

    /// @dev Returns the USD value of `amount` of swap tokens in 1e18 precision.
    function _getSwapTokenValue(uint256 amount) internal view returns (uint256) {
        return Math.mulDiv(
            amount * _getConversionRate(swapTokenRateProvider),
            1e18,
            IRateProviderLike(swapTokenRateProvider).getRatePrecision() * _swapTokenPrecision
        );
    }

    /// @dev Returns the USD value of `amount` of collateral tokens in 1e18 precision.
    function _getCollateralTokenValue(uint256 amount) internal view returns (uint256) {
        return Math.mulDiv(
            amount * _getConversionRate(collateralTokenRateProvider),
            1e18,
            IRateProviderLike(collateralTokenRateProvider).getRatePrecision() * _collateralTokenPrecision
        );
    }

    /// @dev Returns the USD value of `amount` of credit tokens in 1e18 precision.
    function _getCreditTokenValue(uint256 amount, bool roundUp) internal view returns (uint256) {
        uint256 rate      = _getConversionRate(creditTokenRateProvider);
        uint256 precision = IRateProviderLike(creditTokenRateProvider).getRatePrecision();

        return Math.mulDiv(
            amount * rate,
            1e18,
            precision * _creditTokenPrecision,
            roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor
        );
    }

    /**********************************************************************************************/
    /*** Internal preview functions (swaps)                                                     ***/
    /**********************************************************************************************/

    /// @dev Converts `amount` of `asset` into `quoteAsset` terms using rate providers.
    function _getSwapQuote(address asset, address quoteAsset, uint256 amount, bool roundUp)
        internal view returns (uint256 quoteAmount)
    {
        if (asset == swapToken) {
            if      (quoteAsset == collateralToken) revert InvalidSwap();
            else if (quoteAsset == creditToken)     return _convertSwapToCreditToken(amount, roundUp);
        }

        else if (asset == collateralToken) {
            if      (quoteAsset == swapToken)      revert InvalidSwap();
            else if (quoteAsset == creditToken)    return _convertCollateralToCreditToken(amount, roundUp);
        }

        else if (asset == creditToken) {
            if      (quoteAsset == swapToken)       return _convertCreditTokenToSwap(amount, roundUp);
            else if (quoteAsset == collateralToken) return _convertCreditTokenToCollateral(amount, roundUp);
        }

        revert InvalidAsset();
    }

    /// @dev Converts swap token amount to equivalent credit token amount.
    function _convertSwapToCreditToken(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        uint256 swapRate   = _getConversionRate(swapTokenRateProvider);
        uint256 creditRate = _getConversionRate(creditTokenRateProvider);

        if (!roundUp) {
            return Math.mulDiv(amount, swapRate * _creditTokenPrecision, creditRate * _swapTokenPrecision);
        }

        return Math.ceilDiv(
            Math.ceilDiv(amount * swapRate, creditRate) * _creditTokenPrecision,
            _swapTokenPrecision
        );
    }

    /// @dev Converts credit token amount to equivalent swap token amount.
    function _convertCreditTokenToSwap(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        uint256 swapRate   = _getConversionRate(swapTokenRateProvider);
        uint256 creditRate = _getConversionRate(creditTokenRateProvider);

        if (!roundUp) {
            return Math.mulDiv(amount, creditRate * _swapTokenPrecision, swapRate * _creditTokenPrecision);
        }

        return Math.ceilDiv(
            Math.ceilDiv(amount * creditRate, swapRate) * _swapTokenPrecision,
            _creditTokenPrecision
        );
    }

    /// @dev Converts collateral token amount to equivalent credit token amount.
    function _convertCollateralToCreditToken(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        // collateral -> USD value -> credit
        // USD value = amount * collateralRate / 1e9 / collateralPrecision (in 1e18)
        // credit = USD value * 1e27 / creditRate * creditPrecision / 1e18
        //        = amount * collateralRate / creditRate * creditPrecision / collateralPrecision
        uint256 collateralRate = _getConversionRate(collateralTokenRateProvider);
        uint256 creditRate     = _getConversionRate(creditTokenRateProvider);

        if (!roundUp) {
            return Math.mulDiv(amount, collateralRate * _creditTokenPrecision, creditRate * _collateralTokenPrecision);
        }

        return Math.ceilDiv(
            Math.ceilDiv(amount * collateralRate, creditRate) * _creditTokenPrecision,
            _collateralTokenPrecision
        );
    }

    /// @dev Converts credit token amount to equivalent collateral token amount.
    function _convertCreditTokenToCollateral(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        // credit -> USD value -> collateral
        // USD value = amount * creditRate / 1e9 / creditPrecision (in 1e18)
        // collateral = USD value * 1e27 / collateralRate * collateralPrecision / 1e18
        //            = amount * creditRate / collateralRate * collateralPrecision / creditPrecision
        uint256 collateralRate = _getConversionRate(collateralTokenRateProvider);
        uint256 creditRate     = _getConversionRate(creditTokenRateProvider);

        if (!roundUp) {
            return Math.mulDiv(amount, creditRate * _collateralTokenPrecision, collateralRate * _creditTokenPrecision);
        }

        return Math.ceilDiv(
            Math.ceilDiv(amount * creditRate, collateralRate) * _collateralTokenPrecision,
            _creditTokenPrecision
        );
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

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
        (rate, lastUpdated) = IRateProviderLike(rateProvider).getConversionRateWithAge();

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
    function _depositLiquidityInPocket(uint256 amount, address asset) internal {
        if (asset == swapToken && _hasPocket()) {
            IGroveBasinPocket(pocket).depositLiquidity(amount, asset);
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

    /// @dev Reverts if the swap direction from `assetIn` to `assetOut` is paused.
    function _checkSwapNotPaused(address assetIn, address assetOut) internal view {
        if (assetIn == swapToken && assetOut == creditToken) {
            if (pausedSwapToCredit) revert RoutePaused();
        } else if (assetIn == creditToken && assetOut == swapToken) {
            if (pausedCreditToSwap) revert RoutePaused();
        } else if (assetIn == collateralToken && assetOut == creditToken) {
            if (pausedCollateralToCredit) revert RoutePaused();
        } else if (assetIn == creditToken && assetOut == collateralToken) {
            if (pausedCreditToCollateral) revert RoutePaused();
        }
    }

    /// @dev Reverts if `asset` is not one of the three supported tokens.
    function _requireValidAsset(address asset) internal view {
        if (asset != swapToken && asset != collateralToken && asset != creditToken) revert InvalidAsset();
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
    function _initiateRedeem(address redeemer, uint256 creditTokenAmount) internal {
        if (pausedInitiateRedeem)                       revert InitiateRedeemPaused();
        if (!hasRole(REDEEMER_CONTRACT_ROLE, redeemer)) revert InvalidRedeemer();

        IERC20(creditToken).approve(redeemer, creditTokenAmount);
        ITokenRedeemer(redeemer).initiateRedeem(creditTokenAmount);
        IERC20(creditToken).approve(redeemer, 0);

        redeemedCreditTokenBalance += creditTokenAmount;
        emit RedeemInitiated(redeemer, msg.sender, creditTokenAmount);
    }

    /// @dev Completes an async redemption, decreasing the tracked credit token balance.
    function _completeRedeem(address redeemer, uint256 creditTokenAmount) internal {
        if (!hasRole(REDEEMER_CONTRACT_ROLE, redeemer)) revert InvalidRedeemer();

        redeemedCreditTokenBalance = creditTokenAmount > redeemedCreditTokenBalance ? 0 : redeemedCreditTokenBalance - creditTokenAmount;

        emit RedeemCompleted(redeemer, msg.sender, creditTokenAmount);
        
        ITokenRedeemer(redeemer).completeRedeem(creditTokenAmount);
    }

    /// @dev Calculates a fee on `amount` in basis points.
    function _calculateFee(uint256 amount, uint256 fee, bool roundUp) internal pure returns (uint256) {
        if (roundUp) return Math.ceilDiv(amount * fee, BPS);
        return amount * fee / BPS;
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
