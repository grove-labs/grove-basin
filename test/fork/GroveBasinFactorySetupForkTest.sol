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
import { TransferTokenRedeemer } from "src/redeemers/TransferTokenRedeemer.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAToken }       from "test/mocks/MockAToken.sol";

contract GroveBasinFactorySetupForkTest is Test {

    using SafeERC20 for IERC20;

    address constant PAU_ALM_PROXY = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;

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

    function _defaultPausedFlags() internal pure returns (bytes4[] memory flags) {
        flags = new bytes4[](4);
        flags[0] = bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"));
        flags[1] = bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"));
        flags[2] = bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"));
        flags[3] = bytes4(keccak256("PAUSED_WITHDRAW_CREDIT"));
    }

    function _defaultAllowlistManagers() internal pure returns (address[] memory allowlistManagers) {
        allowlistManagers = new address[](1);
        allowlistManagers[0] = Ethereum.ALM_RELAYER;
    }

    function _baseParams(GroveBasinFactory.PocketType pocketType)
        internal
        view
        returns (GroveBasinFactory.DeployParams memory params)
    {
        bool isUsds = pocketType == GroveBasinFactory.PocketType.UsdsUsdc;

        params = GroveBasinFactory.DeployParams({
            liquidityProvider           : PAU_ALM_PROXY,
            extraLiquidityProviders     : new address[](0),
            swapToken                   : isUsds ? Ethereum.USDS : Ethereum.USDT,
            collateralToken             : Ethereum.USDC,
            creditToken                 : address(creditToken),
            swapTokenRateProvider       : address(rateProvider),
            collateralTokenRateProvider : address(rateProvider),
            creditTokenRateProvider     : address(rateProvider),
            pocketType                  : pocketType,
            pocketAddress1              : isUsds ? psm : (pocketType == GroveBasinFactory.PocketType.MorphoUsdt ? morphoVault : address(aUsdt)),
            pocketAddress2              : pocketType == GroveBasinFactory.PocketType.AaveUsdt ? aaveV3Pool : address(0),
            managerAdmin                : Ethereum.GROVE_PROXY,
            manager                     : Ethereum.ALM_RELAYER,
            pauser                      : Ethereum.ALM_FREEZER,
            redemptionAddress           : address(0),
            tokenRedeemer               : address(0),
            issuerRedeemer              : address(0),
            pausedFlags                 : _defaultPausedFlags(),
            allowlistManagers           : _defaultAllowlistManagers(),
            minFee                      : 0,
            maxFee                      : 500,
            swapAllowlistEnabled        : false
        });
    }

    function _assertCommonConfig(GroveBasin basin, address pocket, address expectedOwner) internal view {
        // Liquidity provider is the hardcoded DPAU ALM Proxy.
        assertTrue(basin.hasRole(basin.LIQUIDITY_PROVIDER_ROLE(), PAU_ALM_PROXY));

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
        assertTrue(basin.hasRole(basin.MANAGER_ROLE(),           Ethereum.ALM_RELAYER));
        assertTrue(basin.hasRole(basin.ALLOWLIST_MANAGER_ROLE(), Ethereum.ALM_RELAYER));
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

    function test_deploy_usdsUsdc_withTransferRedeemer() public {
        _seed(Ethereum.USDS);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.redemptionAddress = redemption;
        params.issuerRedeemer         = issuer;

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(),       Ethereum.USDS);
        assertEq(groveBasin.collateralToken(), Ethereum.USDC);
        assertEq(groveBasin.creditToken(),     address(creditToken));

        _assertCommonConfig(groveBasin, pocket, adminTimelock);

        // Redeemer deployed and registered, issuer granted REDEEMER_ROLE.
        assertTrue(redeemer != address(0));
        assertEq(TransferTokenRedeemer(redeemer).creditToken(), address(creditToken));
        assertEq(address(TransferTokenRedeemer(redeemer).basin()), basin);
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), redeemer));
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(),          issuer));
    }

    function test_deploy_morphoUsdt_externalRedeemer_atomicRegistrationReverts() public {
        // A faithful redeemer must be constructed against an already-deployed Basin, so it can
        // only ever be bound to a different Basin than the one deployAndInit creates in the same
        // call. Registration then reverts in setUp's onlyBasin check, so the atomic
        // external-redeemer branch is unreachable for real redeemers; only the self-deployed
        // BUIDL branch (test_deploy_usdsUsdc_withBuidlRedeemer) works.
        _seed(Ethereum.USDT);
        (address otherBasin,,) =
            factory.deployAndInit(_baseParams(GroveBasinFactory.PocketType.MorphoUsdt), adminTimelock);

        address externalRedeemer = address(new MockTokenRedeemer(address(creditToken), otherBasin));

        _seed(Ethereum.USDT);
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.tokenRedeemer = externalRedeemer;

        vm.expectRevert(MockTokenRedeemer.OnlyBasin.selector);
        factory.deployAndInit(params, adminTimelock);
    }

    function test_deploy_morphoUsdt_externalRedeemerAddedPostDeployment() public {
        _seed(Ethereum.USDT);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.tokenRedeemer  = address(0);  // atomic external registration is impossible; skip it
        params.issuerRedeemer = issuer;

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(), Ethereum.USDT);

        _assertCommonConfig(groveBasin, pocket, adminTimelock);

        // No redeemer registered during setup; issuer still granted REDEEMER_ROLE.
        assertEq(redeemer, address(0));
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(), issuer));

        // Real supported flow: build the redeemer against the now-existing Basin, then the
        // MANAGER_ADMIN (GROVE_PROXY) registers it via addTokenRedeemer.
        address externalRedeemer = address(new MockTokenRedeemer(address(creditToken), basin));

        vm.prank(Ethereum.GROVE_PROXY);
        groveBasin.addTokenRedeemer(externalRedeemer);

        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), externalRedeemer));
    }

    function test_deploy_aaveUsdt_withoutRedeemer() public {
        _seed(Ethereum.USDT);

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.AaveUsdt);

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(), Ethereum.USDT);

        _assertCommonConfig(groveBasin, pocket, adminTimelock);

        // No token redeemer registered, no issuer granted.
        assertEq(redeemer, address(0));
        assertFalse(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), address(0)));
        assertFalse(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(), issuer));
    }

    function test_deployWithTimelockAndInit_deploysAndOwnsBasin() public {
        _seed(Ethereum.USDT);

        uint256 minDelay = 7 days;

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.issuerRedeemer = issuer;

        (address basin, address pocket, , address timelock) =
            factory.deployWithTimelockAndInit(params, proposer, minDelay);

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
        factory.deployAndInit(params, address(0));
    }

    function test_deployWithTimelockAndInit_revertsOnZeroProposer() public {
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);

        vm.expectRevert(GroveBasinFactory.InvalidTimelockProposer.selector);
        factory.deployWithTimelockAndInit(params, address(0), 7 days);
    }

}

/// @dev Faithful ITokenRedeemer stand-in. Like the real redeemers (BUIDLTokenRedeemer /
///      JTRSYTokenRedeemer), its constructor reads the Basin's token config, so it cannot be
///      constructed before the Basin exists, and setUp/tearDown are gated by onlyBasin. This
///      reproduces the circular existence dependency that makes atomic registration of a
///      pre-deployed redeemer impossible inside deployAndInit.
contract MockTokenRedeemer {

    error OnlyBasin();
    error CreditTokenMismatch();

    address public immutable basin;
    address public immutable creditToken;
    address public immutable collateralToken;

    modifier onlyBasin() {
        if (msg.sender != basin) revert OnlyBasin();
        _;
    }

    constructor(address creditToken_, address basin_) {
        if (GroveBasin(basin_).creditToken() != creditToken_) revert CreditTokenMismatch();
        basin           = basin_;
        creditToken     = creditToken_;
        collateralToken = GroveBasin(basin_).collateralToken();
    }

    function setUp(address)    external onlyBasin {}
    function tearDown(address) external onlyBasin {}

}
