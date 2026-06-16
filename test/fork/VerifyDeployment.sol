// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import { GroveBasin }            from "src/GroveBasin.sol";
import { UsdsUsdcPocket }        from "src/pockets/UsdsUsdcPocket.sol";
import { BUIDLTokenRedeemer }    from "src/redeemers/BUIDLTokenRedeemer.sol";
import { FixedRateProvider }     from "src/rate-providers/FixedRateProvider.sol";
import { ChronicleRateProvider } from "src/rate-providers/ChronicleRateProvider.sol";
import { IChronicleOracleLike }  from "src/interfaces/IChronicleOracleLike.sol";
import { ITokenRedeemer }        from "src/interfaces/ITokenRedeemer.sol";

library Deployments {

    /**********************************************************************************************/
    /*** Shared                                                                                 ***/
    /**********************************************************************************************/

    address internal constant DEPLOYER                      = 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817;
    address internal constant DPAU_ALM_PROXY                = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;
    address internal constant USDS_PSM_WRAPPER              = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address internal constant GROVE_BASIN_FACTORY           = 0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a;
    address internal constant USDS_USDC_FIXED_RATE_PROVIDER = 0x7928A185B8137D1CD2a0996a810A04dB2837419D;

    /**********************************************************************************************/
    /*** JTRSY Basin                                                                            ***/
    /**********************************************************************************************/

    address internal constant JTRSY_TIMELOCK                = 0xA52dC9876aB4A9DB6dAfbb83410554086054d140;
    address internal constant JTRSY_BASIN                   = 0xf08943f817e1F902dEbC884c7B19Ea5764594Ac9;
    address internal constant JTRSY_TOKEN_REDEEMER          = 0x7c5Ce1a1D50a6cb3Da97C9e202B3E7CD8e5b5b6c;
    address internal constant JTRSY_USDS_USDC_POCKET        = 0x2Cd296095788A2741e72056D66B3Ae1fAeE23ea2;
    address internal constant JTRSY_CHRONICLE_RATE_PROVIDER = 0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5;

    // Issuer provided
    address internal constant JTRSY_ISSUER_MULTISIG = 0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c;
    address internal constant JTRSY_REDEEMER        = 0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a;

    // External
    address internal constant JTRSY_TOKEN       = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address internal constant FULL_RESTRICTIONS = 0x8E680873b4C77e6088b4Ba0aBD59d100c3D224a4;

    /**********************************************************************************************/
    /*** BUIDL Basin                                                                            ***/
    /**********************************************************************************************/

    address internal constant BUIDL_TIMELOCK                = 0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34;
    address internal constant BUIDL_BASIN                   = 0xCBa428fB052B365557DAf52b744DFfF20d5FbEdD;
    address internal constant BUIDL_USDS_USDC_POCKET        = 0x39548FeF138370Db06e172eF0739894b2a613DF9;
    address internal constant BUIDL_TOKEN_REDEEMER          = 0x73414528187A4986E2Af5D551fD14871b723E506;
    address internal constant BUIDL_CHRONICLE_RATE_PROVIDER = 0x69a171853575FFD41574EA80Abfc6337AcbC4d43;

    // Issuer provided (current)
    address internal constant SECURITIZE_ISSUER_MULTISIG    = 0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a;
    address internal constant SECURITIZE_REDEEMER           = 0x488F27168a19472c51f003fbC5b75B1ACc3B7b4c;
    address internal constant SECURITIZE_REDEMPTION_ADDRESS = 0x8780Dd016171B91E4Df47075dA0a947959C34200;

    // Issuer provided (old — rotated out, must not hold any roles)
    address internal constant OLD_SECURITIZE_ISSUER_MULTISIG    = 0x551e841e6fb54431a0664C8776784F6d7E611428;
    address internal constant OLD_SECURITIZE_REDEEMER           = 0xdfC603076EA75895DD4d59c6e2ee5038f881CB74;
    address internal constant OLD_SECURITIZE_REDEMPTION_ADDRESS = 0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052;
    address internal constant OLD_BUIDL_TOKEN_REDEEMER          = 0x0D46f8A832B76A79AC3B5F29fFfc35ACeebad885;

    // External
    address internal constant BUIDL_TOKEN = 0x7712c34205737192402172409a8F7ccef8aA2AEc;

}


interface IChronicleAuthLike {
    function kiss(address who) external;
}

interface IFullRestrictionsLike {
    function updateMember(address token, address user, uint64 validUntil) external;
}

interface IShareTokenLike {
    function balanceOf(address) external view returns (uint256);
    function hookDataOf(address) external view returns (bytes16);
}

interface IBUIDLLike {
    function owner() external view returns (address);
    function getDSService(uint256 serviceId) external view returns (address);
    function issueTokensWithNoCompliance(address to, uint256 value) external;
    function setCap(uint256 cap) external;
    function COMPLIANCE_SERVICE() external view returns (uint256);
    function WALLET_REGISTRAR() external view returns (uint256);
    function REGISTRY_SERVICE() external view returns (uint256);
}

contract NoOpFallback {

    fallback() external payable {
        assembly {
            return(0, 256)
        }
    }

}

/**********************************************************************************************/
/*** Shared abstract base — parameterized by deployment addresses                           ***/
/**********************************************************************************************/

