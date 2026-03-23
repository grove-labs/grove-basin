// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Math }          from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IGroveBasin }             from "src/interfaces/IGroveBasin.sol";
import { IGroveBasinPocket }       from "src/interfaces/IGroveBasinPocket.sol";
import { IRateProviderLike }       from "src/interfaces/IRateProviderLike.sol";
import { ITokenRedeemer }          from "src/interfaces/ITokenRedeemer.sol";

/**
 * @title  GroveBasin
 * @notice Multi-asset liquidity pool that facilitates swaps between a swap token, collateral
 *         token, and a yield-bearing credit token. Liquidity providers deposit assets in exchange
 *         for shares that represent pro-rata ownership of the pool's total value.
 * @dev    Uses AccessControl for role-based permissioning across owner, manager admin, manager,
 *         liquidity provider, and redeemer roles. Asset values are determined by external rate
 *         providers that return conversion rates in 1e27 precision. Swap token custody can be
 *         delegated to a pocket contract for yield generation.
 */
contract GroveBasin is IGroveBasin, AccessControl {

    using SafeERC20 for IERC20;

    uint256 public constant override BPS = 100_00;

    bytes32 public constant override OWNER_ROLE              = DEFAULT_ADMIN_ROLE;
    bytes32 public constant override MANAGER_ADMIN_ROLE      = keccak256("MANAGER_ADMIN_ROLE");
    bytes32 public constant override MANAGER_ROLE            = keccak256("MANAGER_ROLE");
    bytes32 public constant override LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");
    bytes32 public constant override REDEEMER_ROLE           = keccak256("REDEEMER_ROLE");
    bytes32 public constant override REDEEMER_CONTRACT_ROLE  = keccak256("REDEEMER_CONTRACT_ROLE");

    uint256 internal immutable _swapTokenPrecision;
    uint256 internal immutable _collateralTokenPrecision;
    uint256 internal immutable _creditTokenPrecision;

    IERC20 public override immutable swapToken;
    IERC20 public override immutable collateralToken;
    IERC20 public override immutable creditToken;

    address public override swapTokenRateProvider;
    address public override collateralTokenRateProvider;
    address public override creditTokenRateProvider;

    address public override pocket;

    bool public override creditTokenDepositsDisabled;
    bool public override swapToCreditPaused;
    bool public override creditToSwapPaused;
    bool public override collateralToCreditPaused;
    bool public override creditToCollateralPaused;
    bool public override depositsPaused;
    bool public override initiateRedeemPaused;

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
        address swapToken_,
        address collateralToken_,
        address creditToken_,
        address swapTokenRateProvider_,
        address collateralTokenRateProvider_,
        address creditTokenRateProvider_
    ) {
        // Setup Roles
        require(owner_ != address(0), "GroveBasin/invalid-owner");

        _grantRole(OWNER_ROLE,              owner_);
        _grantRole(LIQUIDITY_PROVIDER_ROLE, msg.sender);

        _setRoleAdmin(MANAGER_ROLE,            MANAGER_ADMIN_ROLE);
        _setRoleAdmin(LIQUIDITY_PROVIDER_ROLE, MANAGER_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_CONTRACT_ROLE,  MANAGER_ADMIN_ROLE);
        _setRoleAdmin(REDEEMER_ROLE,           MANAGER_ADMIN_ROLE);

        // Setup Tokens
        require(swapToken_       != address(0), "GroveBasin/invalid-swapToken");
        require(collateralToken_ != address(0), "GroveBasin/invalid-collateralToken");
        require(creditToken_     != address(0), "GroveBasin/invalid-creditToken");

        require(swapToken_       != collateralToken_, "GroveBasin/swapToken-collateralToken-same");
        require(swapToken_       != creditToken_,     "GroveBasin/swapToken-creditToken-same");
        require(collateralToken_ != creditToken_,     "GroveBasin/collateralToken-creditToken-same");

        swapToken       = IERC20(swapToken_);
        collateralToken = IERC20(collateralToken_);
        creditToken     = IERC20(creditToken_);

        _swapTokenPrecision       = 10 ** IERC20(swapToken_).decimals();
        _collateralTokenPrecision = 10 ** IERC20(collateralToken_).decimals();
        _creditTokenPrecision     = 10 ** IERC20(creditToken_).decimals();

        // Necessary to ensure rounding works as expected
        require(_creditTokenPrecision     <= 1e18, "GroveBasin/creditToken-precision-too-high");
        require(_swapTokenPrecision       <= 1e18, "GroveBasin/swapToken-precision-too-high");
        require(_collateralTokenPrecision <= 1e18, "GroveBasin/collateralToken-precision-too-high");

        // Setup Rate Providers
        require(swapTokenRateProvider_       != address(0), "GroveBasin/invalid-swapTokenRateProvider");
        require(collateralTokenRateProvider_ != address(0), "GroveBasin/invalid-collateralTokenRateProvider");
        require(creditTokenRateProvider_     != address(0), "GroveBasin/invalid-creditTokenRateProvider");

        require(
            IRateProviderLike(swapTokenRateProvider_).getConversionRate() != 0,
            "GroveBasin/swap-rate-provider-returns-zero"
        );

        require(
            IRateProviderLike(collateralTokenRateProvider_).getConversionRate() != 0,
            "GroveBasin/collateral-rate-provider-returns-zero"
        );

        require(
            IRateProviderLike(creditTokenRateProvider_).getConversionRate() != 0,
            "GroveBasin/credit-rate-provider-returns-zero"
        );

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
        require(newRateProvider != address(0), "GroveBasin/invalid-rate-provider");
        require(
            IRateProviderLike(newRateProvider).getConversionRate() != 0,
            "GroveBasin/rate-provider-returns-zero"
        );

        address oldRateProvider;

        if (token == address(swapToken)) {
            oldRateProvider             = swapTokenRateProvider;
            swapTokenRateProvider       = newRateProvider;
        } else if (token == address(collateralToken)) {
            oldRateProvider             = collateralTokenRateProvider;
            collateralTokenRateProvider = newRateProvider;
        } else if (token == address(creditToken)) {
            oldRateProvider             = creditTokenRateProvider;
            creditTokenRateProvider     = newRateProvider;
        } else {
            revert("GroveBasin/invalid-token");
        }

        emit RateProviderSet(token, oldRateProvider, newRateProvider);
    }

    /// @inheritdoc IGroveBasin
    function setMaxSwapSizeBounds(uint256 newLowerBound, uint256 newUpperBound)
        external override onlyRole(MANAGER_ADMIN_ROLE)
    {
        require(newLowerBound <= newUpperBound, "GroveBasin/min-gt-max-swap-size");

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
        require(newMinThreshold != 0,               "GroveBasin/min-threshold-zero");
        require(newMinThreshold <= newMaxThreshold, "GroveBasin/min-gt-max-threshold");

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
        require(newMinFee <= newMaxFee, "GroveBasin/min-fee-gt-max-fee");
        require(newMaxFee <= BPS,       "GroveBasin/max-fee-gte-bps");

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
        require(newPocket != address(0), "GroveBasin/invalid-pocket");

        address pocket_ = pocket;

        require(newPocket != pocket_, "GroveBasin/same-pocket");

        _withdrawLiquidityInPocket(_getAvailableBalance(address(swapToken)), address(swapToken));

        uint256 amountToTransfer = swapToken.balanceOf(pocket_);

        if (!_hasPocket()) {
            swapToken.safeTransfer(newPocket, amountToTransfer);
        } else {
            swapToken.safeTransferFrom(pocket_, newPocket, amountToTransfer);
        }

        pocket = newPocket;

        emit PocketSet(pocket_, newPocket, amountToTransfer);
    }

    /// @inheritdoc IGroveBasin
    function addTokenRedeemer(address redeemer) external override onlyRole(MANAGER_ADMIN_ROLE) {
        require(redeemer != address(0),                     "GroveBasin/invalid-redeemer");
        require(_grantRole(REDEEMER_CONTRACT_ROLE, redeemer), "GroveBasin/redeemer-already-added");

        ITokenRedeemer(redeemer).setUp(address(this));

        emit TokenRedeemerAdded(redeemer);
    }

    /// @inheritdoc IGroveBasin
    function removeTokenRedeemer(address redeemer) external override onlyRole(MANAGER_ADMIN_ROLE) {
        require(hasRole(REDEEMER_CONTRACT_ROLE, redeemer), "GroveBasin/invalid-redeemer");

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
        require(
            newMaxSwapSize >= maxSwapSizeLowerBound && newMaxSwapSize <= maxSwapSizeUpperBound,
            "GroveBasin/swap-size-out-of-bounds"
        );

        uint256 oldMaxSwapSize = maxSwapSize;
        maxSwapSize            = newMaxSwapSize;
        emit MaxSwapSizeSet(oldMaxSwapSize, newMaxSwapSize);
    }

    /// @inheritdoc IGroveBasin
    function setPaused(bytes32 action, bool paused)
        external override onlyRole(MANAGER_ROLE)
    {
        if      (action == "swapToCredit")        swapToCreditPaused        = paused;
        else if (action == "creditToSwap")        creditToSwapPaused        = paused;
        else if (action == "collateralToCredit")  collateralToCreditPaused  = paused;
        else if (action == "creditToCollateral")  creditToCollateralPaused  = paused;
        else if (action == "deposits")            depositsPaused            = paused;
        else if (action == "initiateRedeem")      initiateRedeemPaused      = paused;
        else                                      revert("GroveBasin/invalid-action");

        emit PausedSet(action, paused);
    }

    /// @inheritdoc IGroveBasin
    function setStalenessThreshold(uint256 newThreshold)
        external override onlyRole(MANAGER_ROLE)
    {
        require(newThreshold >= minStalenessThreshold, "GroveBasin/threshold-too-low");
        require(newThreshold <= maxStalenessThreshold, "GroveBasin/threshold-too-high");

        uint256 oldThreshold = stalenessThreshold;

        require(newThreshold != oldThreshold, "GroveBasin/same-staleness-threshold");

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
        require(amountIn != 0,          "GroveBasin/invalid-amountIn");
        require(receiver != address(0), "GroveBasin/invalid-receiver");

        _checkSwapNotPaused(assetIn, assetOut);

        amountOut = previewSwapExactIn(assetIn, assetOut, amountIn);

        require(amountOut >= minAmountOut, "GroveBasin/amountOut-too-low");

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
        require(amountOut != 0,         "GroveBasin/invalid-amountOut");
        require(receiver != address(0), "GroveBasin/invalid-receiver");

        _checkSwapNotPaused(assetIn, assetOut);

        amountIn = previewSwapExactOut(assetIn, assetOut, amountOut);

        require(amountIn <= maxAmountIn, "GroveBasin/amountIn-too-high");

        _withdrawLiquidityInPocket(amountOut, assetOut);
        _pullAsset(assetIn, amountIn);
        _pushAsset(assetOut, receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external override onlyRole(LIQUIDITY_PROVIDER_ROLE) returns (uint256 newShares)
    {
        require(!depositsPaused,      "GroveBasin/deposits-paused");
        require(assetsToDeposit != 0, "GroveBasin/invalid-amount");

        newShares = previewDeposit(asset, assetsToDeposit);

        require(newShares > 0, "GroveBasin/no-new-shares");

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
        require(maxAssetsToWithdraw != 0, "GroveBasin/invalid-amount");

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
        require(
            !(asset == address(creditToken) && creditTokenDepositsDisabled),
            "GroveBasin/creditToken-deposits-disabled"
        );

        // Convert amount to 1e18 precision denominated in value of USD then convert to shares.
        // NOTE: Don't need to check valid asset here since `_getAssetValue` will revert if invalid
        return convertToShares(_getAssetValue(asset, assetsToDeposit, false));  // Round down
    }

    /// @inheritdoc IGroveBasin
    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
    {
        require(_isValidAsset(asset), "GroveBasin/invalid-asset");

        uint256 assetBalance = _getAvailableBalance(asset);

        assetsWithdrawn = assetBalance < maxAssetsToWithdraw
            ? assetBalance
            : maxAssetsToWithdraw;

        // Get shares to burn, rounding up for both calculations
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
        require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize, "GroveBasin/swap-size-exceeded");

        // Round down to get amountOut
        amountOut = _getSwapQuote(assetIn, assetOut, amountIn, false);

        // Assumes no stable-to-stable swap
        if (assetOut == address(creditToken)) {
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

        require(_getAssetValue(assetIn, amountIn, false) <= maxSwapSize, "GroveBasin/swap-size-exceeded");

        // Assumes no stable-to-stable swap
        if (assetOut == address(creditToken)) {
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
        require(_isValidAsset(asset), "GroveBasin/invalid-asset");

        uint256 assetValue = convertToAssetValue(numShares);

        if (asset == address(swapToken)) {
            return assetValue
                * 1e9
                * _swapTokenPrecision
                / _getConversionRate(swapTokenRateProvider);
        }
        else if (asset == address(collateralToken)) {
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
        require(_isValidAsset(asset), "GroveBasin/invalid-asset");
        return convertToShares(_getAssetValue(asset, assets, false));  // Round down
    }

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    /// @inheritdoc IGroveBasin
    function totalAssets() public view override returns (uint256) {
        return _getSwapTokenValue(
                    _getAvailableBalance(address(swapToken))
                )
            +  _getCollateralTokenValue(
                    _getAvailableBalance(address(collateralToken))
                )
            +  _getCreditTokenValue(
                    _getAvailableBalance(address(creditToken)), false // Round down
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
        if      (asset == address(swapToken))       return _getSwapTokenValue(amount);
        else if (asset == address(collateralToken)) return _getCollateralTokenValue(amount);
        else if (asset == address(creditToken))     return _getCreditTokenValue(amount, roundUp);
        else                                        revert("GroveBasin/invalid-asset-for-value");
    }

    /// @dev Returns the USD value of `amount` of swap tokens in 1e18 precision.
    function _getSwapTokenValue(uint256 amount) internal view returns (uint256) {
        return amount
            * _getConversionRate(swapTokenRateProvider)
            / 1e9
            / _swapTokenPrecision;
    }

    /// @dev Returns the USD value of `amount` of collateral tokens in 1e18 precision.
    function _getCollateralTokenValue(uint256 amount) internal view returns (uint256) {
        // amount * rate / 1e27 gives USD value, then scale to 1e18
        // amount * rate / 1e9 / precision = amount * rate / (1e9 * precision)
        return amount
            * _getConversionRate(collateralTokenRateProvider)
            / 1e9
            / _collateralTokenPrecision;
    }

    /// @dev Returns the USD value of `amount` of credit tokens in 1e18 precision.
    function _getCreditTokenValue(uint256 amount, bool roundUp) internal view returns (uint256) {
        uint256 rate = _getConversionRate(creditTokenRateProvider);

        if (!roundUp) return amount
            * rate
            / 1e9
            / _creditTokenPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * rate, 1e9),
            _creditTokenPrecision
        );
    }

    /**********************************************************************************************/
    /*** Internal preview functions (swaps)                                                     ***/
    /**********************************************************************************************/

    /// @dev Converts `amount` of `asset` into `quoteAsset` terms using rate providers.
    function _getSwapQuote(address asset, address quoteAsset, uint256 amount, bool roundUp)
        internal view returns (uint256 quoteAmount)
    {
        if (asset == address(swapToken)) {
            if      (quoteAsset == address(collateralToken)) revert("GroveBasin/invalid-swap");
            else if (quoteAsset == address(creditToken))     return _convertSwapToCreditToken(amount, roundUp);
        }

        else if (asset == address(collateralToken)) {
            if      (quoteAsset == address(swapToken))      revert("GroveBasin/invalid-swap");
            else if (quoteAsset == address(creditToken))    return _convertCollateralToCreditToken(amount, roundUp);
        }

        else if (asset == address(creditToken)) {
            if      (quoteAsset == address(swapToken))       return _convertCreditTokenToSwap(amount, roundUp);
            else if (quoteAsset == address(collateralToken)) return _convertCreditTokenToCollateral(amount, roundUp);
        }

        revert("GroveBasin/invalid-asset");
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

        require(
            block.timestamp - lastUpdated <= stalenessThreshold,
            "GroveBasin/stale-rate"
        );
    }

    /**
     * @dev Withdraws liquidity from the pocket if one is configured. For swap tokens, tokens
     *      remain in the pocket after withdraw since `_pushAsset` uses `transferFrom`. For
     *      collateral tokens, the deficit is pulled back to Basin.
     */
    function _withdrawLiquidityInPocket(uint256 amount, address asset) internal {
        if (!_hasPocket()) return;

        if (asset == address(swapToken)) {
            try IGroveBasinPocket(pocket).withdrawLiquidity(amount, asset) {} catch {}
        } else if (asset == address(collateralToken)) {
            uint256 basinBalance = IERC20(asset).balanceOf(address(this));

            if (basinBalance < amount) {
                uint256 deficit = amount - basinBalance;
                try IGroveBasinPocket(pocket).withdrawLiquidity(deficit, asset) returns (uint256 drawn) {
                    IERC20(asset).safeTransferFrom(pocket, address(this), drawn);
                } catch {}
            }
        }
    }

    /// @dev Deposits swap token liquidity into the pocket if one is configured.
    function _depositLiquidityInPocket(uint256 amount, address asset) internal {
        if (asset == address(swapToken) && _hasPocket()) {
            IGroveBasinPocket(pocket).depositLiquidity(amount, asset);
        }
    }

    /// @dev Returns the available balance of `asset`, querying the pocket for swap tokens.
    function _getAvailableBalance(address asset) internal view returns (uint256) {
        if (asset == address(swapToken) && _hasPocket()) {
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
        if (assetIn == address(swapToken) && assetOut == address(creditToken)) {
            require(!swapToCreditPaused, "GroveBasin/swap-to-credit-paused");
        } else if (assetIn == address(creditToken) && assetOut == address(swapToken)) {
            require(!creditToSwapPaused, "GroveBasin/credit-to-swap-paused");
        } else if (assetIn == address(collateralToken) && assetOut == address(creditToken)) {
            require(!collateralToCreditPaused, "GroveBasin/collateral-to-credit-paused");
        } else if (assetIn == address(creditToken) && assetOut == address(collateralToken)) {
            require(!creditToCollateralPaused, "GroveBasin/credit-to-collateral-paused");
        }
    }

    /// @dev Returns true if `asset` is one of the three supported tokens.
    function _isValidAsset(address asset) internal view returns (bool) {
        return asset == address(swapToken) || asset == address(collateralToken) || asset == address(creditToken);
    }

    /// @dev Returns the address holding custody of `asset` (pocket for swap tokens, Basin otherwise).
    function _getAssetCustodian(address asset) internal view returns (address custodian) {
        custodian = asset == address(swapToken) ? pocket : address(this);
    }

    /// @dev Transfers `amount` of `asset` from `msg.sender` to the asset's custodian.
    function _pullAsset(address asset, uint256 amount) internal {
        IERC20(asset).safeTransferFrom(msg.sender, _getAssetCustodian(asset), amount);
    }

    /// @dev Transfers `amount` of `asset` to `receiver`, pulling from pocket if needed.
    function _pushAsset(address asset, address receiver, uint256 amount) internal {
        if (asset == address(swapToken) && _hasPocket()) {
            IERC20(asset).safeTransferFrom(pocket, receiver, amount);
        } else {
            IERC20(asset).safeTransfer(receiver, amount);
        }
    }

    /// @dev Approves and sends credit tokens to the redeemer to initiate an async redemption.
    function _initiateRedeem(address redeemer, uint256 creditTokenAmount) internal {
        require(!initiateRedeemPaused,                     "GroveBasin/initiate-redeem-paused");
        require(hasRole(REDEEMER_CONTRACT_ROLE, redeemer), "GroveBasin/invalid-redeemer");

        creditToken.approve(redeemer, creditTokenAmount);
        ITokenRedeemer(redeemer).initiateRedeem(creditTokenAmount);
        creditToken.approve(redeemer, 0);

        redeemedCreditTokenBalance += creditTokenAmount;
        emit RedeemInitiated(redeemer, msg.sender, creditTokenAmount);
    }

    /// @dev Completes an async redemption, decreasing the tracked credit token balance.
    function _completeRedeem(address redeemer, uint256 creditTokenAmount) internal {
        require(hasRole(REDEEMER_CONTRACT_ROLE, redeemer), "GroveBasin/invalid-redeemer");

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
        require(newPurchaseFee >= minFee && newPurchaseFee <= maxFee, "GroveBasin/purchase-fee-out-of-bounds");

        uint256 oldPurchaseFee = purchaseFee;
        purchaseFee = newPurchaseFee;

        emit PurchaseFeeSet(oldPurchaseFee, newPurchaseFee);
    }

    /// @dev Sets the redemption fee, enforcing it is within [minFee, maxFee].
    function _setRedemptionFee(uint256 newRedemptionFee) internal {
        require(newRedemptionFee >= minFee && newRedemptionFee <= maxFee, "GroveBasin/redemption-fee-out-of-bounds");

        uint256 oldRedemptionFee = redemptionFee;
        redemptionFee = newRedemptionFee;

        emit RedemptionFeeSet(oldRedemptionFee, newRedemptionFee);
    }
}
