// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Math }          from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IGroveBasin }             from "src/interfaces/IGroveBasin.sol";
import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

contract GroveBasin is IGroveBasin, AccessControl {

    using SafeERC20 for IERC20;

    uint256 internal immutable _secondaryTokenPrecision;
    uint256 internal immutable _collateralTokenPrecision;
    uint256 internal immutable _creditTokenPrecision;

    IERC20 public override immutable secondaryToken;
    IERC20 public override immutable collateralToken;
    IERC20 public override immutable creditToken;

    address public override immutable secondaryTokenRateProvider;
    address public override immutable collateralTokenRateProvider;
    address public override immutable creditTokenRateProvider;

    address public override pocket;

    uint256 public override totalShares;

    mapping(address user => uint256 shares) public override shares;

    constructor(
        address owner_,
        address secondaryToken_,
        address collateralToken_,
        address creditToken_,
        address secondaryTokenRateProvider_,
        address collateralTokenRateProvider_,
        address creditTokenRateProvider_
    ) {
        require(owner_                   != address(0), "GroveBasin/invalid-owner");
        require(secondaryToken_              != address(0), "GroveBasin/invalid-secondaryToken");
        require(collateralToken_             != address(0), "GroveBasin/invalid-collateralToken");
        require(creditToken_                 != address(0), "GroveBasin/invalid-creditToken");
        require(secondaryTokenRateProvider_  != address(0), "GroveBasin/invalid-secondaryTokenRateProvider");
        require(collateralTokenRateProvider_ != address(0), "GroveBasin/invalid-collateralTokenRateProvider");
        require(creditTokenRateProvider_     != address(0), "GroveBasin/invalid-creditTokenRateProvider");

        require(secondaryToken_ != collateralToken_, "GroveBasin/secondaryToken-collateralToken-same");
        require(secondaryToken_ != creditToken_,     "GroveBasin/secondaryToken-creditToken-same");
        require(collateralToken_ != creditToken_,    "GroveBasin/collateralToken-creditToken-same");

        secondaryToken  = IERC20(secondaryToken_);
        collateralToken = IERC20(collateralToken_);
        creditToken     = IERC20(creditToken_);

        secondaryTokenRateProvider  = secondaryTokenRateProvider_;
        collateralTokenRateProvider = collateralTokenRateProvider_;
        creditTokenRateProvider     = creditTokenRateProvider_;
        pocket                      = address(this);

        require(
            IRateProviderLike(secondaryTokenRateProvider_).getConversionRate() != 0,
            "GroveBasin/secondary-rate-provider-returns-zero"
        );

        require(
            IRateProviderLike(collateralTokenRateProvider_).getConversionRate() != 0,
            "GroveBasin/collateral-rate-provider-returns-zero"
        );

        require(
            IRateProviderLike(creditTokenRateProvider_).getConversionRate() != 0,
            "GroveBasin/credit-rate-provider-returns-zero"
        );

        _secondaryTokenPrecision  = 10 ** IERC20(secondaryToken_).decimals();
        _collateralTokenPrecision = 10 ** IERC20(collateralToken_).decimals();
        _creditTokenPrecision     = 10 ** IERC20(creditToken_).decimals();

        _grantRole(DEFAULT_ADMIN_ROLE, owner_);

        // Necessary to ensure rounding works as expected
        require(_secondaryTokenPrecision  <= 1e18, "GroveBasin/secondaryToken-precision-too-high");
        require(_collateralTokenPrecision <= 1e18, "GroveBasin/collateralToken-precision-too-high");
    }

    /**********************************************************************************************/
    /*** Owner functions                                                                        ***/
    /**********************************************************************************************/

    function setPocket(address newPocket) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newPocket != address(0), "GroveBasin/invalid-pocket");

        address pocket_ = pocket;

        require(newPocket != pocket_, "GroveBasin/same-pocket");

        uint256 amountToTransfer = secondaryToken.balanceOf(pocket_);

        if (pocket_ == address(this)) {
            secondaryToken.safeTransfer(newPocket, amountToTransfer);
        } else {
            secondaryToken.safeTransferFrom(pocket_, newPocket, amountToTransfer);
        }

        pocket = newPocket;

        emit PocketSet(pocket_, newPocket, amountToTransfer);
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

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

        amountOut = previewSwapExactIn(assetIn, assetOut, amountIn);

        require(amountOut >= minAmountOut, "GroveBasin/amountOut-too-low");

        _pullAsset(assetIn, amountIn);
        _pushAsset(assetOut, receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

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

        amountIn = previewSwapExactOut(assetIn, assetOut, amountOut);

        require(amountIn <= maxAmountIn, "GroveBasin/amountIn-too-high");

        _pullAsset(assetIn, amountIn);
        _pushAsset(assetOut, receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external override returns (uint256 newShares)
    {
        require(assetsToDeposit != 0, "GroveBasin/invalid-amount");

        newShares = previewDeposit(asset, assetsToDeposit);

        shares[receiver] += newShares;
        totalShares      += newShares;

        _pullAsset(asset, assetsToDeposit);

        emit Deposit(asset, msg.sender, receiver, assetsToDeposit, newShares);
    }

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

        _pushAsset(asset, receiver, assetsWithdrawn);

        emit Withdraw(asset, msg.sender, receiver, assetsWithdrawn, sharesToBurn);
    }

    /**********************************************************************************************/
    /*** Deposit/withdraw preview functions                                                     ***/
    /**********************************************************************************************/

    function previewDeposit(address asset, uint256 assetsToDeposit)
        public view override returns (uint256)
    {
        // Convert amount to 1e18 precision denominated in value of USD then convert to shares.
        // NOTE: Don't need to check valid asset here since `_getAssetValue` will revert if invalid
        return convertToShares(_getAssetValue(asset, assetsToDeposit, false));  // Round down
    }

    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
    {
        require(_isValidAsset(asset), "GroveBasin/invalid-asset");

        uint256 assetBalance = IERC20(asset).balanceOf(_getAssetCustodian(asset));

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

    function previewSwapExactIn(address assetIn, address assetOut, uint256 amountIn)
        public view override returns (uint256 amountOut)
    {
        // Round down to get amountOut
        amountOut = _getSwapQuote(assetIn, assetOut, amountIn, false);
    }

    function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
        public view override returns (uint256 amountIn)
    {
        // Round up to get amountIn
        amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);
    }

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    function convertToAssets(address asset, uint256 numShares)
        public view override returns (uint256)
    {
        require(_isValidAsset(asset), "GroveBasin/invalid-asset");

        uint256 assetValue = convertToAssetValue(numShares);

        if (asset == address(secondaryToken)) {
            return assetValue
                * 1e9
                * _secondaryTokenPrecision
                / IRateProviderLike(secondaryTokenRateProvider).getConversionRate();
        }
        else if (asset == address(collateralToken)) {
            // assetValue is in 1e18, rate is 1e27, precision is native decimals
            // amount = assetValue * 1e27 / rate * precision / 1e18 = assetValue * 1e9 * precision / rate
            return assetValue
                * 1e9
                * _collateralTokenPrecision
                / IRateProviderLike(collateralTokenRateProvider).getConversionRate();
        }

        // NOTE: Multiplying by 1e27 and dividing by 1e18 cancels to 1e9 in numerator
        return assetValue
            * 1e9
            * _creditTokenPrecision
            / IRateProviderLike(creditTokenRateProvider).getConversionRate();
    }

    function convertToAssetValue(uint256 numShares) public view override returns (uint256) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ != 0) {
            return numShares * totalAssets() / totalShares_;
        }
        return numShares;
    }

    function convertToShares(uint256 assetValue) public view override returns (uint256) {
        uint256 totalAssets_ = totalAssets();
        if (totalAssets_ != 0) {
            return assetValue * totalShares / totalAssets_;
        }
        return assetValue;
    }

    function convertToShares(address asset, uint256 assets) public view override returns (uint256) {
        require(_isValidAsset(asset), "GroveBasin/invalid-asset");
        return convertToShares(_getAssetValue(asset, assets, false));  // Round down
    }

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    function totalAssets() public view override returns (uint256) {
        return _getSecondaryTokenValue(secondaryToken.balanceOf(pocket))
            +  _getCollateralTokenValue(collateralToken.balanceOf(address(this)))
            +  _getCreditTokenValue(creditToken.balanceOf(address(this)), false);  // Round down
    }

    /**********************************************************************************************/
    /*** Internal valuation functions (deposit/withdraw)                                        ***/
    /**********************************************************************************************/

    function _getAssetValue(address asset, uint256 amount, bool roundUp) internal view returns (uint256) {
        if      (asset == address(secondaryToken))  return _getSecondaryTokenValue(amount);
        else if (asset == address(collateralToken)) return _getCollateralTokenValue(amount);
        else if (asset == address(creditToken))     return _getCreditTokenValue(amount, roundUp);
        else revert("GroveBasin/invalid-asset-for-value");
    }

    function _getSecondaryTokenValue(uint256 amount) internal view returns (uint256) {
        return amount
            * IRateProviderLike(secondaryTokenRateProvider).getConversionRate()
            / 1e9
            / _secondaryTokenPrecision;
    }

    function _getCollateralTokenValue(uint256 amount) internal view returns (uint256) {
        // amount * rate / 1e27 gives USD value, then scale to 1e18
        // amount * rate / 1e9 / precision = amount * rate / (1e9 * precision)
        return amount
            * IRateProviderLike(collateralTokenRateProvider).getConversionRate()
            / 1e9
            / _collateralTokenPrecision;
    }

    function _getCreditTokenValue(uint256 amount, bool roundUp) internal view returns (uint256) {
        // NOTE: Multiplying by 1e18 and dividing by 1e27 cancels to 1e9 in denominator
        if (!roundUp) return amount
            * IRateProviderLike(creditTokenRateProvider).getConversionRate()
            / 1e9
            / _creditTokenPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * IRateProviderLike(creditTokenRateProvider).getConversionRate(), 1e9),
            _creditTokenPrecision
        );
    }

    /**********************************************************************************************/
    /*** Internal preview functions (swaps)                                                     ***/
    /**********************************************************************************************/

    function _getSwapQuote(address asset, address quoteAsset, uint256 amount, bool roundUp)
        internal view returns (uint256 quoteAmount)
    {
        if (asset == address(secondaryToken)) {
            if      (quoteAsset == address(collateralToken)) revert("GroveBasin/invalid-swap");
            else if (quoteAsset == address(creditToken))     return _convertSecondaryToCreditToken(amount, roundUp);
        }

        else if (asset == address(collateralToken)) {
            if      (quoteAsset == address(secondaryToken)) revert("GroveBasin/invalid-swap");
            else if (quoteAsset == address(creditToken))    return _convertCollateralToCreditToken(amount, roundUp);
        }

        else if (asset == address(creditToken)) {
            if      (quoteAsset == address(secondaryToken))  return _convertCreditTokenToSecondary(amount, roundUp);
            else if (quoteAsset == address(collateralToken)) return _convertCreditTokenToCollateral(amount, roundUp);
        }

        revert("GroveBasin/invalid-asset");
    }

    function _convertSecondaryToCreditToken(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        uint256 secondaryRate = IRateProviderLike(secondaryTokenRateProvider).getConversionRate();
        uint256 creditRate    = IRateProviderLike(creditTokenRateProvider).getConversionRate();

        if (!roundUp) return amount * secondaryRate / creditRate * _creditTokenPrecision / _secondaryTokenPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * secondaryRate, creditRate) * _creditTokenPrecision,
            _secondaryTokenPrecision
        );
    }

    function _convertCreditTokenToSecondary(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        uint256 secondaryRate = IRateProviderLike(secondaryTokenRateProvider).getConversionRate();
        uint256 creditRate    = IRateProviderLike(creditTokenRateProvider).getConversionRate();

        if (!roundUp) return amount * creditRate / secondaryRate * _secondaryTokenPrecision / _creditTokenPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * creditRate, secondaryRate) * _secondaryTokenPrecision,
            _creditTokenPrecision
        );
    }

    function _convertCollateralToCreditToken(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        // collateral -> USD value -> credit
        // USD value = amount * collateralRate / 1e9 / collateralPrecision (in 1e18)
        // credit = USD value * 1e27 / creditRate * creditPrecision / 1e18
        //        = amount * collateralRate / creditRate * creditPrecision / collateralPrecision
        uint256 collateralRate = IRateProviderLike(collateralTokenRateProvider).getConversionRate();
        uint256 creditRate     = IRateProviderLike(creditTokenRateProvider).getConversionRate();

        if (!roundUp) return amount * collateralRate / creditRate * _creditTokenPrecision / _collateralTokenPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * collateralRate, creditRate) * _creditTokenPrecision,
            _collateralTokenPrecision
        );
    }

    function _convertCreditTokenToCollateral(uint256 amount, bool roundUp)
        internal view returns (uint256)
    {
        // credit -> USD value -> collateral
        // USD value = amount * creditRate / 1e9 / creditPrecision (in 1e18)
        // collateral = USD value * 1e27 / collateralRate * collateralPrecision / 1e18
        //            = amount * creditRate / collateralRate * collateralPrecision / creditPrecision
        uint256 collateralRate = IRateProviderLike(collateralTokenRateProvider).getConversionRate();
        uint256 creditRate     = IRateProviderLike(creditTokenRateProvider).getConversionRate();

        if (!roundUp) return amount * creditRate / collateralRate * _collateralTokenPrecision / _creditTokenPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * creditRate, collateralRate) * _collateralTokenPrecision,
            _creditTokenPrecision
        );
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function _convertToSharesRoundUp(uint256 assetValue) internal view returns (uint256) {
        uint256 totalValue = totalAssets();
        if (totalValue != 0) {
            return Math.ceilDiv(assetValue * totalShares, totalValue);
        }
        return assetValue;
    }

    function _isValidAsset(address asset) internal view returns (bool) {
        return asset == address(secondaryToken) || asset == address(collateralToken) || asset == address(creditToken);
    }

    function _getAssetCustodian(address asset) internal view returns (address custodian) {
        custodian = asset == address(secondaryToken) ? pocket : address(this);
    }

    function _pullAsset(address asset, uint256 amount) internal {
        IERC20(asset).safeTransferFrom(msg.sender, _getAssetCustodian(asset), amount);
    }

    function _pushAsset(address asset, address receiver, uint256 amount) internal {
        if (asset == address(secondaryToken) && pocket != address(this)) {
            secondaryToken.safeTransferFrom(pocket, receiver, amount);
        } else {
            IERC20(asset).safeTransfer(receiver, amount);
        }
    }

}
