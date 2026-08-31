// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { GroveBasinFactory } from "src/GroveBasinFactory.sol";
import { UsdsUsdcPocket }    from "src/pockets/UsdsUsdcPocket.sol";

library BasinSetup {

    /// @notice DPAU ALM Proxy, granted LIQUIDITY_PROVIDER_ROLE on deployed Basins.
    address internal constant DPAU_ALM_PROXY = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;

    /// @notice Check the deployer has at least 1 USDS, then approve that amount to the factory
    ///         so the subsequent `factory.deploy(...)` call can pull it as the basin seed.
    function approveFactoryForSeeding(address factoryAddr) internal returns (GroveBasinFactory factory) {
        require(IERC20(Ethereum.USDS).balanceOf(msg.sender) >= 10 ** IERC20(Ethereum.USDS).decimals(), "insufficient-usds-balance");

        factory = GroveBasinFactory(factoryAddr);

        uint256 seedAmount = 10 ** IERC20(Ethereum.USDS).decimals();
        IERC20(Ethereum.USDS).approve(address(factory), seedAmount);
    }

    /// @notice Deploy a GroveBasin via the factory using the USDS/USDC pocket defaults.
    function deployUsdsUsdcBasin(
        GroveBasinFactory factory,
        address           deployer,
        address           creditToken,
        address           creditTokenRateProvider,
        address           fixedRateProvider
    ) internal returns (address basin) {
        basin = factory.deploy({
            owner                       : deployer,
            liquidityProvider           : DPAU_ALM_PROXY,
            swapToken                   : Ethereum.USDS,
            collateralToken             : Ethereum.USDC,
            creditToken                 : creditToken,
            swapTokenRateProvider       : fixedRateProvider,
            collateralTokenRateProvider : fixedRateProvider,
            creditTokenRateProvider     : creditTokenRateProvider
        });
    }

    /// @notice Grant MANAGER_ADMIN_ROLE to GROVE_PROXY and the deployer, deploy a new
    ///         UsdsUsdcPocket, and wire it onto the basin.
    function grantManagerAdminAndDeployPocket(
        GroveBasin basin,
        address    deployer,
        address    usdsPsmWrapper
    ) internal returns (address pocket) {
        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY);
        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), deployer);

        pocket = address(new UsdsUsdcPocket(
            address(basin),
            Ethereum.USDC,
            Ethereum.USDS,
            usdsPsmWrapper,
            Ethereum.GROVE_PROXY
        ));

        basin.setPocket(pocket);
    }

    /// @notice Universal post-deployment configuration sequence shared by GroveBasin setup
    ///         scripts: register the token redeemer, grant operational roles, pause the two swap
    ///         routes into the credit token, set fee bounds, and hand ownership over to the admin
    ///         timelock.
    /// @param  basin           The freshly deployed GroveBasin (pocket must already be wired up
    ///                         by the caller).
    /// @param  deployer        The deploying EOA. Must currently hold OWNER_ROLE and
    ///                         MANAGER_ADMIN_ROLE on `basin`.
    /// @param  tokenRedeemer   Token redeemer contract registered via `addTokenRedeemer`. Pass
    ///                         address(0) to skip.
    /// @param  issuerRedeemer  Address granted REDEEMER_ROLE. Pass address(0) to skip.
    /// @param  adminTimelock   The admin timelock receiving OWNER_ROLE.
    function performBasinInit(
        GroveBasin basin,
        address    deployer,
        address    tokenRedeemer,
        address    issuerRedeemer,
        address    adminTimelock
    ) internal {
        if (tokenRedeemer != address(0)) {
            basin.addTokenRedeemer(tokenRedeemer);
        }

        basin.grantRole(basin.MANAGER_ROLE(), Ethereum.ALM_RELAYER);
        basin.grantRole(basin.PAUSER_ROLE(),  Ethereum.ALM_FREEZER);

        if (issuerRedeemer != address(0)) {
            basin.grantRole(basin.REDEEMER_ROLE(), issuerRedeemer);
        } else {
            console.log("issuerRedeemer is not set, skipping REDEEMER_ROLE grant");
        }

        basin.grantRole(basin.PAUSER_ROLE(), deployer);

        basin.setPaused(basin.PAUSED_SWAP_SWAP_TO_CREDIT());
        basin.setPaused(basin.PAUSED_SWAP_COLLATERAL_TO_CREDIT());

        basin.setFeeBounds(0, 500);

        basin.revokeRole(basin.PAUSER_ROLE(), deployer);

        basin.grantRole(basin.OWNER_ROLE(),  adminTimelock);
        basin.revokeRole(basin.OWNER_ROLE(), deployer);
    }

}
