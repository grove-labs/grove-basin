// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { GroveBasinFactory }   from "src/GroveBasinFactory.sol";
import { JTRSYTokenRedeemer }  from "src/redeemers/JTRSYTokenRedeemer.sol";
import { UsdsUsdcPocket }      from "src/pockets/UsdsUsdcPocket.sol";

contract SetupJTRSYUsdsUsdcBasin is Script {

    address constant USDS_USDC_CHRONICLE_RATE_PROVIDER = 0xE6305390428FD82eB437b50375b95B9550B90256;  // Fixed 1:1 ChronicleRateProvider for USDS and USDC
    address constant JTRSY_CHRONICLE_RATE_PROVIDER     = 0xdBCF3230ff0dbd62BE38956d1aAA845e97126Fe5;  // JTRSY ChronicleRateProvider

    function run() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        vm.startBroadcast();
        (address groveBasin, address pocket_, address redeemer_) = deploy();
        vm.stopBroadcast();

        console.log("GroveBasin deployed at:",         groveBasin);
        console.log("UsdsUsdcPocket deployed at:",     pocket_);
        console.log("JTRSYTokenRedeemer deployed at:", redeemer_);
    }

    function deploy() public returns (address groveBasin, address pocket_, address redeemer_) {
        require(IERC20(Ethereum.USDS).balanceOf(msg.sender) >= 1e18, "insufficient-usds-balance");

        GroveBasinFactory factory = new GroveBasinFactory();

        uint256 seedAmount = 10 ** IERC20(Ethereum.USDS).decimals();
        IERC20(Ethereum.USDS).approve(address(factory), seedAmount);

        groveBasin = factory.deploy({
            owner                       : msg.sender,
            liquidityProvider           : Ethereum.ALM_PROXY,
            swapToken                   : Ethereum.USDS,
            collateralToken             : Ethereum.USDC,
            creditToken                 : Ethereum.SUSDS,
            swapTokenRateProvider       : USDS_USDC_CHRONICLE_RATE_PROVIDER,
            collateralTokenRateProvider : USDS_USDC_CHRONICLE_RATE_PROVIDER,
            creditTokenRateProvider     : JTRSY_CHRONICLE_RATE_PROVIDER
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

        GroveBasin(groveBasin).grantRole(GroveBasin(groveBasin).MANAGER_ROLE(), Ethereum.ALM_RELAYER);

        pocket_   = address(pocket);
        redeemer_ = address(redeemer);
    }

}
