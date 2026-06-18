// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";
import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import { GroveBasin }         from "src/GroveBasin.sol";
import { GroveBasinFactory }  from "src/GroveBasinFactory.sol";
import { BUIDLTokenRedeemer } from "src/redeemers/BUIDLTokenRedeemer.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAToken }       from "test/mocks/MockAToken.sol";

contract GroveBasinFactorySetupForkTest is Test {

    using SafeERC20 for IERC20;

    address constant DPAU_ALM_PROXY = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;

    GroveBasinFactory factory;

    MockERC20        creditToken;
    MockRateProvider rateProvider;
    MockAToken       aUsdt;

    address adminTimelock = makeAddr("adminTimelock");
    address proposer      = makeAddr("proposer");
    address issuer        = makeAddr("issuer");
    address psm           = makeAddr("psm");
    address morphoVault   = makeAddr("morphoVault");
    address aaveV3Pool    = makeAddr("aaveV3Pool");
    address redemption    = makeAddr("redemption");

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 24_522_338);

        factory      = new GroveBasinFactory();
        creditToken  = new MockERC20("credit", "credit", 18);
        rateProvider = new MockRateProvider();
        rateProvider.__setConversionRate(1e27);
        aUsdt = new MockAToken("aUSDT", "aUSDT", 6, Ethereum.USDT);
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _seed(address swapToken) internal {
        uint256 seedAmount = 10 ** IERC20(swapToken).decimals();
        deal(swapToken, address(this), seedAmount);
        IERC20(swapToken).safeApprove(address(factory), seedAmount);
    }

    function _baseParams(GroveBasinFactory.PocketType pocketType)
        internal
        view
        returns (GroveBasinFactory.DeployParams memory params)
    {
        bool isUsds = pocketType == GroveBasinFactory.PocketType.UsdsUsdc;

        params = GroveBasinFactory.DeployParams({
            salt                        : bytes32(uint256(1)),
            swapToken                   : isUsds ? Ethereum.USDS : Ethereum.USDT,
            collateralToken             : Ethereum.USDC,
            creditToken                 : address(creditToken),
            swapTokenRateProvider       : address(rateProvider),
            collateralTokenRateProvider : address(rateProvider),
            creditTokenRateProvider     : address(rateProvider),
            pocketType                  : pocketType,
            pocketAddress1              : isUsds ? psm : (pocketType == GroveBasinFactory.PocketType.MorphoUsdt ? morphoVault : address(aUsdt)),
            pocketAddress2              : pocketType == GroveBasinFactory.PocketType.AaveUsdt ? aaveV3Pool : address(0),
            deployBuidlRedeemer         : false,
            buidlRedemptionAddress      : address(0),
            tokenRedeemer               : address(0),
            issuerRedeemer              : address(0)
        });
    }

    function _assertCommonConfig(GroveBasin basin, address pocket, address expectedOwner) internal view {
        // Liquidity provider is the hardcoded DPAU ALM Proxy.
        assertEq(basin.liquidityProvider(), DPAU_ALM_PROXY);

        // Pocket wired up and is not the basin itself.
        assertEq(basin.pocket(), pocket);
        assertTrue(pocket != address(basin));

        // Ownership handed to the admin timelock; factory and deployer (this) hold nothing.
        assertTrue(basin.hasRole(basin.OWNER_ROLE(), expectedOwner));
        assertFalse(basin.hasRole(basin.OWNER_ROLE(), address(factory)));
        assertFalse(basin.hasRole(basin.OWNER_ROLE(), address(this)));

        // GROVE_PROXY keeps MANAGER_ADMIN_ROLE; factory and deployer must not.
        assertTrue(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY));
        assertFalse(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), address(factory)));
        assertFalse(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), address(this)));

        // Operational roles.
        assertTrue(basin.hasRole(basin.MANAGER_ROLE(), Ethereum.ALM_RELAYER));
        assertTrue(basin.hasRole(basin.PAUSER_ROLE(), Ethereum.ALM_FREEZER));
        assertFalse(basin.hasRole(basin.PAUSER_ROLE(), address(factory)));

        // Pause flags.
        assertTrue(basin.paused(basin.PAUSED_SWAP_SWAP_TO_CREDIT()));
        assertTrue(basin.paused(basin.PAUSED_SWAP_COLLATERAL_TO_CREDIT()));
        assertTrue(basin.paused(basin.PAUSED_DEPOSIT_CREDIT()));
        assertTrue(basin.paused(basin.PAUSED_WITHDRAW_CREDIT()));
        assertFalse(basin.paused(basin.PAUSED_SWAP_CREDIT_TO_COLLATERAL()));
        assertFalse(basin.paused(basin.PAUSED_SWAP_CREDIT_TO_SWAP()));

        // Fee bounds and seed.
        assertEq(basin.minFee(), 0);
        assertEq(basin.maxFee(), 500);
        assertEq(basin.totalShares(),      1e18);
        assertEq(basin.shares(address(0)), 1e18);
    }

    /**********************************************************************************************/
    /*** Happy paths                                                                            ***/
    /**********************************************************************************************/

    function test_deploy_usdsUsdc_withBuidlRedeemer() public {
        _seed(Ethereum.USDS);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.deployBuidlRedeemer    = true;
        params.buidlRedemptionAddress = redemption;
        params.issuerRedeemer         = issuer;

        (address basin, address pocket, address redeemer) = factory.deploy(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(),       Ethereum.USDS);
        assertEq(groveBasin.collateralToken(), Ethereum.USDC);
        assertEq(groveBasin.creditToken(),     address(creditToken));

        _assertCommonConfig(groveBasin, pocket, adminTimelock);

        // BUIDL redeemer deployed and registered, issuer granted REDEEMER_ROLE.
        assertTrue(redeemer != address(0));
        assertEq(BUIDLTokenRedeemer(redeemer).creditToken(), address(creditToken));
        assertEq(address(BUIDLTokenRedeemer(redeemer).basin()), basin);
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), redeemer));
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(),          issuer));
    }

    function test_deploy_morphoUsdt_withExternalRedeemer() public {
        _seed(Ethereum.USDT);

        address externalRedeemer = address(new MockTokenRedeemer());

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.tokenRedeemer  = externalRedeemer;
        params.issuerRedeemer = issuer;

        (address basin, address pocket, address redeemer) = factory.deploy(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(), Ethereum.USDT);

        _assertCommonConfig(groveBasin, pocket, adminTimelock);

        // The pre-deployed redeemer address is registered as-is.
        assertEq(redeemer, externalRedeemer);
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), externalRedeemer));
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(),          issuer));
    }

    function test_deploy_aaveUsdt_withoutRedeemer() public {
        _seed(Ethereum.USDT);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.AaveUsdt);

        (address basin, address pocket, address redeemer) = factory.deploy(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(), Ethereum.USDT);

        _assertCommonConfig(groveBasin, pocket, adminTimelock);

        // No token redeemer registered, no issuer granted.
        assertEq(redeemer, address(0));
        assertFalse(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), address(0)));
        assertFalse(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(), issuer));
    }

    function test_deployWithTimelock_deploysAndOwnsBasin() public {
        _seed(Ethereum.USDT);

        uint256 minDelay = 7 days;

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.issuerRedeemer = issuer;

        (address basin, address pocket, , address timelock) =
            factory.deployWithTimelock(params, proposer, minDelay);

        GroveBasin groveBasin = GroveBasin(basin);

        // Basin owned by the freshly deployed timelock.
        _assertCommonConfig(groveBasin, pocket, timelock);

        TimelockController tl = TimelockController(payable(timelock));

        assertEq(tl.getMinDelay(), minDelay);

        assertTrue(tl.hasRole(tl.PROPOSER_ROLE(),  proposer));
        assertTrue(tl.hasRole(tl.EXECUTOR_ROLE(),  Ethereum.GROVE_PROXY));
        assertTrue(tl.hasRole(tl.CANCELLER_ROLE(), Ethereum.ALM_FREEZER));
        assertTrue(tl.hasRole(tl.CANCELLER_ROLE(), proposer));

        // Timelock self-administered; factory and deployer hold no admin.
        assertTrue(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), timelock));
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), address(factory)));
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    /**********************************************************************************************/
    /*** Reverts                                                                                 ***/
    /**********************************************************************************************/

    function test_deploy_revertsOnZeroAdminTimelock() public {
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);

        vm.expectRevert(GroveBasinFactory.InvalidAdminTimelock.selector);
        factory.deploy(params, address(0));
    }

    function test_deployWithTimelock_revertsOnZeroProposer() public {
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);

        vm.expectRevert(GroveBasinFactory.InvalidTimelockProposer.selector);
        factory.deployWithTimelock(params, address(0), 7 days);
    }

    function test_deploy_usdsUsdc_revertsOnWrongSwapToken() public {
        _seed(Ethereum.USDT);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.swapToken = Ethereum.USDT;

        vm.expectRevert(GroveBasinFactory.InvalidSwapToken.selector);
        factory.deploy(params, adminTimelock);
    }

    function test_deploy_usdsUsdc_revertsOnWrongCollateralToken() public {
        _seed(Ethereum.USDS);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.collateralToken = Ethereum.USDT;

        vm.expectRevert(GroveBasinFactory.InvalidCollateralToken.selector);
        factory.deploy(params, adminTimelock);
    }

    function test_deploy_morphoUsdt_revertsOnWrongSwapToken() public {
        _seed(Ethereum.USDS);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.swapToken = Ethereum.USDS;

        vm.expectRevert(GroveBasinFactory.InvalidSwapToken.selector);
        factory.deploy(params, adminTimelock);
    }

    function test_deploy_aaveUsdt_revertsOnWrongSwapToken() public {
        _seed(Ethereum.USDS);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.AaveUsdt);
        params.swapToken = Ethereum.USDS;

        vm.expectRevert(GroveBasinFactory.InvalidSwapToken.selector);
        factory.deploy(params, adminTimelock);
    }

}

/// @dev Minimal ITokenRedeemer stub: GroveBasin.addTokenRedeemer only invokes setUp on the
///      registered redeemer, so a no-op setUp is enough to exercise the external-redeemer path.
contract MockTokenRedeemer {

    function setUp(address) external {}
    function tearDown(address) external {}

}
