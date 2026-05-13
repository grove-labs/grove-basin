// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }          from "src/GroveBasin.sol";
import { GroveBasinFactory }   from "src/GroveBasinFactory.sol";
import { BUIDLTokenRedeemer }  from "src/redeemers/BUIDLTokenRedeemer.sol";
import { UsdsUsdcPocket }      from "src/pockets/UsdsUsdcPocket.sol";

contract SetupBUIDLUsdsUsdcBasin is Script {

    address constant USDS_USDC_FIXED_RATE_PROVIDER = 0x7928A185B8137D1CD2a0996a810A04dB2837419D;  // Fixed 1:1 ChronicleRateProvider for USDS and USDC
    address constant BUIDL_CHRONICLE_RATE_PROVIDER     = 0x69a171853575FFD41574EA80Abfc6337AcbC4d43;  // BUIDL ChronicleRateProvider
    address constant USDS_PSM_WRAPPER                  = 0xA188EEC8F81263234dA3622A406892F3D630f98c;  // USDS PSM Wrapper
    address constant GROVE_BASIN_FACTORY               = 0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a;  // GroveBasinFactory
    address constant BUIDL_ADMIN_TIMELOCK              = 0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34;  // BUIDL Admin TimelockController
    address constant BUIDL_TOKEN                       = 0x7712c34205737192402172409a8F7ccef8aA2AEc;  // BUIDL (note: not BUIDLI)
    address constant SECURITIZE_REDEEMER_ADDRESS       = 0xdfC603076EA75895DD4d59c6e2ee5038f881CB74;  // Securitize redeemer address
    address constant BUIDL_REDEMPTION_ADDRESS          = 0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052;  // Set BUIDL primary redemption Address

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

        require(IERC20(Ethereum.USDS).balanceOf(msg.sender) >= 10 ** IERC20(Ethereum.USDS).decimals(), "insufficient-usds-balance");

        GroveBasinFactory factory = GroveBasinFactory(GROVE_BASIN_FACTORY);

        uint256 seedAmount = 10 ** IERC20(Ethereum.USDS).decimals();
        IERC20(Ethereum.USDS).approve(address(factory), seedAmount);

        groveBasin = factory.deploy({
            owner                       : deployer,
            liquidityProvider           : Ethereum.ALM_PROXY,
            swapToken                   : Ethereum.USDS,
            collateralToken             : Ethereum.USDC,
            creditToken                 : BUIDL_TOKEN,
            swapTokenRateProvider       : USDS_USDC_FIXED_RATE_PROVIDER,
            collateralTokenRateProvider : USDS_USDC_FIXED_RATE_PROVIDER,
            creditTokenRateProvider     : BUIDL_CHRONICLE_RATE_PROVIDER
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

        if (BUIDL_REDEMPTION_ADDRESS != address(0)) {
            BUIDLTokenRedeemer redeemer = new BUIDLTokenRedeemer(
                BUIDL_TOKEN,
                BUIDL_REDEMPTION_ADDRESS,
                groveBasin
            );

            basin.addTokenRedeemer(address(redeemer));
        } else {
            console.log("BUIDL_REDEMPTION_ADDRESS is not set, skipping BUIDLTokenRedeemer deployment");
        }

        basin.grantRole(basin.MANAGER_ROLE(),  Ethereum.ALM_RELAYER);
        basin.grantRole(basin.PAUSER_ROLE(),   Ethereum.ALM_FREEZER);

        if (SECURITIZE_REDEEMER_ADDRESS != address(0)) {
            basin.grantRole(basin.REDEEMER_ROLE(), SECURITIZE_REDEEMER_ADDRESS);
        } else {
            console.log("SECURITIZE_REDEEMER_ADDRESS is not set, skipping grant redeemer role to SECURITIZE_REDEEMER_ADDRESS");
        }

        basin.grantRole(basin.PAUSER_ROLE(), deployer);

        basin.setPaused(basin.PAUSED_SWAP_SWAP_TO_CREDIT());
        basin.setPaused(basin.PAUSED_SWAP_COLLATERAL_TO_CREDIT());
        basin.setPaused(basin.PAUSED_DEPOSIT_CREDIT());
        basin.setPaused(basin.PAUSED_WITHDRAW_CREDIT());

        basin.setFeeBounds(0, 500);

        basin.revokeRole(basin.PAUSER_ROLE(), deployer);

        basin.grantRole(basin.OWNER_ROLE(),  BUIDL_ADMIN_TIMELOCK);
        basin.revokeRole(basin.OWNER_ROLE(), deployer);

        pocket_ = address(pocket);
    }

}
