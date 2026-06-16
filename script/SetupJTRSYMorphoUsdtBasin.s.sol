// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { GroveBasinFactory }   from "src/GroveBasinFactory.sol";
import { JTRSYTokenRedeemer }  from "src/redeemers/JTRSYTokenRedeemer.sol";
import { MorphoUsdtPocket }    from "src/pockets/MorphoUsdtPocket.sol";

import { BasinSetup } from "script/lib/BasinSetup.sol";

contract SetupJTRSYMorphoUsdtBasin is Script {

    using SafeERC20 for IERC20;

    address constant USDT_CHRONICLE_RATE_PROVIDER      = 0x7928A185B8137D1CD2a0996a810A04dB2837419D; // Fixed 1:1 ChronicleRateProvider 
    address constant USDC_CHRONICLE_RATE_PROVIDER      = 0x7928A185B8137D1CD2a0996a810A04dB2837419D; // Fixed 1:1 ChronicleRateProvider
    address constant JTRSY_CHRONICLE_RATE_PROVIDER     = 0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5;
    address constant MORPHO_STEAKHOUSE_USDT_VAULT      = 0xbEef047a543E45807105E51A8BBEFCc5950fcfBa;
    address constant JTRSY_TOKEN                       = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address constant GROVE_BASIN_FACTORY               = 0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a;
    address constant JTRSY_ADMIN_TIMELOCK              = 0xA52dC9876aB4A9DB6dAfbb83410554086054d140;
    address constant JTRSY_REDEEMER_ADDRESS            = 0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a;

    function run() external {
        vm.startBroadcast();
        (address groveBasin, address pocket_, address redeemer_) = deploy();
        vm.stopBroadcast();

        console.log("GroveBasin deployed at:",          groveBasin);
        console.log("MorphoUsdtPocket deployed at:",    pocket_);
        console.log("JTRSYTokenRedeemer deployed at:",  redeemer_);
    }

    function deploy() public returns (address groveBasin, address pocket_, address redeemer_) {
        address deployer = vm.envAddress("DEPLOYER");

        require(IERC20(Ethereum.USDT).balanceOf(deployer) >= 1e6, "insufficient-usdt-balance");

        GroveBasinFactory factory = GroveBasinFactory(GROVE_BASIN_FACTORY);

        uint256 seedAmount = 10 ** IERC20(Ethereum.USDT).decimals();
        IERC20(Ethereum.USDT).safeApprove(address(factory), seedAmount);

        groveBasin = factory.deploy({
            owner                       : deployer,
            liquidityProvider           : BasinSetup.DPAU_ALM_PROXY,
            swapToken                   : Ethereum.USDT,
            collateralToken             : Ethereum.USDC,
            creditToken                 : JTRSY_TOKEN,
            swapTokenRateProvider       : USDT_CHRONICLE_RATE_PROVIDER,
            collateralTokenRateProvider : USDC_CHRONICLE_RATE_PROVIDER,
            creditTokenRateProvider     : JTRSY_CHRONICLE_RATE_PROVIDER
        });

        GroveBasin basin = GroveBasin(groveBasin);

        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY);
        basin.grantRole(basin.MANAGER_ADMIN_ROLE(), deployer);

        MorphoUsdtPocket pocket = new MorphoUsdtPocket(
            groveBasin,
            Ethereum.USDT,
            MORPHO_STEAKHOUSE_USDT_VAULT
        );

        basin.setPocket(address(pocket));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(
            JTRSY_TOKEN,
            Ethereum.CENTRIFUGE_JTRSY,
            groveBasin
        );

        BasinSetup.performBasinInit({
            basin          : basin,
            deployer       : deployer,
            tokenRedeemer  : address(redeemer),
            issuerRedeemer : JTRSY_REDEEMER_ADDRESS,
            adminTimelock  : JTRSY_ADMIN_TIMELOCK
        });

        pocket_   = address(pocket);
        redeemer_ = address(redeemer);
    }

}