abstract contract UsdsUsdcBasinDeploymentForkTestBase is Test {

    GroveBasin     public basin;
    UsdsUsdcPocket public pocket;

    function _basinAddr()                   internal pure virtual returns (address);
    function _pocketAddr()                  internal pure virtual returns (address);
    function _ownerAddr()                   internal pure virtual returns (address);
    function _timelockAddr()                internal pure virtual returns (address);
    function _creditToken()                 internal pure virtual returns (address);
    function _swapTokenRateProvider()       internal pure virtual returns (address);
    function _collateralTokenRateProvider() internal pure virtual returns (address);
    function _creditTokenRateProvider()     internal pure virtual returns (address);
    function _issuerMultisigAddr()          internal pure virtual returns (address);
    function _redeemerAddr()                internal pure virtual returns (address);
    function _tokenRedeemerAddr()           internal pure virtual returns (address);

    uint256 internal constant FORK_BLOCK_NUMBER = 25093011; // Thu, May 14, 7:33am EST

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl);
        basin  = GroveBasin(_basinAddr());
        pocket = UsdsUsdcPocket(basin.pocket());
        _postSetUp();
    }

    function _postSetUp() internal virtual;

    function _dealCreditToken(address to, uint256 amount) internal virtual;

    function _deposit(address asset, address receiver, uint256 amount) internal {
        address lp_ = basin.liquidityProvider();
        deal(asset, lp_, amount);
        vm.startPrank(lp_);
        IERC20(asset).approve(address(basin), amount);
        basin.deposit(asset, receiver, amount);
        vm.stopPrank();
    }

}

/**********************************************************************************************/
/*** JTRSY deployment base                                                                  ***/
/**********************************************************************************************/

abstract contract JTRSYUsdsUsdcDeploymentForkTestBase is UsdsUsdcBasinDeploymentForkTestBase {

    TimelockController public timelock;

    function _basinAddr()                   internal pure override returns (address) { return Deployments.JTRSY_BASIN; }
    function _pocketAddr()                  internal pure override returns (address) { return Deployments.JTRSY_USDS_USDC_POCKET; }
    function _ownerAddr()                   internal pure override returns (address) { return Deployments.JTRSY_TIMELOCK; }
    function _timelockAddr()                internal pure override returns (address) { return Deployments.JTRSY_TIMELOCK; }
    function _creditToken()                 internal pure override returns (address) { return Deployments.JTRSY_TOKEN; }
    function _swapTokenRateProvider()       internal pure override returns (address) { return Deployments.USDS_USDC_FIXED_RATE_PROVIDER; }
    function _collateralTokenRateProvider() internal pure override returns (address) { return Deployments.USDS_USDC_FIXED_RATE_PROVIDER; }
    function _creditTokenRateProvider()     internal pure override returns (address) { return Deployments.JTRSY_CHRONICLE_RATE_PROVIDER; }
    function _issuerMultisigAddr()          internal pure override returns (address) { return Deployments.JTRSY_ISSUER_MULTISIG; }
    function _redeemerAddr()                internal pure override returns (address) { return Deployments.JTRSY_REDEEMER; }
    function _tokenRedeemerAddr()           internal pure override returns (address) { return Deployments.JTRSY_TOKEN_REDEEMER; }

    function _postSetUp() internal override {
        timelock = TimelockController(payable(Deployments.JTRSY_TIMELOCK));
        _addToJTRSYAllowlist(Deployments.JTRSY_BASIN);
        _addToJTRSYAllowlist(Deployments.JTRSY_TOKEN_REDEEMER);
    }

    function _dealCreditToken(address to, uint256 amount) internal override {
        _dealJTRSY(to, amount);
    }

    function _addToJTRSYAllowlist(address account) internal {
        vm.store(Deployments.FULL_RESTRICTIONS, keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));
        vm.store(Deployments.JTRSY_TOKEN, keccak256(abi.encode(Deployments.FULL_RESTRICTIONS, uint256(0))), bytes32(uint256(1)));
        IFullRestrictionsLike(Deployments.FULL_RESTRICTIONS).updateMember(Deployments.JTRSY_TOKEN, account, type(uint64).max);
    }

    function _dealJTRSY(address to, uint256 amount) internal {
        require(amount <= type(uint128).max, "JTRSY balance overflow");
        _addToJTRSYAllowlist(to);

        IShareTokenLike token = IShareTokenLike(Deployments.JTRSY_TOKEN);
        bytes16 hookData      = token.hookDataOf(to);
        bytes32 slot          = _findBalanceSlot(to);
        bytes32 packed        = bytes32(uint256(uint128(hookData)) << 128 | uint256(amount));
        vm.store(Deployments.JTRSY_TOKEN, slot, packed);

        assertEq(token.balanceOf(to), amount);
    }

    function _findBalanceSlot(address account) internal returns (bytes32) {
        vm.record();
        IShareTokenLike(Deployments.JTRSY_TOKEN).balanceOf(account);
        (bytes32[] memory reads,) = vm.accesses(Deployments.JTRSY_TOKEN);
        require(reads.length > 0, "Could not find balance slot");
        return reads[0];
    }

}

/**********************************************************************************************/
/*** BUIDL deployment base                                                                  ***/
/**********************************************************************************************/

