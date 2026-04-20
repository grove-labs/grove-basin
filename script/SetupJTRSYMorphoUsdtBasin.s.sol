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

contract SetupJTRSYMorphoUsdtBasin is Script {

    using SafeERC20 for IERC20;

    address constant USDT_CHRONICLE_RATE_PROVIDER      = 0x41F16493Cac5d7818301C73CdecF4cE37CC5fe5C;  // USDT ChronicleRateProvider
    address constant USDC_CHRONICLE_RATE_PROVIDER      = 0xE6305390428FD82eB437b50375b95B9550B90256;  // Fixed 1:1 ChronicleRateProvider for USDC
    address constant JTRSY_CHRONICLE_RATE_PROVIDER     = 0xdBCF3230ff0dbd62BE38956d1aAA845e97126Fe5;  // JTRSY ChronicleRateProvider
    address constant MORPHO_STEAKHOUSE_USDT_VAULT      = 0xbEef047a543E45807105E51A8BBEFCc5950fcfBa;  // Morpho Steakhouse USDT Vault
    address constant JTRSY_TOKEN                       = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;  // JTRSY share token (6 decimals)

    function run() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

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

        GroveBasinFactory factory = new GroveBasinFactory();

        uint256 seedAmount = 10 ** IERC20(Ethereum.USDT).decimals();
        IERC20(Ethereum.USDT).safeApprove(address(factory), seedAmount);

        groveBasin = factory.deploy({
            owner                       : deployer,
            liquidityProvider           : Ethereum.ALM_PROXY,
            swapToken                   : Ethereum.USDT,
            collateralToken             : Ethereum.USDC,
            creditToken                 : JTRSY_TOKEN,
            swapTokenRateProvider       : USDT_CHRONICLE_RATE_PROVIDER,
            collateralTokenRateProvider : USDC_CHRONICLE_RATE_PROVIDER,
            creditTokenRateProvider     : JTRSY_CHRONICLE_RATE_PROVIDER
        });

        GroveBasin(groveBasin).grantRole(GroveBasin(groveBasin).MANAGER_ADMIN_ROLE(), deployer);

        MorphoUsdtPocket pocket = new MorphoUsdtPocket(
            groveBasin,
            Ethereum.USDT,
            MORPHO_STEAKHOUSE_USDT_VAULT
        );

        GroveBasin(groveBasin).setPocket(address(pocket));

        JTRSYTokenRedeemer redeemer = new JTRSYTokenRedeemer(
            JTRSY_TOKEN,
            Ethereum.CENTRIFUGE_JTRSY,
            groveBasin
        );

        GroveBasin(groveBasin).addTokenRedeemer(address(redeemer));

        GroveBasin(groveBasin).grantRole(GroveBasin(groveBasin).MANAGER_ROLE(), Ethereum.ALM_RELAYER);

        pocket_   = address(pocket);
        redeemer_ = address(redeemer);
    }

}
