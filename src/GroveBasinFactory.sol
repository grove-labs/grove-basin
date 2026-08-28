// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import {
    GroveBasinDeployer,
    PocketDeployer,
    RedeemerDeployer,
    TimelockDeployer
} from "src/deployers/BasinDeployers.sol";

contract GroveBasinFactory {

    using SafeERC20 for IERC20;

    enum PocketType { UsdsUsdc, MorphoUsdt, AaveUsdt, None }

    /// @notice Auto-incrementing CREATE2 salt counter for the full-setup deployment flow.
    uint256 public nonce;

    /// @notice Upper bound of the salt range reserved for the sequential (nonce-based) flow.
    ///         Caller-selected salts must be strictly greater so the two flows never share a
    ///         CREATE2 address.
    uint256 public constant MAX_AUTO_SALT = type(uint256).max / 2;

    /**
     * @param liquidityProvider Address of the liquidity provider or share receiver being configured. Must not be the factory itself.
     * @param isDepositor       True grants LIQUIDITY_PROVIDER_ROLE; false permissions the address as a share receiver only.
     * @param tokens            Every Basin asset, ordered [swapToken, collateralToken, creditToken]; the Basin rejects anything else.
     * @param allowed           Parallel array to tokens, flagging whether the address may deposit and withdraw each one.
     */
    struct LpConfig {
        address   liquidityProvider;
        bool      isDepositor;
        address[] tokens;
        bool[]    allowed;
    }

    /**
     * @param liquidityProvider           Granted LIQUIDITY_PROVIDER_ROLE by the Basin constructor.
     * @param lpConfigs                   Addresses configured via setLiquidityProvider during init, so LPs and their share receivers are set up together; empty configures none.
     * @param swapToken                   Basin swap token.
     * @param collateralToken             Basin collateral token.
     * @param creditToken                 Basin credit token.
     * @param swapTokenRateProvider       Rate provider for the swap token.
     * @param collateralTokenRateProvider Rate provider for the collateral token.
     * @param creditTokenRateProvider     Rate provider for the credit token.
     * @param pocketAddress1              UsdsUsdc: PSM wrapper | MorphoUsdt: ERC-4626 vault | AaveUsdt: aUSDT token.
     * @param pocketAddress2              AaveUsdt: Aave V3 pool | otherwise unused.
     * @param managerAdmin                Granted MANAGER_ADMIN_ROLE; UsdsUsdc pocket owner and timelock executor. Must be non-zero: a zero value would open timelock execution to any account.
     * @param manager                     Granted MANAGER_ROLE.
     * @param pauser                      Granted PAUSER_ROLE; timelock canceller.
     * @param redemptionAddress           Non-zero deploys a TransferTokenRedeemer with this redemption address and registers it.
     * @param tokenRedeemer               Pre-deployed token redeemer to register (used only when redemptionAddress == address(0); address(0) skips).
     * @param issuerRedeemer              Address granted REDEEMER_ROLE (address(0) skips).
     * @param minFee                      Lower fee bound applied to the Basin, in basis points.
     * @param maxFee                      Upper fee bound applied to the Basin, in basis points.
     * @param swapAllowlistEnabled        True enables the global swap allowlist before the factory relinquishes MANAGER_ADMIN_ROLE.
     * @param pocketType                  Which pocket implementation to deploy and wire up (None deploys no pocket).
     * @param pausedFlags                 Flags applied via setPaused; empty pauses nothing.
     * @param allowlistManagers           Addresses granted ALLOWLIST_MANAGER_ROLE; empty grants none.
     */
    struct DeployParams {
        address    liquidityProvider;
        LpConfig[] lpConfigs;
        address    swapToken;
        address    collateralToken;
        address    creditToken;
        address    swapTokenRateProvider;
        address    collateralTokenRateProvider;
        address    creditTokenRateProvider;
        address    pocketAddress1;
        address    pocketAddress2;
        address    managerAdmin;
        address    manager;
        address    pauser;
        address    redemptionAddress;
        address    tokenRedeemer;
        address    issuerRedeemer;
        uint256    minFee;
        uint256    maxFee;
        bool       swapAllowlistEnabled;
        PocketType pocketType;
        bytes4[]   pausedFlags;
        address[]  allowlistManagers;
    }

    error InvalidAdminTimelock();
    error InvalidTimelockProposer();
    error InvalidLiquidityProvider();
    error InvalidManagerAdmin();
    error InvalidCustomSalt();

    event GroveBasinDeployed(
        address indexed groveBasin,
        address indexed owner,
        address         swapToken,
        address         collateralToken,
        address         creditToken
    );

    /**********************************************************************************************/
    /*** Basin-only deployment                                                                  ***/
    /**********************************************************************************************/

    function deploy(
        address owner,
        address liquidityProvider,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        external returns (address groveBasin)
    {
        return _deploy({
            salt                        : bytes32(nonce++),
            owner                       : owner,
            liquidityProvider           : liquidityProvider,
            swapToken                   : swapToken,
            collateralToken             : collateralToken,
            creditToken                 : creditToken,
            swapTokenRateProvider       : swapTokenRateProvider,
            collateralTokenRateProvider : collateralTokenRateProvider,
            creditTokenRateProvider     : creditTokenRateProvider
        });
    }

    function deploy(
        bytes32 salt,
        address owner,
        address liquidityProvider,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        public returns (address groveBasin)
    {
        if (uint256(salt) <= MAX_AUTO_SALT) revert InvalidCustomSalt();

        return _deploy({
            salt                        : salt,
            owner                       : owner,
            liquidityProvider           : liquidityProvider,
            swapToken                   : swapToken,
            collateralToken             : collateralToken,
            creditToken                 : creditToken,
            swapTokenRateProvider       : swapTokenRateProvider,
            collateralTokenRateProvider : collateralTokenRateProvider,
            creditTokenRateProvider     : creditTokenRateProvider
        });
    }

    function _deploy(
        bytes32 salt,
        address owner,
        address liquidityProvider,
        address swapToken,
        address collateralToken,
        address creditToken,
        address swapTokenRateProvider,
        address collateralTokenRateProvider,
        address creditTokenRateProvider
    )
        internal returns (address groveBasin)
    {
        uint256 seedAmount = 10 ** IERC20(swapToken).decimals();

        IERC20(swapToken).safeTransferFrom(msg.sender, address(this), seedAmount);

        groveBasin = GroveBasinDeployer.deploy({
            salt                        : salt,
            owner                       : owner,
            liquidityProvider           : liquidityProvider,
            swapToken                   : swapToken,
            collateralToken             : collateralToken,
            creditToken                 : creditToken,
            swapTokenRateProvider       : swapTokenRateProvider,
            collateralTokenRateProvider : collateralTokenRateProvider,
            creditTokenRateProvider     : creditTokenRateProvider
        });

        IERC20(swapToken).safeApprove(groveBasin, seedAmount);
        GroveBasin(groveBasin).depositInitial(swapToken, seedAmount);

        emit GroveBasinDeployed(groveBasin, owner, swapToken, collateralToken, creditToken);
    }

    /**********************************************************************************************/
    /*** Full setup deployment                                                                  ***/
    /**********************************************************************************************/

    /// @notice Deploy a GroveBasin together with a fresh admin TimelockController that receives
    ///         OWNER_ROLE.
    function deployWithTimelockAndInit(DeployParams calldata params, address proposer, uint256 minDelay)
        external returns (address basin, address pocket, address redeemer, address timelock)
    {
        if (proposer == address(0)) revert InvalidTimelockProposer();

        timelock = TimelockDeployer.deploy({
            minDelay  : minDelay,
            proposer  : proposer,
            executor  : params.managerAdmin,
            admin     : address(this),
            canceller : params.pauser
        });

        (basin, pocket, redeemer) = deployAndInit(params, timelock);
    }

    /// @notice Deploy and fully configure a GroveBasin, handing OWNER_ROLE to `adminTimelock`.
    ///         The factory holds OWNER_ROLE and MANAGER_ADMIN_ROLE only for the duration of this
    ///         call and revokes both from itself before returning, so no deployer-side admin
    ///         remains. GROVE_PROXY retains MANAGER_ADMIN_ROLE.
    function deployAndInit(DeployParams calldata params, address adminTimelock)
        public returns (address basin, address pocket, address redeemer)
    {
        if (adminTimelock == address(0) || adminTimelock == address(this)) revert InvalidAdminTimelock();
        if (params.liquidityProvider == address(this))                     revert InvalidLiquidityProvider();
        if (params.managerAdmin == address(0))                             revert InvalidManagerAdmin();

        basin = _deploy({
            salt                        : bytes32(nonce++),
            owner                       : address(this),
            liquidityProvider           : params.liquidityProvider,
            swapToken                   : params.swapToken,
            collateralToken             : params.collateralToken,
            creditToken                 : params.creditToken,
            swapTokenRateProvider       : params.swapTokenRateProvider,
            collateralTokenRateProvider : params.collateralTokenRateProvider,
            creditTokenRateProvider     : params.creditTokenRateProvider
        });

        GroveBasin groveBasin = GroveBasin(basin);

        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), address(this));
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), params.managerAdmin);

        pocket = _deployPocket(params, basin);

        if (pocket != address(0)) {
            groveBasin.setPocket(pocket);
        }

        redeemer = params.redemptionAddress != address(0)
            ? RedeemerDeployer.deployTransfer({
                creditToken       : params.creditToken,
                redemptionAddress : params.redemptionAddress,
                basin             : basin
            })
            : params.tokenRedeemer;

        _initBasin(groveBasin, params, redeemer, adminTimelock);
    }

    /**********************************************************************************************/
    /*** Internal helpers                                                                       ***/
    /**********************************************************************************************/

    function _deployPocket(DeployParams calldata params, address basin) internal returns (address) {
        if (params.pocketType == PocketType.UsdsUsdc) {
            return PocketDeployer.deployUsdsUsdc({
                basin      : basin,
                usdc       : params.collateralToken,
                usds       : params.swapToken,
                psm        : params.pocketAddress1,
                groveProxy : params.managerAdmin
            });
        } else if (params.pocketType == PocketType.MorphoUsdt) {
            return PocketDeployer.deployMorphoUsdt({
                basin : basin,
                usdt  : params.swapToken,
                vault : params.pocketAddress1
            });
        } else if (params.pocketType == PocketType.AaveUsdt) {
            return PocketDeployer.deployAaveUsdt({
                basin      : basin,
                usdt       : params.swapToken,
                aUsdt      : params.pocketAddress1,
                aaveV3Pool : params.pocketAddress2
            });
        } else {
            return address(0);  // PocketType.None
        }
    }

    /// @dev Mirrors the BasinSetup.performBasinInit sequence, then revokes the factory's own
    ///      OWNER_ROLE and MANAGER_ADMIN_ROLE so the deployer retains no admin power.
    function _initBasin(
        GroveBasin            groveBasin,
        DeployParams calldata params,
        address               tokenRedeemer,
        address               adminTimelock
    )
        internal
    {
        if (tokenRedeemer != address(0)) {
            groveBasin.addTokenRedeemer(tokenRedeemer);
        }

        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), params.manager);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(),  params.pauser);

        for (uint256 i; i < params.allowlistManagers.length; ++i) {
            groveBasin.grantRole(groveBasin.ALLOWLIST_MANAGER_ROLE(), params.allowlistManagers[i]);
        }

        for (uint256 i; i < params.lpConfigs.length; ++i) {
            LpConfig calldata config = params.lpConfigs[i];

            // The factory holds MANAGER_ADMIN_ROLE only for the length of this call, so any
            // permission it grants itself would outlive its authority to remove it.
            if (config.liquidityProvider == address(this)) revert InvalidLiquidityProvider();

            groveBasin.setLiquidityProvider(
                config.liquidityProvider,
                config.isDepositor,
                config.tokens,
                config.allowed
            );
        }

        if (params.issuerRedeemer != address(0)) {
            groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), params.issuerRedeemer);
        }

        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), address(this));

        for (uint256 i; i < params.pausedFlags.length; ++i) {
            groveBasin.setPaused(params.pausedFlags[i]);
        }

        if (params.swapAllowlistEnabled) {
            groveBasin.setGlobalSwapAllowlistEnabled(true);
        }

        if (params.minFee > 0) {
            groveBasin.setFeeBounds(0, params.maxFee);
            groveBasin.setPurchaseFee(params.minFee);
            groveBasin.setRedemptionFee(params.minFee);
        }

        groveBasin.setFeeBounds(params.minFee, params.maxFee);

        groveBasin.revokeRole(groveBasin.PAUSER_ROLE(), address(this));

        groveBasin.grantRole(groveBasin.OWNER_ROLE(), adminTimelock);

        // Order matters: MANAGER_ADMIN_ROLE is administered by OWNER_ROLE, so revoke it first.
        groveBasin.revokeRole(groveBasin.MANAGER_ADMIN_ROLE(), address(this));
        groveBasin.revokeRole(groveBasin.OWNER_ROLE(),         address(this));
    }

}
