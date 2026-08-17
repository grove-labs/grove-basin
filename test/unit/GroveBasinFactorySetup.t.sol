// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import { GroveBasin }         from "src/GroveBasin.sol";
import { GroveBasinFactory }  from "src/GroveBasinFactory.sol";
import { TransferTokenRedeemer } from "src/redeemers/TransferTokenRedeemer.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAToken }       from "test/mocks/MockAToken.sol";

/// @dev Mock-based coverage of the GroveBasinFactory full-setup flow. The fork test
///      (GroveBasinFactorySetupForkTest) exercises the same paths against real mainnet state;
///      these unit tests reproduce them with mocks so they run without an RPC.
contract GroveBasinFactorySetupTests is Test {

    GroveBasinFactory factory;

    MockERC20        swapToken;        // USDS for UsdsUsdc, USDT for Morpho/Aave
    MockERC20        collateralToken;  // USDC
    MockERC20        creditToken;
    MockRateProvider rateProvider;
    MockAToken       aToken;

    address liquidityProvider = makeAddr("liquidityProvider");
    address groveProxy        = makeAddr("groveProxy");
    address almRelayer        = makeAddr("almRelayer");
    address allowlistManager1 = makeAddr("allowlistManager1");
    address allowlistManager2 = makeAddr("allowlistManager2");
    address almFreezer        = makeAddr("almFreezer");
    address adminTimelock     = makeAddr("adminTimelock");
    address proposer          = makeAddr("proposer");
    address issuer            = makeAddr("issuer");
    address psm               = makeAddr("psm");
    address morphoVault       = makeAddr("morphoVault");
    address aaveV3Pool        = makeAddr("aaveV3Pool");
    address redemption        = makeAddr("redemption");

    function setUp() public {
        factory         = new GroveBasinFactory();
        swapToken       = new MockERC20("swap",       "swap",       6);
        collateralToken = new MockERC20("collateral", "collateral", 6);
        creditToken     = new MockERC20("credit",     "credit",     18);
        rateProvider    = new MockRateProvider();
        rateProvider.__setConversionRate(1e27);
        aToken = new MockAToken("aSwap", "aSwap", 6, address(swapToken));
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _seed() internal {
        uint256 seedAmount = 10 ** swapToken.decimals();
        swapToken.mint(address(this), seedAmount);
        swapToken.approve(address(factory), seedAmount);
    }

    function _defaultPausedFlags() internal pure returns (bytes4[] memory flags) {
        flags = new bytes4[](4);
        flags[0] = bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"));
        flags[1] = bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"));
        flags[2] = bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"));
        flags[3] = bytes4(keccak256("PAUSED_WITHDRAW_CREDIT"));
    }

    function _defaultAllowlistManagers() internal view returns (address[] memory allowlistManagers) {
        allowlistManagers = new address[](2);
        allowlistManagers[0] = allowlistManager1;
        allowlistManagers[1] = allowlistManager2;
    }

    function _pocketAddress1(GroveBasinFactory.PocketType pocketType) internal view returns (address) {
        if (pocketType == GroveBasinFactory.PocketType.UsdsUsdc)   return psm;
        if (pocketType == GroveBasinFactory.PocketType.MorphoUsdt) return morphoVault;
        if (pocketType == GroveBasinFactory.PocketType.AaveUsdt)   return address(aToken);
        return address(0);  // None
    }

    function _baseParams(GroveBasinFactory.PocketType pocketType)
        internal view returns (GroveBasinFactory.DeployParams memory params)
    {
        params = GroveBasinFactory.DeployParams({
            liquidityProvider           : liquidityProvider,
            swapToken                   : address(swapToken),
            collateralToken             : address(collateralToken),
            creditToken                 : address(creditToken),
            swapTokenRateProvider       : address(rateProvider),
            collateralTokenRateProvider : address(rateProvider),
            creditTokenRateProvider     : address(rateProvider),
            pocketType                  : pocketType,
            pocketAddress1              : _pocketAddress1(pocketType),
            pocketAddress2              : pocketType == GroveBasinFactory.PocketType.AaveUsdt ? aaveV3Pool : address(0),
            managerAdmin                : groveProxy,
            manager                     : almRelayer,
            pauser                      : almFreezer,
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

    function _assertCommonConfig(GroveBasin basin, address expectedOwner) internal view {
        assertTrue(basin.hasRole(basin.LIQUIDITY_PROVIDER_ROLE(), liquidityProvider));

        // Ownership handed to the admin timelock; factory and deployer hold nothing.
        assertTrue(basin.hasRole(basin.OWNER_ROLE(), expectedOwner));
        assertFalse(basin.hasRole(basin.OWNER_ROLE(), address(factory)));
        assertFalse(basin.hasRole(basin.OWNER_ROLE(), address(this)));

        // GROVE_PROXY keeps MANAGER_ADMIN_ROLE; factory must not.
        assertTrue(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), groveProxy));
        assertFalse(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), address(factory)));

        // Operational roles.
        assertTrue(basin.hasRole(basin.MANAGER_ROLE(),           almRelayer));
        assertTrue(basin.hasRole(basin.ALLOWLIST_MANAGER_ROLE(), allowlistManager1));
        assertTrue(basin.hasRole(basin.ALLOWLIST_MANAGER_ROLE(), allowlistManager2));
        assertTrue(basin.hasRole(basin.PAUSER_ROLE(),            almFreezer));
        assertFalse(basin.hasRole(basin.PAUSER_ROLE(), address(factory)));

        // The allowlist is a separate role from the manager role.
        assertFalse(basin.hasRole(basin.ALLOWLIST_MANAGER_ROLE(), almRelayer));
        assertFalse(basin.hasRole(basin.MANAGER_ROLE(),           allowlistManager1));

        assertEq(basin.totalShares(),      1e18);
        assertEq(basin.shares(address(0)), 1e18);
    }

    /**********************************************************************************************/
    /*** Pocket variants                                                                        ***/
    /**********************************************************************************************/

    function test_deploy_usdsUsdc_withTransferRedeemer() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.redemptionAddress = redemption;
        params.issuerRedeemer         = issuer;

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(),       address(swapToken));
        assertEq(groveBasin.collateralToken(), address(collateralToken));
        assertEq(groveBasin.creditToken(),     address(creditToken));

        _assertCommonConfig(groveBasin, adminTimelock);

        // Pocket deployed and wired up; seed migrated out of the basin.
        assertTrue(pocket != address(0));
        assertEq(groveBasin.pocket(), pocket);
        assertEq(swapToken.balanceOf(basin),  0);
        assertEq(swapToken.balanceOf(pocket), 10 ** swapToken.decimals());

        // Explicit fee bounds applied verbatim.
        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 500);

        // Default pauses applied.
        assertTrue(groveBasin.paused(groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT()));
        assertTrue(groveBasin.paused(groveBasin.PAUSED_SWAP_COLLATERAL_TO_CREDIT()));
        assertTrue(groveBasin.paused(groveBasin.PAUSED_DEPOSIT_CREDIT()));
        assertTrue(groveBasin.paused(groveBasin.PAUSED_WITHDRAW_CREDIT()));

        // Redeemer deployed and registered; issuer granted REDEEMER_ROLE.
        assertTrue(redeemer != address(0));
        assertEq(TransferTokenRedeemer(redeemer).creditToken(),    address(creditToken));
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
        _seed();
        (address otherBasin,,) =
            factory.deployAndInit(_baseParams(GroveBasinFactory.PocketType.MorphoUsdt), adminTimelock);

        address externalRedeemer = address(new MockTokenRedeemer(address(creditToken), otherBasin));

        _seed();
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.tokenRedeemer = externalRedeemer;

        vm.expectRevert(MockTokenRedeemer.OnlyBasin.selector);
        factory.deployAndInit(params, adminTimelock);
    }

    function test_deploy_morphoUsdt_externalRedeemerAddedPostDeployment_customFeeBounds() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.tokenRedeemer  = address(0);  // atomic external registration is impossible; skip it
        params.issuerRedeemer = issuer;
        params.minFee         = 0;
        params.maxFee         = 400;

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(), address(swapToken));

        _assertCommonConfig(groveBasin, adminTimelock);

        assertTrue(pocket != address(0));
        assertEq(groveBasin.pocket(), pocket);

        // Custom fee bounds applied verbatim.
        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 400);

        // No redeemer registered during setup; issuer still granted REDEEMER_ROLE.
        assertEq(redeemer, address(0));
        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(), issuer));

        // Real supported flow: build the redeemer against the now-existing Basin, then the
        // MANAGER_ADMIN (GROVE_PROXY) registers it via addTokenRedeemer.
        address externalRedeemer = address(new MockTokenRedeemer(address(creditToken), basin));

        vm.prank(groveProxy);
        groveBasin.addTokenRedeemer(externalRedeemer);

        assertTrue(groveBasin.hasRole(groveBasin.REDEEMER_CONTRACT_ROLE(), externalRedeemer));
    }

    function test_deploy_aaveUsdt_noRedeemer_emptyPausedFlags() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.AaveUsdt);
        params.pausedFlags = new bytes4[](0);

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertEq(groveBasin.swapToken(), address(swapToken));

        _assertCommonConfig(groveBasin, adminTimelock);

        assertTrue(pocket != address(0));
        assertEq(groveBasin.pocket(), pocket);

        // Empty pausedFlags pauses nothing.
        assertFalse(groveBasin.paused(groveBasin.PAUSED_SWAP_SWAP_TO_CREDIT()));
        assertFalse(groveBasin.paused(groveBasin.PAUSED_DEPOSIT_CREDIT()));

        // No token redeemer registered, no issuer granted.
        assertEq(redeemer, address(0));
        assertFalse(groveBasin.hasRole(groveBasin.REDEEMER_ROLE(), issuer));
    }

    function test_deploy_none_deploysNoPocket() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.None);

        (address basin, address pocket, address redeemer) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        // No pocket deployed and setPocket skipped.
        assertEq(pocket,   address(0));
        assertEq(redeemer, address(0));

        assertEq(groveBasin.swapToken(), address(swapToken));

        _assertCommonConfig(groveBasin, adminTimelock);

        // Seed remains held by the basin since no pocket migration occurred.
        assertEq(swapToken.balanceOf(basin), 10 ** swapToken.decimals());
    }

    /**********************************************************************************************/
    /*** Fee bounds                                                                             ***/
    /**********************************************************************************************/

    function test_deploy_nonZeroMinFee_setsFeesWithinBounds() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.None);
        params.minFee = 100;
        params.maxFee = 400;

        (address basin,,) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        // Fees raised into range so the tightened bounds apply without reverting.
        assertEq(groveBasin.minFee(),        100);
        assertEq(groveBasin.maxFee(),        400);
        assertEq(groveBasin.purchaseFee(),   100);
        assertEq(groveBasin.redemptionFee(), 100);
    }

    function test_deploy_zeroFeeBounds() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.None);
        params.minFee = 0;
        params.maxFee = 0;

        (address basin,,) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        // Explicit (0, 0) bounds are honored; no default is substituted for a zero maxFee.
        assertEq(groveBasin.minFee(), 0);
        assertEq(groveBasin.maxFee(), 0);
    }

    /**********************************************************************************************/
    /*** Swap allowlist variant                                                                 ***/
    /**********************************************************************************************/

    function test_deploy_swapAllowlistDisabledByDefault() public {
        _seed();

        (address basin,,) = factory.deployAndInit(_baseParams(GroveBasinFactory.PocketType.None), adminTimelock);

        assertFalse(GroveBasin(basin).swapAllowlistEnabled(GroveBasin(basin).GLOBAL_ROUTE_KEY()));
    }

    function test_deploy_swapAllowlistEnabled() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.None);
        params.swapAllowlistEnabled = true;

        (address basin,,) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertTrue(groveBasin.swapAllowlistEnabled(groveBasin.GLOBAL_ROUTE_KEY()));

        // Enabling is atomic with deployment, so no caller is allowlisted on arrival.
        assertFalse(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), almRelayer));

        // The factory retains no power to change it afterwards.
        assertFalse(groveBasin.hasRole(groveBasin.MANAGER_ADMIN_ROLE(), address(factory)));
    }

    function test_deploy_noAllowlistManagers() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.None);
        params.allowlistManagers = new address[](0);

        (address basin,,) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        assertFalse(groveBasin.hasRole(groveBasin.ALLOWLIST_MANAGER_ROLE(), allowlistManager1));
        assertFalse(groveBasin.hasRole(groveBasin.ALLOWLIST_MANAGER_ROLE(), allowlistManager2));
    }

    function test_deploy_allowlistManagersCanManageAllowlist() public {
        _seed();

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.None);
        params.swapAllowlistEnabled = true;

        (address basin,,) = factory.deployAndInit(params, adminTimelock);

        GroveBasin groveBasin = GroveBasin(basin);

        // The deployment enables the global allowlist only, so the global set governs every route.
        bytes32 globalRouteKey = groveBasin.GLOBAL_ROUTE_KEY();

        vm.prank(allowlistManager1);
        groveBasin.addToSwapAllowlist(globalRouteKey, almRelayer);

        assertTrue(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), almRelayer));

        vm.prank(allowlistManager2);
        groveBasin.removeFromSwapAllowlist(globalRouteKey, almRelayer);

        assertFalse(groveBasin.isSwapCallerAllowlisted(address(swapToken), address(creditToken), almRelayer));
    }

    /**********************************************************************************************/
    /*** Timelock variant                                                                       ***/
    /**********************************************************************************************/

    function test_deployWithTimelockAndInit_deploysAndOwnsBasin() public {
        _seed();

        uint256 minDelay = 7 days;

        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.MorphoUsdt);
        params.issuerRedeemer = issuer;

        (address basin, address pocket, , address timelock) =
            factory.deployWithTimelockAndInit(params, proposer, minDelay);

        GroveBasin groveBasin = GroveBasin(basin);

        // Basin owned by the freshly deployed timelock.
        _assertCommonConfig(groveBasin, timelock);
        assertEq(groveBasin.pocket(), pocket);

        TimelockController tl = TimelockController(payable(timelock));

        assertEq(tl.getMinDelay(), minDelay);

        assertTrue(tl.hasRole(tl.PROPOSER_ROLE(),  proposer));
        assertTrue(tl.hasRole(tl.EXECUTOR_ROLE(),  groveProxy));
        assertTrue(tl.hasRole(tl.CANCELLER_ROLE(), almFreezer));
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

    function test_deploy_revertsOnSelfAdminTimelock() public {
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);

        vm.expectRevert(GroveBasinFactory.InvalidAdminTimelock.selector);
        factory.deployAndInit(params, address(factory));
    }

    function test_deploy_revertsOnSelfLiquidityProvider() public {
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.liquidityProvider = address(factory);

        vm.expectRevert(GroveBasinFactory.InvalidLiquidityProvider.selector);
        factory.deployAndInit(params, adminTimelock);
    }

    function test_deploy_revertsOnZeroManagerAdmin() public {
        GroveBasinFactory.DeployParams memory params = _baseParams(GroveBasinFactory.PocketType.UsdsUsdc);
        params.managerAdmin = address(0);

        vm.expectRevert(GroveBasinFactory.InvalidManagerAdmin.selector);
        factory.deployAndInit(params, adminTimelock);
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
