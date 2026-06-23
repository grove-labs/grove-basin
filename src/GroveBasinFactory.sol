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

    enum PocketType { UsdsUsdc, MorphoUsdt, AaveUsdt }

    uint256 public constant DEFAULT_MIN_FEE = 0;
    uint256 public constant DEFAULT_MAX_FEE = 500;

    /// @notice Auto-incrementing CREATE2 salt counter for the full-setup deployment flow.
    uint256 public nonce;

    /**
     * @param liquidityProvider           Address set as the Basin `liquidityProvider`.
     * @param swapToken                   Basin swap token.
     * @param collateralToken             Basin collateral token.
     * @param creditToken                 Basin credit token.
     * @param swapTokenRateProvider       Rate provider for the swap token.
     * @param collateralTokenRateProvider Rate provider for the collateral token.
     * @param creditTokenRateProvider     Rate provider for the credit token.
     * @param pocketType                  Which pocket implementation to deploy and wire up.
     * @param pocketAddress1              UsdsUsdc: PSM wrapper | MorphoUsdt: ERC-4626 vault | AaveUsdt: aUSDT token.
     * @param pocketAddress2              AaveUsdt: Aave V3 pool | otherwise unused.
     * @param groveProxy                  Granted MANAGER_ADMIN_ROLE; UsdsUsdc pocket owner and timelock executor.
     * @param almRelayer                  Granted MANAGER_ROLE.
     * @param almFreezer                  Granted PAUSER_ROLE; timelock canceller.
     * @param deployBuidlRedeemer         If true, deploy a BUIDLTokenRedeemer and register it.
     * @param buidlRedemptionAddress      Redemption address for the BUIDLTokenRedeemer (only used when deployBuidlRedeemer).
     * @param tokenRedeemer               Pre-deployed token redeemer to register (only used when !deployBuidlRedeemer; address(0) skips).
     * @param issuerRedeemer              Address granted REDEEMER_ROLE (address(0) skips).
     * @param pausedFlags                 Flags applied via setPaused; empty pauses nothing.
     * @param minFee                      Lower fee bound; ignored when maxFee == 0 (defaults applied).
     * @param maxFee                      Upper fee bound; 0 applies the defaults (DEFAULT_MIN_FEE, DEFAULT_MAX_FEE).
     */
    struct DeployParams {
        address    liquidityProvider;
        address    swapToken;
        address    collateralToken;
        address    creditToken;
        address    swapTokenRateProvider;
        address    collateralTokenRateProvider;
        address    creditTokenRateProvider;
        PocketType pocketType;
        address    pocketAddress1;
        address    pocketAddress2;
        address    groveProxy;
        address    almRelayer;
        address    almFreezer;
        bool       deployBuidlRedeemer;
        address    buidlRedemptionAddress;
        address    tokenRedeemer;
        address    issuerRedeemer;
        bytes4[]   pausedFlags;
        uint256    minFee;
        uint256    maxFee;
    }

    error InvalidAdminTimelock();
    error InvalidTimelockProposer();

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
        return deploy({
            salt                        : keccak256(abi.encode(owner, swapToken, collateralToken, creditToken)),
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
        uint256 seedAmount = 10 ** IERC20(swapToken).decimals();

        IERC20(swapToken).safeTransferFrom(msg.sender, address(this), seedAmount);

        groveBasin = GroveBasinDeployer.deploy(
            salt,
            owner,
            liquidityProvider,
            swapToken,
            collateralToken,
            creditToken,
            swapTokenRateProvider,
            collateralTokenRateProvider,
            creditTokenRateProvider
        );

        IERC20(swapToken).safeApprove(groveBasin, seedAmount);
        GroveBasin(groveBasin).depositInitial(swapToken, seedAmount);

        emit GroveBasinDeployed(groveBasin, owner, swapToken, collateralToken, creditToken);
    }

    /**********************************************************************************************/
    /*** Full setup deployment                                                                  ***/
    /**********************************************************************************************/

    /// @notice Deploy a GroveBasin together with a fresh admin TimelockController that receives
    ///         OWNER_ROLE.
    function deployWithTimelock(DeployParams calldata params, address proposer, uint256 minDelay)
        external returns (address basin, address pocket, address redeemer, address timelock)
    {
        if (proposer == address(0)) revert InvalidTimelockProposer();

        timelock = TimelockDeployer.deploy(
            minDelay,
            proposer,
            params.groveProxy,
            address(this),
            params.almFreezer
        );

        (basin, pocket, redeemer) = deploy(params, timelock);
    }

    /// @notice Deploy and fully configure a GroveBasin, handing OWNER_ROLE to `adminTimelock`.
    ///         The factory holds OWNER_ROLE and MANAGER_ADMIN_ROLE only for the duration of this
    ///         call and revokes both from itself before returning, so no deployer-side admin
    ///         remains. GROVE_PROXY retains MANAGER_ADMIN_ROLE.
    function deploy(DeployParams calldata params, address adminTimelock)
        public returns (address basin, address pocket, address redeemer)
    {
        if (adminTimelock == address(0)) revert InvalidAdminTimelock();

        basin = deploy({
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
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), params.groveProxy);

        pocket = _deployPocket(params, basin);
        groveBasin.setPocket(pocket);

        redeemer = params.deployBuidlRedeemer
            ? RedeemerDeployer.deployBuidl(params.creditToken, params.buidlRedemptionAddress, basin)
            : params.tokenRedeemer;

        _initBasin(groveBasin, params, redeemer, adminTimelock);
    }

    /**********************************************************************************************/
    /*** Internal helpers                                                                       ***/
    /**********************************************************************************************/

    function _deployPocket(DeployParams calldata params, address basin) internal returns (address) {
        if (params.pocketType == PocketType.UsdsUsdc) {
            return PocketDeployer.deployUsdsUsdc(
                basin,
                params.collateralToken,
                params.swapToken,
                params.pocketAddress1,
                params.groveProxy
            );
        } else if (params.pocketType == PocketType.MorphoUsdt) {
            return PocketDeployer.deployMorphoUsdt(basin, params.swapToken, params.pocketAddress1);
        } else {
            return PocketDeployer.deployAaveUsdt(basin, params.swapToken, params.pocketAddress1, params.pocketAddress2);
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

        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), params.almRelayer);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(),  params.almFreezer);

        if (params.issuerRedeemer != address(0)) {
            groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), params.issuerRedeemer);
        }

        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), address(this));

        for (uint256 i; i < params.pausedFlags.length; ++i) {
            groveBasin.setPaused(params.pausedFlags[i]);
        }

        uint256 minFee_ = params.minFee;
        uint256 maxFee_ = params.maxFee;
        if (maxFee_ == 0) {
            minFee_ = DEFAULT_MIN_FEE;
            maxFee_ = DEFAULT_MAX_FEE;
        }

        groveBasin.setFeeBounds(minFee_, maxFee_);

        groveBasin.revokeRole(groveBasin.PAUSER_ROLE(), address(this));

        groveBasin.grantRole(groveBasin.OWNER_ROLE(), adminTimelock);

        // Order matters: MANAGER_ADMIN_ROLE is administered by OWNER_ROLE, so revoke it first.
        groveBasin.revokeRole(groveBasin.MANAGER_ADMIN_ROLE(), address(this));
        groveBasin.revokeRole(groveBasin.OWNER_ROLE(),         address(this));
    }

}