abstract contract BUIDLUsdsUsdcDeploymentForkTestBase is UsdsUsdcBasinDeploymentForkTestBase {

    IBUIDLLike public buidl = IBUIDLLike(Deployments.BUIDL_TOKEN);

    TimelockController public timelock;

    address public buidlMaster;
    address public complianceService;
    address public walletRegistrar;
    address public registryService;

    function _basinAddr()                   internal pure override returns (address) { return Deployments.BUIDL_BASIN; }
    function _pocketAddr()                  internal pure override returns (address) { return Deployments.BUIDL_USDS_USDC_POCKET; }
    function _ownerAddr()                   internal pure override returns (address) { return Deployments.BUIDL_TIMELOCK; }
    function _timelockAddr()                internal pure override returns (address) { return Deployments.BUIDL_TIMELOCK; }
    function _creditToken()                 internal pure override returns (address) { return Deployments.BUIDL_TOKEN; }
    function _swapTokenRateProvider()       internal pure override returns (address) { return Deployments.USDS_USDC_FIXED_RATE_PROVIDER; }
    function _collateralTokenRateProvider() internal pure override returns (address) { return Deployments.USDS_USDC_FIXED_RATE_PROVIDER; }
    function _creditTokenRateProvider()     internal pure override returns (address) { return Deployments.BUIDL_CHRONICLE_RATE_PROVIDER; }
    function _issuerMultisigAddr()          internal pure override returns (address) { return Deployments.SECURITIZE_ISSUER_MULTISIG; }
    function _redeemerAddr()                internal pure override returns (address) { return Deployments.SECURITIZE_REDEEMER; }
    function _tokenRedeemerAddr()           internal pure override returns (address) { return Deployments.BUIDL_TOKEN_REDEEMER; }

    function _postSetUp() internal override {
        timelock          = TimelockController(payable(Deployments.BUIDL_TIMELOCK));
        buidlMaster       = buidl.owner();
        complianceService = buidl.getDSService(buidl.COMPLIANCE_SERVICE());
        walletRegistrar   = buidl.getDSService(buidl.WALLET_REGISTRAR());
        registryService   = buidl.getDSService(buidl.REGISTRY_SERVICE());

        vm.prank(buidlMaster);
        buidl.setCap(type(uint256).max);

        _mockBUIDLWalletRegistrar();
        _mockBUIDLCompliance();
    }

    function _dealCreditToken(address to, uint256 amount) internal override {
        vm.prank(buidlMaster);
        buidl.issueTokensWithNoCompliance(to, amount);
    }

    function _mockBUIDLWalletRegistrar() internal {
        vm.mockCall(
            walletRegistrar,
            abi.encodeWithSignature("isWallet(address)"),
            abi.encode(true)
        );
        vm.mockCall(
            registryService,
            abi.encodeWithSignature("isWallet(address)"),
            abi.encode(true)
        );
    }

    function _mockBUIDLCompliance() internal {
        vm.etch(complianceService, type(NoOpFallback).runtimeCode);
    }

}

/**********************************************************************************************/
/*** Shared tests — TimelockController                                                      ***/
/**********************************************************************************************/

abstract contract Verify_Timelock is UsdsUsdcBasinDeploymentForkTestBase {

    function _timelock() internal view returns (TimelockController) {
        return TimelockController(payable(_timelockAddr()));
    }

    function test_timelock_onlyAdminIsSelf() public view {
        TimelockController tl = _timelock();
        assertTrue(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), address(tl)),            "timelock should be its own DEFAULT_ADMIN");
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), Deployments.DEPLOYER),  "deployer should not have DEFAULT_ADMIN_ROLE");
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), _issuerMultisigAddr()), "issuer multisig should not have DEFAULT_ADMIN_ROLE");
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), Ethereum.GROVE_PROXY),  "GROVE_PROXY should not have DEFAULT_ADMIN_ROLE");
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), Ethereum.ALM_FREEZER),  "ALM_FREEZER should not have DEFAULT_ADMIN_ROLE");
    }

    function test_timelock_delay() public view {
        assertEq(_timelock().getMinDelay(), 7 days, "timelock min delay should be 7 days");
    }

    function test_timelock_onlyProposerIsIssuerMultisig() public view {
        TimelockController tl = _timelock();
        assertTrue(tl.hasRole(tl.PROPOSER_ROLE(), _issuerMultisigAddr()), "issuer multisig should have PROPOSER_ROLE");
        assertFalse(tl.hasRole(tl.PROPOSER_ROLE(), Deployments.DEPLOYER), "deployer should not have PROPOSER_ROLE");
        assertFalse(tl.hasRole(tl.PROPOSER_ROLE(), Ethereum.GROVE_PROXY), "GROVE_PROXY should not have PROPOSER_ROLE");
        assertFalse(tl.hasRole(tl.PROPOSER_ROLE(), Ethereum.ALM_FREEZER), "ALM_FREEZER should not have PROPOSER_ROLE");
    }

    function test_timelock_onlyExecutorIsGroveProxy() public view {
        TimelockController tl = _timelock();
        assertTrue(tl.hasRole(tl.EXECUTOR_ROLE(), Ethereum.GROVE_PROXY),   "GROVE_PROXY should have EXECUTOR_ROLE");
        assertFalse(tl.hasRole(tl.EXECUTOR_ROLE(), Deployments.DEPLOYER),  "deployer should not have EXECUTOR_ROLE");
        assertFalse(tl.hasRole(tl.EXECUTOR_ROLE(), _issuerMultisigAddr()), "issuer multisig should not have EXECUTOR_ROLE");
        assertFalse(tl.hasRole(tl.EXECUTOR_ROLE(), Ethereum.ALM_FREEZER),  "ALM_FREEZER should not have EXECUTOR_ROLE");
    }

    function test_timelock_cancellerIsFreezerAndIssuer() public view {
        TimelockController tl = _timelock();
        assertTrue(tl.hasRole(tl.CANCELLER_ROLE(), Ethereum.ALM_FREEZER),  "ALM_FREEZER should have CANCELLER_ROLE");
        assertTrue(tl.hasRole(tl.CANCELLER_ROLE(), _issuerMultisigAddr()), "issuer multisig should have CANCELLER_ROLE");
        assertFalse(tl.hasRole(tl.CANCELLER_ROLE(), Deployments.DEPLOYER), "deployer should not have CANCELLER_ROLE");
        assertFalse(tl.hasRole(tl.CANCELLER_ROLE(), Ethereum.GROVE_PROXY), "GROVE_PROXY should not have CANCELLER_ROLE");
    }

    function test_timelock_deployerHasNoRoles() public view {
        TimelockController tl = _timelock();
        assertFalse(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), Deployments.DEPLOYER), "deployer should not have DEFAULT_ADMIN_ROLE");
        assertFalse(tl.hasRole(tl.PROPOSER_ROLE(), Deployments.DEPLOYER),      "deployer should not have PROPOSER_ROLE");
        assertFalse(tl.hasRole(tl.EXECUTOR_ROLE(), Deployments.DEPLOYER),      "deployer should not have EXECUTOR_ROLE");
        assertFalse(tl.hasRole(tl.CANCELLER_ROLE(), Deployments.DEPLOYER),     "deployer should not have CANCELLER_ROLE");
    }

    /*** Timelock actions ***/

    function _scheduleGrantManagerAdmin(address target, bytes32 salt) internal returns (bytes32) {
        TimelockController tl = _timelock();
        bytes memory data = abi.encodeCall(
            basin.grantRole,
            (basin.MANAGER_ADMIN_ROLE(), target)
        );
        uint256 delay = tl.getMinDelay();

        vm.prank(_issuerMultisigAddr());
        tl.schedule(address(basin), 0, data, bytes32(0), salt, delay);

        return tl.hashOperation(address(basin), 0, data, bytes32(0), salt);
    }

    function test_action_proposerCanScheduleAndProxyCanExecute() public {
        TimelockController tl = _timelock();
        address newAdmin = makeAddr("newAdmin");
        bytes memory data = abi.encodeCall(basin.grantRole, (basin.MANAGER_ADMIN_ROLE(), newAdmin));
        bytes32 salt = keccak256("test_schedule_execute");

        bytes32 id = _scheduleGrantManagerAdmin(newAdmin, salt);
        assertTrue(tl.isOperationPending(id), "operation should be pending after schedule");

        vm.warp(block.timestamp + tl.getMinDelay());

        vm.prank(Ethereum.GROVE_PROXY);
        tl.execute(address(basin), 0, data, bytes32(0), salt);

        assertTrue(tl.isOperationDone(id), "operation should be done after execute");
        assertTrue(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), newAdmin), "newAdmin should have MANAGER_ADMIN_ROLE");
    }

    function test_action_freezerCanCancelScheduledTransaction() public {
        TimelockController tl = _timelock();
        address newAdmin = makeAddr("newAdmin");
        bytes32 salt = keccak256("test_cancel");

        bytes32 id = _scheduleGrantManagerAdmin(newAdmin, salt);
        assertTrue(tl.isOperationPending(id), "operation should be pending after schedule");

        vm.prank(Ethereum.ALM_FREEZER);
        tl.cancel(id);

        assertFalse(tl.isOperationPending(id), "operation should not be pending after cancel");
        assertFalse(tl.isOperation(id), "operation should not exist after cancel");
    }

    function test_action_cannotExecuteBeforeDelay() public {
        TimelockController tl = _timelock();
        address newAdmin = makeAddr("newAdmin");
        bytes memory data = abi.encodeCall(basin.grantRole, (basin.MANAGER_ADMIN_ROLE(), newAdmin));
        bytes32 salt = keccak256("test_before_delay");

        bytes32 id = _scheduleGrantManagerAdmin(newAdmin, salt);

        vm.warp(block.timestamp + tl.getMinDelay() - 1);

        vm.prank(Ethereum.GROVE_PROXY);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                id,
                bytes32(1 << uint8(TimelockController.OperationState.Ready))
            )
        );
        tl.execute(address(basin), 0, data, bytes32(0), salt);
    }

    function test_action_cannotExecuteAfterCancel() public {
        TimelockController tl = _timelock();
        address newAdmin = makeAddr("newAdmin");
        bytes memory data = abi.encodeCall(basin.grantRole, (basin.MANAGER_ADMIN_ROLE(), newAdmin));
        bytes32 salt = keccak256("test_cancel_then_execute");

        bytes32 id = _scheduleGrantManagerAdmin(newAdmin, salt);

        vm.prank(Ethereum.ALM_FREEZER);
        tl.cancel(id);

        vm.warp(block.timestamp + tl.getMinDelay());

        vm.prank(Ethereum.GROVE_PROXY);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                id,
                bytes32(1 << uint8(TimelockController.OperationState.Ready))
            )
        );
        tl.execute(address(basin), 0, data, bytes32(0), salt);
    }

}

