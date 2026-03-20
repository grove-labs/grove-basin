// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { JTRSYTokenRedeemer }  from "src/JTRSYTokenRedeemer.sol";
import { UsdsUsdcPocket }      from "src/pockets/UsdsUsdcPocket.sol";
import { GroveBasinDeploy }    from "deploy/GroveBasinDeploy.sol";

contract SetupJTRSYUsdsUsdcBasin is Script {

    function run() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        console.log("Deploying GroveBasin with JTRSYTokenRedeemer and UsdsUsdcPocket...");

        vm.startBroadcast();

        address groveBasin = GroveBasinDeploy.deploy({
            owner                       : msg.sender,
            swapToken                   : Ethereum.USDS,
            collateralToken             : Ethereum.USDC,
            creditToken                 : Ethereum.SUSDS,
            swapTokenRateProvider       : address(0), // TODO: set up rate provider
            collateralTokenRateProvider : address(0), // TODO: set up rate provider
            creditTokenRateProvider     : address(0)  // TODO: set up rate provider
        });

        GroveBasin(groveBasin).grantRole(GroveBasin(groveBasin).MANAGER_ADMIN_ROLE(), msg.sender);

        UsdsUsdcPocket pocket = new UsdsUsdcPocket(
            groveBasin,
            Ethereum.USDC,
            Ethereum.USDS,
            Ethereum.PSM,
            Ethereum.GROVE_PROXY
        );

        GroveBasin(groveBasin).setPocket(address(pocket));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(
            Ethereum.SUSDS,
            Ethereum.CENTRIFUGE_JTRSY,
            groveBasin
        );

        GroveBasin(groveBasin).addTokenRedeemer(address(redeemer));

        GroveBasin(groveBasin).grantRole(GroveBasin(groveBasin).MANAGER_ROLE(),            Ethereum.ALM_RELAYER);
        GroveBasin(groveBasin).grantRole(GroveBasin(groveBasin).LIQUIDITY_PROVIDER_ROLE(), Ethereum.ALM_PROXY);

        vm.stopBroadcast();

        console.log("GroveBasin deployed at:",          groveBasin);
        console.log("UsdsUsdcPocket deployed at:",      address(pocket));
        console.log("JTRSYTokenRedeemer deployed at:",  address(redeemer));
    }

}
