// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }         from "src/GroveBasin.sol";
import { GroveBasinFactory }  from "src/GroveBasinFactory.sol";
import { JTRSYTokenRedeemer } from "src/redeemers/JTRSYTokenRedeemer.sol";
import { UsdsUsdcPocket }     from "src/pockets/UsdsUsdcPocket.sol";

import { BasinSetup } from "script/lib/BasinSetup.sol";

contract SetupJTRSYUsdsUsdcBasin is Script {

    address constant USDS_USDC_FIXED_RATE_PROVIDER = 0x7928A185B8137D1CD2a0996a810A04dB2837419D;  // Fixed 1:1 ChronicleRateProvider for USDS and USDC
    address constant JTRSY_CHRONICLE_RATE_PROVIDER = 0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5;
    address constant JTRSY_TOKEN                   = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address constant USDS_PSM_WRAPPER              = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address constant GROVE_BASIN_FACTORY           = 0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a;
    address constant JTRSY_ADMIN_TIMELOCK          = 0xA52dC9876aB4A9DB6dAfbb83410554086054d140;
    address constant JTRSY_REDEEMER_ADDRESS        = 0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a;

    function run() external {
        vm.startBroadcast();
        (address groveBasin, address pocket_, address redeemer_) = deploy();
        vm.stopBroadcast();

        console.log("GroveBasin deployed at:",         groveBasin);
        console.log("UsdsUsdcPocket deployed at:",     pocket_);
        console.log("JTRSYTokenRedeemer deployed at:", redeemer_);
    }

    function deploy() public returns (address groveBasin, address pocket_, address redeemer_) {
        address deployer = vm.envAddress("DEPLOYER");

        require(IERC20(Ethereum.USDS).balanceOf(msg.sender) >= 10 ** IERC20(Ethereum.USDS).decimals(), "insufficient-usds-balance");

        GroveBasinFactory factory = GroveBasinFactory(GROVE_BASIN_FACTORY);

        uint256 seedAmount = 10 ** IERC20(Ethereum.USDS).decimals();
        IERC20(Ethereum.USDS).approve(address(factory), seedAmount);

        groveBasin = factory.deploy({
            owner                       : deployer,
            liquidityProvider           : Ethereum.ALM_PROXY,
            swapToken                   : Ethereum.USDS,
            collateralToken             : Ethereum.USDC,
            creditToken                 : JTRSY_TOKEN,
            swapTokenRateProvider       : USDS_USDC_FIXED_RATE_PROVIDER,
            collateralTokenRateProvider : USDS_USDC_FIXED_RATE_PROVIDER,
            creditTokenRateProvider     : JTRSY_CHRONICLE_RATE_PROVIDER
        });

        GroveBasin basin = GroveBasin(groveBasin);

        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY);
        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), deployer);

        UsdsUsdcPocket pocket = new UsdsUsdcPocket(
            groveBasin,
            Ethereum.USDC,
            Ethereum.USDS,
            USDS_PSM_WRAPPER,
            Ethereum.GROVE_PROXY
        );

        basin.setPocket(address(pocket));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(
            JTRSY_TOKEN,
            Ethereum.CENTRIFUGE_JTRSY,
            groveBasin
        );

        basin.addTokenRedeemer(address(redeemer));

        BasinSetup.performBasinInit({
            basin          : basin,
            deployer       : deployer,
            issuerRedeemer : JTRSY_REDEEMER_ADDRESS,
            adminTimelock  : JTRSY_ADMIN_TIMELOCK
        });

        pocket_   = address(pocket);
        redeemer_ = address(redeemer);
    }

}