/**********************************************************************************************/
/*** Shared tests — Burn address                                                            ***/
/**********************************************************************************************/

abstract contract Verify_BurnAddress is UsdsUsdcBasinDeploymentForkTestBase {

    function test_burnAddress_hasShares() public view {
        assertEq(basin.shares(address(0)), 1e18);
    }

}

/**********************************************************************************************/
/*** Shared tests — Rate providers                                                          ***/
/**********************************************************************************************/

abstract contract Verify_RateProviders is UsdsUsdcBasinDeploymentForkTestBase {

    function test_swapTokenRateProvider_matchesExpected() public view {
        assertEq(basin.swapTokenRateProvider(), _swapTokenRateProvider());
    }

    function test_collateralTokenRateProvider_matchesExpected() public view {
        assertEq(basin.collateralTokenRateProvider(), _collateralTokenRateProvider());
    }

    function test_creditTokenRateProvider_matchesExpected() public view {
        assertEq(basin.creditTokenRateProvider(), _creditTokenRateProvider());
    }

    function test_fixedRateProvider_returnsExpectedRateAndAge() public view {
        FixedRateProvider fixedRP = FixedRateProvider(basin.swapTokenRateProvider());

        (uint256 rate, uint256 age) = fixedRP.getConversionRateWithAge();

        assertEq(rate, 1e27);
        assertEq(age,  block.timestamp);
    }

    function test_chronicleRateProvider_returnsOracleRateAndAge() public {
        ChronicleRateProvider chronicleRP = ChronicleRateProvider(basin.creditTokenRateProvider());
        address oracle = chronicleRP.oracle();

        vm.store(oracle, keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));
        IChronicleAuthLike(oracle).kiss(address(this));

        (uint256 oracleVal, uint256 oracleAge) = IChronicleOracleLike(oracle).readWithAge();
        (uint256 rpRate, uint256 rpAge)        = chronicleRP.getConversionRateWithAge();

        assertEq(rpRate, oracleVal * 1e27 / 1e18);
        assertEq(rpAge,  oracleAge);
    }

}

/**********************************************************************************************/
/*** Shared tests — UsdsUsdcPocket                                                          ***/
/**********************************************************************************************/

