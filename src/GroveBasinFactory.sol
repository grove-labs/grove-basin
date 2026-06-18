// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import {
    GroveBasinDeployer,
    PocketDeployer,
    RedeemerDeployer,
    TimelockDeployer
} from "src/deployers/BasinDeployers.sol";

contract GroveBasinFactory {

    using SafeERC20 for IERC20;

    /// @notice DPAU ALM Proxy, set as the `liquidityProvider` on Basins deployed via the full
    ///         setup flow.
    address internal constant DPAU_ALM_PROXY = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;

    enum PocketType { UsdsUsdc, MorphoUsdt, AaveUsdt }

    /**
     * @param salt                        CREATE2 salt for the GroveBasin.
     * @param swapToken                   Basin swap token.
     * @param collateralToken             Basin collateral token.
     * @param creditToken                 Basin credit token.
     * @param swapTokenRateProvider       Rate provider for the swap token.
     * @param collateralTokenRateProvider Rate provider for the collateral token.
     * @param creditTokenRateProvider     Rate provider for the credit token.
     * @param pocketType                  Which pocket implementation to deploy and wire up.
     * @param pocketAddress1              UsdsUsdc: PSM wrapper | MorphoUsdt: ERC-4626 vault | AaveUsdt: aUSDT token.
     * @param pocketAddress2              AaveUsdt: Aave V3 pool | otherwise unused.
     * @param deployBuidlRedeemer         If true, deploy a BUIDLTokenRedeemer and register it.
     * @param buidlRedemptionAddress      Redemption address for the BUIDLTokenRedeemer (only used when deployBuidlRedeemer).
     * @param tokenRedeemer               Pre-deployed token redeemer to register (only used when !deployBuidlRedeemer; address(0) skips).
     * @param issuerRedeemer              Address granted REDEEMER_ROLE (address(0) skips).
     */
    struct DeployParams {
        bytes32    salt;
        address    swapToken;
        address    collateralToken;
        address    creditToken;
        address    swapTokenRateProvider;
        address    collateralTokenRateProvider;
        address    creditTokenRateProvider;
        PocketType pocketType;
        address    pocketAddress1;
        address    pocketAddress2;
        bool       deployBuidlRedeemer;
        address    buidlRedemptionAddress;
        address    tokenRedeemer;
        address    issuerRedeemer;
    }

    error InvalidSwapToken();
    error InvalidCollateralToken();
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
            Ethereum.GROVE_PROXY,
            address(this),
            Ethereum.ALM_FREEZER
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
            salt                        : params.salt,
            owner                       : address(this),
            liquidityProvider           : DPAU_ALM_PROXY,
            swapToken                   : params.swapToken,
            collateralToken             : params.collateralToken,
            creditToken                 : params.creditToken,
            swapTokenRateProvider       : params.swapTokenRateProvider,
            collateralTokenRateProvider : params.collateralTokenRateProvider,
            creditTokenRateProvider     : params.creditTokenRateProvider
        });

        GroveBasin groveBasin = GroveBasin(basin);

        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), address(this));
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY);

        pocket = _deployPocket(params, basin);
        groveBasin.setPocket(pocket);

        redeemer = params.deployBuidlRedeemer
            ? RedeemerDeployer.deployBuidl(params.creditToken, params.buidlRedemptionAddress, basin)
            : params.tokenRedeemer;

        _initBasin(groveBasin, redeemer, params.issuerRedeemer, adminTimelock);
    }

    /**********************************************************************************************/
    /*** Internal helpers                                                                       ***/
    /**********************************************************************************************/

    function _deployPocket(DeployParams calldata params, address basin) internal returns (address) {
        if (params.pocketType == PocketType.UsdsUsdc) {
            if (params.swapToken       != Ethereum.USDS) revert InvalidSwapToken();
            if (params.collateralToken != Ethereum.USDC) revert InvalidCollateralToken();

            return PocketDeployer.deployUsdsUsdc(
                basin,
                Ethereum.USDC,
                Ethereum.USDS,
                params.pocketAddress1,
                Ethereum.GROVE_PROXY
            );
        } else if (params.pocketType == PocketType.MorphoUsdt) {
            if (params.swapToken != Ethereum.USDT) revert InvalidSwapToken();

            return PocketDeployer.deployMorphoUsdt(basin, Ethereum.USDT, params.pocketAddress1);
        } else {
            if (params.swapToken != Ethereum.USDT) revert InvalidSwapToken();

            return PocketDeployer.deployAaveUsdt(basin, Ethereum.USDT, params.pocketAddress1, params.pocketAddress2);
        }
    }

    /// @dev Mirrors the BasinSetup.performBasinInit sequence, then revokes the factory's own
    ///      OWNER_ROLE and MANAGER_ADMIN_ROLE so the deployer retains no admin power.
    function _initBasin(GroveBasin groveBasin, address tokenRedeemer, address issuerRedeemer, address adminTimelock)
        internal
    {
        if (tokenRedeemer != address(0)) {
            groveBasin.addTokenRedeemer(tokenRedeemer);
        }

        groveBasin.grantRole(groveBasin.MANAGER_ROLE(), Ethereum.ALM_RELAYER);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(),  Ethereum.ALM_FREEZER);

        if (issuerRedeemer != address(0)) {
            groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), issuerRedeemer);
        }

        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), address(this));

        groveBasin.setPaused(groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT());
        groveBasin.setPaused(groveBasin.PAUSED_SWAP_COLLATERAL_TO_CREDIT());
        groveBasin.setPaused(groveBasin.PAUSED_DEPOSIT_CREDIT());
        groveBasin.setPaused(groveBasin.PAUSED_WITHDRAW_CREDIT());

        groveBasin.setFeeBounds(0, 500);

        groveBasin.revokeRole(groveBasin.PAUSER_ROLE(), address(this));

        groveBasin.grantRole(groveBasin.OWNER_ROLE(), adminTimelock);

        // Order matters: MANAGER_ADMIN_ROLE is administered by OWNER_ROLE, so revoke it first.
        groveBasin.revokeRole(groveBasin.MANAGER_ADMIN_ROLE(), address(this));
        groveBasin.revokeRole(groveBasin.OWNER_ROLE(),         address(this));
    }

}
