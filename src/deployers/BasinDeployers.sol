// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import { GroveBasin } from "src/GroveBasin.sol";

import { UsdsUsdcPocket }   from "src/pockets/UsdsUsdcPocket.sol";
import { MorphoUsdtPocket } from "src/pockets/MorphoUsdtPocket.sol";
import { AaveV3UsdtPocket } from "src/pockets/AaveV3UsdtPocket.sol";

import { BUIDLTokenRedeemer } from "src/redeemers/BUIDLTokenRedeemer.sol";

/**
 * @dev These libraries exist only to keep `GroveBasinFactory` under the EIP-170 contract size
 *      limit. Each `new X(...)` embeds X's full creation code into the bytecode of whatever
 *      holds the `new` expression. Embedding the GroveBasin, all three pockets, the redeemer,
 *      and the timelock creation codes in the factory would far exceed 24,576 bytes, so each is
 *      moved into an external library. External library functions are invoked via `delegatecall`,
 *      meaning `address(this)` and `msg.sender` are still the factory: CREATE2 addresses and seed
 *      transfers behave exactly as if the `new` ran inline.
 */

library GroveBasinDeployer {

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
        external returns (address)
    {
        return address(new GroveBasin{salt: salt}({
            owner_                       : owner,
            liquidityProvider_           : liquidityProvider,
            swapToken_                   : swapToken,
            collateralToken_             : collateralToken,
            creditToken_                 : creditToken,
            swapTokenRateProvider_       : swapTokenRateProvider,
            collateralTokenRateProvider_ : collateralTokenRateProvider,
            creditTokenRateProvider_     : creditTokenRateProvider
        }));
    }

}

library PocketDeployer {

    function deployUsdsUsdc(address basin, address usdc, address usds, address psm, address groveProxy)
        external returns (address)
    {
        return address(new UsdsUsdcPocket({
            basin_      : basin,
            usdc_       : usdc,
            usds_       : usds,
            psm_        : psm,
            groveProxy_ : groveProxy
        }));
    }

    function deployMorphoUsdt(address basin, address usdt, address vault) external returns (address) {
        return address(new MorphoUsdtPocket({
            basin_ : basin,
            usdt_  : usdt,
            vault_ : vault
        }));
    }

    function deployAaveUsdt(address basin, address usdt, address aUsdt, address aaveV3Pool)
        external returns (address)
    {
        return address(new AaveV3UsdtPocket({
            basin_      : basin,
            usdt_       : usdt,
            aUsdt_      : aUsdt,
            aaveV3Pool_ : aaveV3Pool
        }));
    }

}

library RedeemerDeployer {

    function deployBuidl(address creditToken, address redemptionAddress, address basin)
        external returns (address)
    {
        return address(new BUIDLTokenRedeemer({
            creditToken_       : creditToken,
            redemptionAddress_ : redemptionAddress,
            basin_             : basin
        }));
    }

}

library TimelockDeployer {

    function deploy(uint256 minDelay, address proposer, address executor, address admin, address canceller)
        external returns (address)
    {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        TimelockController timelock = new TimelockController({
            minDelay  : minDelay,
            proposers : proposers,
            executors : executors,
            admin     : admin
        });

        // Constructor grants CANCELLER_ROLE to proposers by default; also grant it to the canceller.
        timelock.grantRole(timelock.CANCELLER_ROLE(), canceller);

        // The factory only needs DEFAULT_ADMIN_ROLE for the grant above; renounce it so the
        // timelock is self-administered and no deployer-side admin remains.
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), admin);

        return address(timelock);
    }

}