abstract contract Verify_Pocket is UsdsUsdcBasinDeploymentForkTestBase {

    function test_pocket_basinMatches() public view {
        assertEq(pocket.basin(), _basinAddr());
    }

    function test_pocket_usds() public view {
        assertEq(address(pocket.usds()), Ethereum.USDS);
    }

    function test_pocket_usdc() public view {
        assertEq(address(pocket.usdc()), Ethereum.USDC);
    }

    function test_pocket_psm() public view {
        assertEq(pocket.psm(), Deployments.USDS_PSM_WRAPPER);
    }

    function test_pocket_groveProxy() public view {
        assertEq(pocket.groveProxy(), Ethereum.GROVE_PROXY);
    }

    function test_pocket_groveProxyHasUnlimitedUsdsAllowance() public view {
        assertEq(
            IERC20(Ethereum.USDS).allowance(address(pocket), Ethereum.GROVE_PROXY),
            type(uint256).max,
            "GROVE_PROXY should have unlimited USDS transfer privileges on pocket"
        );
    }

}

/**********************************************************************************************/
/*** Shared tests — TokenRedeemer                                                           ***/
/**********************************************************************************************/

abstract contract Verify_Redeemer is UsdsUsdcBasinDeploymentForkTestBase {

    function test_redeemer_isSet() public view {
        assertTrue(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
    }

    function test_redeemer_basinMatches() public {
        require(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
        assertEq(address(ITokenRedeemer(_tokenRedeemerAddr()).basin()), _basinAddr());
    }

    function test_redeemer_creditToken() public {
        require(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
        assertEq(ITokenRedeemer(_tokenRedeemerAddr()).creditToken(), _creditToken());
    }

}

/**********************************************************************************************/
/*** Shared tests — GroveBasin roles, configuration, and parameters                         ***/
/**********************************************************************************************/

abstract contract Verify_Basin is UsdsUsdcBasinDeploymentForkTestBase {

    /*** Roles ***/

    function test_basin_ownerRoleHolder() public view {
        assertTrue(basin.hasRole(basin.OWNER_ROLE(), _ownerAddr()), "owner should hold OWNER_ROLE");
    }

    function test_basin_managerAdminIsGroveProxy() public view {
        assertTrue(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY), "Grove Proxy should have MANAGER_ADMIN_ROLE");
    }

    function test_basin_managerIsRelayer() public view {
        assertTrue(basin.hasRole(basin.MANAGER_ROLE(), Ethereum.ALM_RELAYER), "ALM Relayer should have MANAGER_ROLE");
    }

    function test_basin_pauserIsFreezer() public view {
        assertTrue(basin.hasRole(basin.PAUSER_ROLE(), Ethereum.ALM_FREEZER), "ALM Freezer should have PAUSER_ROLE");
    }

    function test_basin_liquidityProviderIsDpauAlmProxy() public view {
        assertEq(basin.liquidityProvider(), Deployments.DPAU_ALM_PROXY);
    }

    function test_basin_feeClaimerIsZero() public view {
        assertEq(basin.feeClaimer(), address(0));
    }

    /*** Pause flags ***/

    function test_basin_paused_swapCollateralToCredit() public view {
        assertTrue(basin.paused(basin.PAUSED_SWAP_COLLATERAL_TO_CREDIT()));
    }

    function test_basin_paused_swapSwapToCredit() public view {
        assertTrue(basin.paused(basin.PAUSED_SWAP_SWAP_TO_CREDIT()));
    }

    function test_basin_paused_depositCredit() public view {
        assertTrue(basin.paused(basin.PAUSED_DEPOSIT_CREDIT()));
    }

    function test_basin_paused_withdrawCredit() public view {
        assertTrue(basin.paused(basin.PAUSED_WITHDRAW_CREDIT()));
    }

    function test_basin_notPaused_swapCreditToCollateral() public view {
        assertFalse(basin.paused(basin.PAUSED_SWAP_CREDIT_TO_COLLATERAL()));
    }

    function test_basin_notPaused_swapCreditToSwap() public view {
        assertFalse(basin.paused(basin.PAUSED_SWAP_CREDIT_TO_SWAP()));
    }

    /*** Basin instance ***/

    function test_basin_creditTokenMatchesExpected() public view {
        assertEq(basin.creditToken(), _creditToken());
    }

    /*** Pocket ***/

    function test_basin_pocketMatchesDeployment() public view {
        assertEq(basin.pocket(), _pocketAddr());
    }

    function test_basin_pocketMatches() public view {
        assertEq(basin.pocket(), address(pocket));
        assertTrue(basin.pocket() != address(basin));
    }

    /*** Max swap size ***/

    function test_basin_maxSwapSize() public view {
        assertEq(basin.maxSwapSize(), 50_000_000e18);
    }

    function test_basin_maxSwapSizeLowerBound() public view {
        assertEq(basin.maxSwapSizeLowerBound(), 0);
    }

    function test_basin_maxSwapSizeUpperBound() public view {
        assertEq(basin.maxSwapSizeUpperBound(), 1_000_000_000e18);
    }

    /*** Staleness ***/

    function test_basin_stalenessThreshold() public view {
        assertEq(basin.stalenessThreshold(), 1 weeks);
    }

    function test_basin_minStalenessThreshold() public view {
        assertEq(basin.minStalenessThreshold(), 5 minutes);
    }

    function test_basin_maxStalenessThreshold() public view {
        assertEq(basin.maxStalenessThreshold(), 2 weeks);
    }

    /*** Fees ***/

    function test_basin_minFee() public view {
        assertEq(basin.minFee(), 0);
    }

    function test_basin_maxFee() public view {
        assertEq(basin.maxFee(), 500);
    }

    function test_basin_purchaseFee() public view {
        assertEq(basin.purchaseFee(), 0);
    }

    function test_basin_redemptionFee() public view {
        assertEq(basin.redemptionFee(), 0);
    }

    /*** Deployer ***/

    function test_basin_deployerDoesNotHaveOtherRoles() public view {
        assertFalse(basin.hasRole(basin.OWNER_ROLE(),             Deployments.DEPLOYER), "deployer should not have OWNER_ROLE");
        assertFalse(basin.hasRole(basin.MANAGER_ADMIN_ROLE(),     Deployments.DEPLOYER), "deployer should not have MANAGER_ADMIN_ROLE");
        assertFalse(basin.hasRole(basin.MANAGER_ROLE(),           Deployments.DEPLOYER), "deployer should not have MANAGER_ROLE");
        assertFalse(basin.hasRole(basin.PAUSER_ROLE(),            Deployments.DEPLOYER), "deployer should not have PAUSER_ROLE");
        assertFalse(basin.hasRole(basin.REDEEMER_ROLE(),          Deployments.DEPLOYER), "deployer should not have REDEEMER_ROLE");
        assertFalse(basin.hasRole(basin.REDEEMER_CONTRACT_ROLE(), Deployments.DEPLOYER), "deployer should not have REDEEMER_CONTRACT_ROLE");
    }

    /*** Redeemer roles ***/

    function test_basin_redeemerContractRoleIsRedeemer() public {
        require(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
        assertTrue(basin.hasRole(basin.REDEEMER_CONTRACT_ROLE(), _tokenRedeemerAddr()), "TOKEN_REDEEMER should have REDEEMER_CONTRACT_ROLE");
    }

    function test_basin_redeemerRoleHolder() public {
        require(_redeemerAddr() != address(0), "REDEEMER not set");
        assertTrue(basin.hasRole(basin.REDEEMER_ROLE(), _redeemerAddr()), "REDEEMER should have REDEEMER_ROLE");
    }

}

/**********************************************************************************************/
/*** Shared tests — Actions (role revocations, freezing, deposits, withdrawals, swaps)      ***/
/**********************************************************************************************/

abstract contract Verify_Actions is UsdsUsdcBasinDeploymentForkTestBase {

    /*** OWNER_ROLE can revoke MANAGER_ADMIN_ROLE ***/

    function test_action_ownerCanRevokeManagerAdmin() public {
        bytes32 managerAdminRole = basin.MANAGER_ADMIN_ROLE();
        assertTrue(basin.hasRole(managerAdminRole, Ethereum.GROVE_PROXY));

        vm.prank(_ownerAddr());
        basin.revokeRole(managerAdminRole, Ethereum.GROVE_PROXY);

        assertFalse(basin.hasRole(managerAdminRole, Ethereum.GROVE_PROXY));
    }

    /*** MANAGER_ADMIN_ROLE can revoke MANAGER_ROLE, PAUSER_ROLE, REDEEMER_ROLE ***/

    function test_action_managerAdminCanRevokeManagerRole() public {
        bytes32 managerRole = basin.MANAGER_ROLE();
        assertTrue(basin.hasRole(managerRole, Ethereum.ALM_RELAYER));

        vm.prank(Ethereum.GROVE_PROXY);
        basin.revokeRole(managerRole, Ethereum.ALM_RELAYER);

        assertFalse(basin.hasRole(managerRole, Ethereum.ALM_RELAYER));
    }

    function test_action_managerAdminCanRevokePauserRole() public {
        bytes32 pauserRole = basin.PAUSER_ROLE();
        assertTrue(basin.hasRole(pauserRole, Ethereum.ALM_FREEZER));

        vm.prank(Ethereum.GROVE_PROXY);
        basin.revokeRole(pauserRole, Ethereum.ALM_FREEZER);

        assertFalse(basin.hasRole(pauserRole, Ethereum.ALM_FREEZER));
    }

    function test_action_managerAdminCanRevokeRedeemerRole() public {
        address testRedeemer = makeAddr("testRedeemer");

        vm.startPrank(Ethereum.GROVE_PROXY);
        basin.grantRole(basin.REDEEMER_ROLE(), testRedeemer);
        assertTrue(basin.hasRole(basin.REDEEMER_ROLE(), testRedeemer));

        basin.revokeRole(basin.REDEEMER_ROLE(), testRedeemer);
        assertFalse(basin.hasRole(basin.REDEEMER_ROLE(), testRedeemer));
        vm.stopPrank();
    }

    /*** Freezer can set all pause flags and revoke MANAGER_ROLE and REDEEMER_ROLE ***/

    function test_action_freezerCanFreezeAllAndRevokeRoles() public {
        bytes32 redeemerRole = basin.REDEEMER_ROLE();
        bytes32 managerRole  = basin.MANAGER_ROLE();

        address testRedeemer = makeAddr("testRedeemer");
        vm.prank(Ethereum.GROVE_PROXY);
        basin.grantRole(redeemerRole, testRedeemer);

        vm.startPrank(Ethereum.ALM_FREEZER);

        basin.setPaused(bytes4(0));
        basin.setPaused(basin.PAUSED_SWAP_CREDIT_TO_COLLATERAL());
        basin.setPaused(basin.PAUSED_SWAP_CREDIT_TO_SWAP());
        basin.setPaused(basin.PAUSED_SWAP_COLLATERAL_TO_CREDIT());
        basin.setPaused(basin.PAUSED_SWAP_SWAP_TO_CREDIT());
        basin.setPaused(basin.PAUSED_DEPOSIT_CREDIT());
        basin.setPaused(basin.PAUSED_WITHDRAW_CREDIT());

        basin.revokeRole(managerRole, Ethereum.ALM_RELAYER);
        basin.revokeRole(redeemerRole, testRedeemer);

        vm.stopPrank();

        assertTrue(basin.paused(bytes4(0)));
        assertTrue(basin.paused(basin.PAUSED_SWAP_CREDIT_TO_COLLATERAL()));
        assertTrue(basin.paused(basin.PAUSED_SWAP_CREDIT_TO_SWAP()));
        assertTrue(basin.paused(basin.PAUSED_SWAP_COLLATERAL_TO_CREDIT()));
        assertTrue(basin.paused(basin.PAUSED_SWAP_SWAP_TO_CREDIT()));
        assertTrue(basin.paused(basin.PAUSED_DEPOSIT_CREDIT()));
        assertTrue(basin.paused(basin.PAUSED_WITHDRAW_CREDIT()));

        assertFalse(basin.hasRole(managerRole, Ethereum.ALM_RELAYER));
        assertFalse(basin.hasRole(redeemerRole, testRedeemer));
    }

    /*** Full deposit and withdraw (50m USDS) ***/

    function test_action_depositAndWithdrawFull_50m() public {
        address lp            = basin.liquidityProvider();
        assertEq(lp, Deployments.DPAU_ALM_PROXY);

        uint256 depositAmount = 50_000_000e18;

        _deposit(Ethereum.USDS, lp, depositAmount);

        uint256 sharesBefore = basin.shares(lp);
        assertEq(sharesBefore, depositAmount);
        assertEq(basin.shares(address(0)), 1e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 50_000_001e18);

        vm.prank(lp);
        basin.withdraw(Ethereum.USDS, lp, depositAmount);

        assertEq(basin.shares(lp), 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 1e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(lp), depositAmount);
    }

    /*** SwapExactIn and SwapExactOut (credit -> swap/collateral, unpaused directions) ***/

    function test_action_swapExactIn_creditToSwap() public {
        address receiver = makeAddr("receiver");

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);

        uint256 amountIn    = 1_000e6;
        uint256 expectedOut = basin.previewSwapExactIn(_creditToken(), Ethereum.USDS, amountIn);
        assertGt(expectedOut, 0);

        _dealCreditToken(Deployments.DPAU_ALM_PROXY, amountIn);

        vm.startPrank(Deployments.DPAU_ALM_PROXY);
        IERC20(_creditToken()).approve(address(basin), amountIn);
        uint256 amountOut = basin.swapExactIn(_creditToken(), Ethereum.USDS, amountIn, expectedOut, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);
    }

    function test_action_swapExactIn_creditToCollateral() public {
        address receiver = makeAddr("receiver");

        _deposit(Ethereum.USDC, makeAddr("lp1"), 100_000e6);

        uint256 amountIn    = 1_000e6;
        uint256 expectedOut = basin.previewSwapExactIn(_creditToken(), Ethereum.USDC, amountIn);
        assertGt(expectedOut, 0);

        _dealCreditToken(Deployments.DPAU_ALM_PROXY, amountIn);

        vm.startPrank(Deployments.DPAU_ALM_PROXY);
        IERC20(_creditToken()).approve(address(basin), amountIn);
        uint256 amountOut = basin.swapExactIn(_creditToken(), Ethereum.USDC, amountIn, expectedOut, receiver, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

    function test_action_swapExactOut_creditToSwap() public {
        address receiver = makeAddr("receiver");

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);

        uint256 amountOut  = 1_000e18;
        uint256 expectedIn = basin.previewSwapExactOut(_creditToken(), Ethereum.USDS, amountOut);
        assertGt(expectedIn, 0);

        _dealCreditToken(Deployments.DPAU_ALM_PROXY, expectedIn);

        vm.startPrank(Deployments.DPAU_ALM_PROXY);
        IERC20(_creditToken()).approve(address(basin), expectedIn);
        uint256 amountIn = basin.swapExactOut(_creditToken(), Ethereum.USDS, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);
    }

    function test_action_swapExactOut_creditToCollateral() public {
        address receiver = makeAddr("receiver");

        _deposit(Ethereum.USDC, makeAddr("lp1"), 100_000e6);

        uint256 amountOut  = 1_000e6;
        uint256 expectedIn = basin.previewSwapExactOut(_creditToken(), Ethereum.USDC, amountOut);
        assertGt(expectedIn, 0);

        _dealCreditToken(Deployments.DPAU_ALM_PROXY, expectedIn);

        vm.startPrank(Deployments.DPAU_ALM_PROXY);
        IERC20(_creditToken()).approve(address(basin), expectedIn);
        uint256 amountIn = basin.swapExactOut(_creditToken(), Ethereum.USDC, amountOut, expectedIn, receiver, 0);
        vm.stopPrank();

        assertEq(amountIn, expectedIn);
        assertEq(IERC20(Ethereum.USDC).balanceOf(receiver), amountOut);
    }

    /*** Redeemer contract role ***/

    function test_action_managerAdminCanRevokeRedeemerContractRole() public {
        require(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
        bytes32 redeemerContractRole = basin.REDEEMER_CONTRACT_ROLE();
        assertTrue(basin.hasRole(redeemerContractRole, _tokenRedeemerAddr()));

        vm.prank(Ethereum.GROVE_PROXY);
        basin.revokeRole(redeemerContractRole, _tokenRedeemerAddr());

        assertFalse(basin.hasRole(redeemerContractRole, _tokenRedeemerAddr()));
    }

}

/**********************************************************************************************/
/*** Shared tests — ALM Relayer (MANAGER_ROLE) on Pocket                                    ***/
/**********************************************************************************************/

abstract contract Verify_RelayerManager is UsdsUsdcBasinDeploymentForkTestBase {

    function test_relayer_canCallPocketDepositLiquidity() public {
        deal(Ethereum.USDS, address(pocket), 1_000e18);

        vm.prank(Ethereum.ALM_RELAYER);
        uint256 deposited = pocket.depositLiquidity(1_000e18, Ethereum.USDS);

        assertEq(deposited, 1_000e18);
    }

    function test_relayer_canCallPocketWithdrawLiquidity() public {
        deal(Ethereum.USDS, address(pocket), 1_000e18);

        vm.prank(Ethereum.ALM_RELAYER);
        uint256 withdrawn = pocket.withdrawLiquidity(100e18, Ethereum.USDS);

        assertEq(withdrawn, 100e18);
    }

    function test_relayer_canCallPocketSweep() public {
        deal(Ethereum.USDC, address(pocket), 100e6);

        vm.prank(Ethereum.ALM_RELAYER);
        pocket.sweep();

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(pocket)), 0);
        assertGt(IERC20(Ethereum.USDC).balanceOf(_basinAddr()), 0);
    }

    function test_proxy_canCallRedeemerSweep() public {
        require(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
        ITokenRedeemer redeemer = ITokenRedeemer(_tokenRedeemerAddr());

        deal(Ethereum.USDC, _tokenRedeemerAddr(), 100e6);

        vm.prank(Ethereum.GROVE_PROXY);
        redeemer.sweep(Ethereum.USDC, 100e6);

        assertEq(IERC20(Ethereum.USDC).balanceOf(_tokenRedeemerAddr()), 0);
        assertGt(IERC20(Ethereum.USDC).balanceOf(_basinAddr()), 0);
    }

}

/**********************************************************************************************/
/***                                                                                        ***/
/*** JTRSY — Concrete test contracts                                                        ***/
/***                                                                                        ***/
/**********************************************************************************************/

/**********************************************************************************************/
/*** Burn address                                                                           ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_BurnAddress    is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_BurnAddress {}
contract JTRSYUsdsUsdcDeploymentForkTest_Timelock       is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_Timelock {}
contract JTRSYUsdsUsdcDeploymentForkTest_RateProviders  is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_RateProviders {}
contract JTRSYUsdsUsdcDeploymentForkTest_Pocket         is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_Pocket {}
contract JTRSYUsdsUsdcDeploymentForkTest_Basin          is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_Basin {}
contract JTRSYUsdsUsdcDeploymentForkTest_Actions        is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_Actions {}
contract JTRSYUsdsUsdcDeploymentForkTest_RelayerManager is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_RelayerManager {}

contract JTRSYUsdsUsdcDeploymentForkTest_Redeemer is JTRSYUsdsUsdcDeploymentForkTestBase, Verify_Redeemer {

    function test_redeemer_vault() public view {
        assertEq(ITokenRedeemer(_tokenRedeemerAddr()).vault(), Ethereum.CENTRIFUGE_JTRSY);
    }

}

/**********************************************************************************************/
/***                                                                                        ***/
/*** BUIDL — Concrete test contracts                                                        ***/
/***                                                                                        ***/
/**********************************************************************************************/

/**********************************************************************************************/
/*** Burn address                                                                           ***/
/**********************************************************************************************/

contract BUIDLUsdsUsdcDeploymentForkTest_BurnAddress    is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_BurnAddress {}
contract BUIDLUsdsUsdcDeploymentForkTest_Timelock       is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_Timelock {}
contract BUIDLUsdsUsdcDeploymentForkTest_RateProviders  is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_RateProviders {}
contract BUIDLUsdsUsdcDeploymentForkTest_Pocket         is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_Pocket {}
contract BUIDLUsdsUsdcDeploymentForkTest_Basin          is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_Basin {}
contract BUIDLUsdsUsdcDeploymentForkTest_Actions        is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_Actions {}
contract BUIDLUsdsUsdcDeploymentForkTest_RelayerManager is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_RelayerManager {}

contract BUIDLUsdsUsdcDeploymentForkTest_Redeemer is BUIDLUsdsUsdcDeploymentForkTestBase, Verify_Redeemer {

    function test_redeemer_redemptionAddress() public {
        require(_tokenRedeemerAddr() != address(0), "TOKEN_REDEEMER not set");
        assertEq(BUIDLTokenRedeemer(_tokenRedeemerAddr()).redemptionAddress(), Deployments.SECURITIZE_REDEMPTION_ADDRESS);
    }

}

contract BUIDLUsdsUsdcDeploymentForkTest_OldAddressesRevoked is BUIDLUsdsUsdcDeploymentForkTestBase {

    /*** Old Securitize issuer multisig must not hold any timelock roles ***/

    function test_oldIssuer_noProposerRole() public view {
        assertFalse(
            timelock.hasRole(timelock.PROPOSER_ROLE(), Deployments.OLD_SECURITIZE_ISSUER_MULTISIG),
            "old issuer multisig should not have PROPOSER_ROLE"
        );
    }

    function test_oldIssuer_noCancellerRole() public view {
        assertFalse(
            timelock.hasRole(timelock.CANCELLER_ROLE(), Deployments.OLD_SECURITIZE_ISSUER_MULTISIG),
            "old issuer multisig should not have CANCELLER_ROLE"
        );
    }

    function test_oldIssuer_noExecutorRole() public view {
        assertFalse(
            timelock.hasRole(timelock.EXECUTOR_ROLE(), Deployments.OLD_SECURITIZE_ISSUER_MULTISIG),
            "old issuer multisig should not have EXECUTOR_ROLE"
        );
    }

    function test_oldIssuer_noDefaultAdminRole() public view {
        assertFalse(
            timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), Deployments.OLD_SECURITIZE_ISSUER_MULTISIG),
            "old issuer multisig should not have DEFAULT_ADMIN_ROLE"
        );
    }

    /*** Old Securitize redeemer must not hold REDEEMER_ROLE on the basin ***/

    function test_oldRedeemer_noRedeemerRole() public view {
        assertFalse(
            basin.hasRole(basin.REDEEMER_ROLE(), Deployments.OLD_SECURITIZE_REDEEMER),
            "old redeemer address should not have REDEEMER_ROLE"
        );
    }

    /*** Old BUIDLTokenRedeemer must not hold REDEEMER_CONTRACT_ROLE on the basin ***/

    function test_oldTokenRedeemer_noRedeemerContractRole() public view {
        assertFalse(
            basin.hasRole(basin.REDEEMER_CONTRACT_ROLE(), Deployments.OLD_BUIDL_TOKEN_REDEEMER),
            "old BUIDLTokenRedeemer should not have REDEEMER_CONTRACT_ROLE"
        );
    }

}
