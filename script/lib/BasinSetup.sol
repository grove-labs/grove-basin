// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin } from "src/GroveBasin.sol";

library BasinSetup {

    /// @notice Universal post-deployment configuration sequence shared by GroveBasin setup
    ///         scripts: grant operational roles, pause credit-side flows, set fee bounds, and
    ///         hand ownership over to the admin timelock.
    /// @param  basin           The freshly deployed GroveBasin (pocket and any token redeemer
    ///                         must already be wired up by the caller).
    /// @param  deployer        The deploying EOA. Must currently hold OWNER_ROLE and
    ///                         MANAGER_ADMIN_ROLE on `basin`.
    /// @param  issuerRedeemer  Address granted REDEEMER_ROLE. Pass address(0) to skip.
    /// @param  adminTimelock   The admin timelock receiving OWNER_ROLE.
    function performBasinInit(
        GroveBasin basin,
        address    deployer,
        address    issuerRedeemer,
        address    adminTimelock
    ) internal {
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
        basin.setPaused(basin.PAUSED_DEPOSIT_CREDIT());
        basin.setPaused(basin.PAUSED_WITHDRAW_CREDIT());

        basin.setFeeBounds(0, 500);

        basin.revokeRole(basin.PAUSER_ROLE(), deployer);

        basin.grantRole(basin.OWNER_ROLE(),  adminTimelock);
        basin.revokeRole(basin.OWNER_ROLE(), deployer);
    }

}
