// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }         from "src/GroveBasin.sol";
import { GroveBasinFactory }  from "src/GroveBasinFactory.sol";
import { BUIDLTokenRedeemer } from "src/redeemers/BUIDLTokenRedeemer.sol";

import { BasinSetup } from "script/lib/BasinSetup.sol";

contract SetupBUIDLUsdsUsdcBasin is Script {

    address constant USDS_USDC_FIXED_RATE_PROVIDER = 0x7928A185B8137D1CD2a0996a810A04dB2837419D;  // Fixed 1:1 ChronicleRateProvider for USDS and USDC
    address constant BUIDL_CHRONICLE_RATE_PROVIDER = 0x69a171853575FFD41574EA80Abfc6337AcbC4d43;
    address constant USDS_PSM_WRAPPER              = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address constant GROVE_BASIN_FACTORY           = 0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a;
    address constant BUIDL_ADMIN_TIMELOCK          = 0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34;
    address constant BUIDL_TOKEN                   = 0x7712c34205737192402172409a8F7ccef8aA2AEc;
    address constant SECURITIZE_REDEEMER_ADDRESS   = 0xdfC603076EA75895DD4d59c6e2ee5038f881CB74;
    address constant BUIDL_REDEMPTION_ADDRESS      = 0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052;

    function run() external {
        vm.startBroadcast();
        (address groveBasin, address pocket_) = deploy();
        vm.stopBroadcast();

        console.log("GroveBasin deployed at:",          groveBasin);
        console.log("UsdsUsdcPocket deployed at:",      pocket_);
    }

    function deployRedeemerContractAndGrantRedeemerRole(address groveBasin) external {
        vm.startBroadcast();
        GroveBasin basin = GroveBasin(groveBasin);

        if (BUIDL_REDEMPTION_ADDRESS != address(0)) {
            BUIDLTokenRedeemer redeemer = new BUIDLTokenRedeemer(
                BUIDL_TOKEN,
                BUIDL_REDEMPTION_ADDRESS,
                groveBasin
            );

            basin.addTokenRedeemer(address(redeemer));

            console.log("BUIDLTokenRedeemer deployed at: %s with redemption address: %s", address(redeemer), BUIDL_REDEMPTION_ADDRESS);
        } else {
            console.log("BUIDL_REDEMPTION_ADDRESS is not set, skipping BUIDLTokenRedeemer deployment");
        }

        if (SECURITIZE_REDEEMER_ADDRESS != address(0)) {
            basin.grantRole(basin.REDEEMER_ROLE(), SECURITIZE_REDEEMER_ADDRESS);

            console.log("Granted redeemer role: ", SECURITIZE_REDEEMER_ADDRESS);
        } else {
            console.log("SECURITIZE_REDEEMER_ADDRESS is not set, skipping grant redeemer role to SECURITIZE_REDEEMER_ADDRESS");
        }
        vm.stopBroadcast();
    }

    function deploy() public returns (address groveBasin, address pocket_) {
        address deployer = vm.envAddress("DEPLOYER");

        GroveBasinFactory factory = BasinSetup.approveFactoryForSeeding(GROVE_BASIN_FACTORY);

        groveBasin = BasinSetup.deployUsdsUsdcBasin({
            factory                 : factory,
            deployer                : deployer,
            creditToken             : BUIDL_TOKEN,
            creditTokenRateProvider : BUIDL_CHRONICLE_RATE_PROVIDER,
            fixedRateProvider       : USDS_USDC_FIXED_RATE_PROVIDER
        });

        GroveBasin basin = GroveBasin(groveBasin);

        pocket_ = BasinSetup.grantManagerAdminAndDeployPocket({
            basin          : basin,
            deployer       : deployer,
            usdsPsmWrapper : USDS_PSM_WRAPPER
        });

        address tokenRedeemer;
        if (BUIDL_REDEMPTION_ADDRESS != address(0)) {
            tokenRedeemer = address(new BUIDLTokenRedeemer(
                BUIDL_TOKEN,
                BUIDL_REDEMPTION_ADDRESS,
                groveBasin
            ));
        } else {
            console.log("BUIDL_REDEMPTION_ADDRESS is not set, skipping BUIDLTokenRedeemer deployment");
        }

        BasinSetup.performBasinInit({
            basin          : basin,
            deployer       : deployer,
            tokenRedeemer  : tokenRedeemer,
            issuerRedeemer : SECURITIZE_REDEEMER_ADDRESS,
            adminTimelock  : BUIDL_ADMIN_TIMELOCK
        });
    }

}
