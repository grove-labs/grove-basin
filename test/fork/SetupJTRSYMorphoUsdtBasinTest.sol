// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }                from "src/GroveBasin.sol";
import { MorphoUsdtPocket }          from "src/pockets/MorphoUsdtPocket.sol";
import { JTRSYTokenRedeemer }        from "src/redeemers/JTRSYTokenRedeemer.sol";
import { SetupJTRSYMorphoUsdtBasin } from "script/SetupJTRSYMorphoUsdtBasin.s.sol";

contract SetupJTRSYMorphoUsdtBasinTest is Test, SetupJTRSYMorphoUsdtBasin {

    GroveBasin         public groveBasin;
    MorphoUsdtPocket   public pocket;
    JTRSYTokenRedeemer public redeemer;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        _mockRateProvider(USDT_CHRONICLE_RATE_PROVIDER,  1e27);
        _mockRateProvider(USDC_CHRONICLE_RATE_PROVIDER,  1e27);
        _mockRateProvider(JTRSY_CHRONICLE_RATE_PROVIDER, 1.05e27);

        deal(Ethereum.USDT, address(this), 1e6);

        (address groveBasin_, address pocket_, address redeemer_) = this.deploy();

        groveBasin = GroveBasin(groveBasin_);
        pocket     = MorphoUsdtPocket(pocket_);
        redeemer   = JTRSYTokenRedeemer(redeemer_);
    }

    function _mockRateProvider(address provider, uint256 rate) internal {
        vm.mockCall(provider, abi.encodeWithSignature("getConversionRate()"),        abi.encode(rate));
        vm.mockCall(provider, abi.encodeWithSignature("getConversionRateWithAge()"), abi.encode(rate, block.timestamp));
    }

    function test_deploy_basinTokens() public view {
        assertEq(groveBasin.swapToken(),       Ethereum.USDT);
        assertEq(groveBasin.collateralToken(), Ethereum.USDC);
        assertEq(groveBasin.creditToken(),     Ethereum.SUSDS);
    }

    function test_deploy_rateProviders() public view {
        assertEq(groveBasin.swapTokenRateProvider(),       USDT_CHRONICLE_RATE_PROVIDER);
        assertEq(groveBasin.collateralTokenRateProvider(), USDC_CHRONICLE_RATE_PROVIDER);
        assertEq(groveBasin.creditTokenRateProvider(),     JTRSY_CHRONICLE_RATE_PROVIDER);
    }

    function test_deploy_pocket() public view {
        assertEq(groveBasin.pocket(),    address(pocket));
        assertEq(address(pocket.usdt()), Ethereum.USDT);
        assertEq(pocket.vault(),         MORPHO_STEAKHOUSE_USDT_VAULT);
    }

    function test_deploy_redeemer() public view {
        assertEq(redeemer.creditToken(),    Ethereum.SUSDS);
        assertEq(redeemer.vault(),          Ethereum.CENTRIFUGE_JTRSY);
        assertEq(address(redeemer.basin()), address(groveBasin));
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), address(redeemer)));
    }

    function test_deploy_roles() public view {
        assertTrue(groveBasin.hasRole(groveBasin.OWNER_ROLE(),              address(this)));
        assertTrue(groveBasin.hasRole(groveBasin.MANAGER_ADMIN_ROLE(),      address(this)));
        assertTrue(groveBasin.hasRole(groveBasin.MANAGER_ROLE(),            Ethereum.ALM_RELAYER));
        assertEq(groveBasin.liquidityProvider(), Ethereum.ALM_PROXY);
    }

    function test_deploy_initialShares() public view {
        assertEq(groveBasin.totalShares(),      1e18);
        assertEq(groveBasin.shares(address(0)), 1e18);
    }

}
