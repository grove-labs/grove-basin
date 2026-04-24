// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import { GroveBasin }            from "src/GroveBasin.sol";
import { UsdsUsdcPocket }        from "src/pockets/UsdsUsdcPocket.sol";
import { JTRSYTokenRedeemer }    from "src/redeemers/JTRSYTokenRedeemer.sol";
import { FixedRateProvider }     from "src/rate-providers/FixedRateProvider.sol";
import { ChronicleRateProvider } from "src/rate-providers/ChronicleRateProvider.sol";
import { IChronicleOracleLike }  from "src/interfaces/IChronicleOracleLike.sol";

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

abstract contract JTRSYUsdsUsdcDeploymentForkTestBase is Test {

    /**********************************************************************************************/
    /*** Deployed contract addresses — fill in before running                                   ***/
    /**********************************************************************************************/

    address constant GROVE_BASIN_ADDR    = address(0x34B7385D87793bAc8b94d95d8eF75200787A61F7);  // TODO: deployed GroveBasin
    address constant TIMELOCK_ADDR       = address(0xfB805f2f88e862e687bEBdF120306ef39380F3bf);  // TODO: deployed TimelockController
    address constant TOKEN_REDEEMER_ADDR = address(0x471C4D7B1F38009061e7c545A08732d82Bd54B15);  // TODO: deployed JTRSYTokenRedeemer
    address constant DEPLOYER            = address(0x72dE9Ab4dD9541a0CCD9735A01ed2427D4b9AF54);  // TODO: deployer EOA
    address constant ISSUER_MULTISIG     = address(0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c);  // TODO: proposer on timelock
    address constant REDEEMER_ROLE_ADDR  = address(0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a);  // TODO: REDEEMER_ROLE holder

    /**********************************************************************************************/
    /*** Known addresses                                                                        ***/
    /**********************************************************************************************/

    address constant JTRSY_TOKEN       = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address constant USDS_PSM_WRAPPER  = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address constant FULL_RESTRICTIONS = 0x8E680873b4C77e6088b4Ba0aBD59d100c3D224a4;

    /**********************************************************************************************/
    /*** Contract references                                                                    ***/
    /**********************************************************************************************/

    GroveBasin         public basin;
    TimelockController public timelock;
    JTRSYTokenRedeemer public redeemer;
    UsdsUsdcPocket     public pocket;

    function setUp() public virtual {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        basin    = GroveBasin(GROVE_BASIN_ADDR);
        timelock = TimelockController(payable(TIMELOCK_ADDR));
        redeemer = JTRSYTokenRedeemer(TOKEN_REDEEMER_ADDR);
        pocket   = UsdsUsdcPocket(basin.pocket());

        _addToJTRSYAllowlist(GROVE_BASIN_ADDR);
        _addToJTRSYAllowlist(TOKEN_REDEEMER_ADDR);
    }

    /**********************************************************************************************/
    /*** JTRSY helpers                                                                          ***/
    /**********************************************************************************************/

    function _addToJTRSYAllowlist(address account) internal {
        vm.store(FULL_RESTRICTIONS, keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));
        vm.store(JTRSY_TOKEN, keccak256(abi.encode(FULL_RESTRICTIONS, uint256(0))), bytes32(uint256(1)));
        IFullRestrictionsLike(FULL_RESTRICTIONS).updateMember(JTRSY_TOKEN, account, type(uint64).max);
    }

    function _dealJTRSY(address to, uint256 amount) internal {
        require(amount <= type(uint128).max, "JTRSY balance overflow");
        _addToJTRSYAllowlist(to);

        IShareTokenLike token = IShareTokenLike(JTRSY_TOKEN);
        bytes16 hookData      = token.hookDataOf(to);
        bytes32 slot          = _findBalanceSlot(to);
        bytes32 packed        = bytes32(uint256(uint128(hookData)) << 128 | uint256(amount));
        vm.store(JTRSY_TOKEN, slot, packed);

        assertEq(token.balanceOf(to), amount);
    }

    function _findBalanceSlot(address account) internal returns (bytes32) {
        vm.record();
        IShareTokenLike(JTRSY_TOKEN).balanceOf(account);
        (bytes32[] memory reads,) = vm.accesses(JTRSY_TOKEN);
        require(reads.length > 0, "Could not find balance slot");
        return reads[0];
    }

    function _kissOnChronicle(address oracle, address who) internal {
        vm.store(oracle, keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));
        IChronicleAuthLike(oracle).kiss(who);
    }

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
/*** Burn address                                                                           ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_BurnAddress is JTRSYUsdsUsdcDeploymentForkTestBase {

    function test_burnAddress_hasShares() public view {
        assertGt(basin.shares(address(0)), 0);
    }

}

/**********************************************************************************************/
/*** TimelockController                                                                     ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_Timelock is JTRSYUsdsUsdcDeploymentForkTestBase {

    function test_timelock_onlyAdminIsSelf() public view {
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), ISSUER_MULTISIG));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), Ethereum.GROVE_PROXY));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), Ethereum.ALM_FREEZER));
    }

    function test_timelock_delay() public view {
        assertEq(timelock.getMinDelay(), 7 days);
    }

    function test_timelock_onlyProposerIsIssuerMultisig() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), ISSUER_MULTISIG));
        assertFalse(timelock.hasRole(timelock.PROPOSER_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.PROPOSER_ROLE(), Ethereum.GROVE_PROXY));
        assertFalse(timelock.hasRole(timelock.PROPOSER_ROLE(), Ethereum.ALM_FREEZER));
    }

    function test_timelock_onlyExecutorIsGroveProxy() public view {
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), Ethereum.GROVE_PROXY));
        assertFalse(timelock.hasRole(timelock.EXECUTOR_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.EXECUTOR_ROLE(), ISSUER_MULTISIG));
        assertFalse(timelock.hasRole(timelock.EXECUTOR_ROLE(), Ethereum.ALM_FREEZER));
    }

    function test_timelock_onlyCancellerIsGroveFreezer() public view {
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), Ethereum.ALM_FREEZER));
        assertFalse(timelock.hasRole(timelock.CANCELLER_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.CANCELLER_ROLE(), ISSUER_MULTISIG));
        assertFalse(timelock.hasRole(timelock.CANCELLER_ROLE(), Ethereum.GROVE_PROXY));
    }

    function test_timelock_deployerHasNoRoles() public view {
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.PROPOSER_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.EXECUTOR_ROLE(), DEPLOYER));
        assertFalse(timelock.hasRole(timelock.CANCELLER_ROLE(), DEPLOYER));
    }

}

/**********************************************************************************************/
/*** Rate providers                                                                         ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_RateProviders is JTRSYUsdsUsdcDeploymentForkTestBase {

    function test_fixedRateProvider_returnsExpectedRateAndAge() public view {
        FixedRateProvider fixedRP = FixedRateProvider(basin.swapTokenRateProvider());

        (uint256 rate, uint256 age) = fixedRP.getConversionRateWithAge();

        assertEq(rate, 1e27);
        assertEq(age,  block.timestamp);
    }

    function test_chronicleRateProvider_returnsOracleRateAndAge() public {
        ChronicleRateProvider chronicleRP = ChronicleRateProvider(basin.creditTokenRateProvider());
        address oracle = chronicleRP.oracle();

        _kissOnChronicle(oracle, address(this));

        (uint256 oracleVal, uint256 oracleAge) = IChronicleOracleLike(oracle).readWithAge();
        (uint256 rpRate, uint256 rpAge)         = chronicleRP.getConversionRateWithAge();

        assertEq(rpRate, oracleVal * 1e27 / 1e18);
        assertEq(rpAge,  oracleAge);
    }

}

/**********************************************************************************************/
/*** UsdsUsdcPocket                                                                         ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_Pocket is JTRSYUsdsUsdcDeploymentForkTestBase {

    function test_pocket_basinMatches() public view {
        assertEq(pocket.basin(), GROVE_BASIN_ADDR);
    }

    function test_pocket_usds() public view {
        assertEq(address(pocket.usds()), Ethereum.USDS);
    }

    function test_pocket_usdc() public view {
        assertEq(address(pocket.usdc()), Ethereum.USDC);
    }

    function test_pocket_psm() public view {
        assertEq(pocket.psm(), USDS_PSM_WRAPPER);
    }

    function test_pocket_groveProxy() public view {
        assertEq(pocket.groveProxy(), Ethereum.GROVE_PROXY);
    }

}

/**********************************************************************************************/
/*** TokenRedeemer                                                                          ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_Redeemer is JTRSYUsdsUsdcDeploymentForkTestBase {

    function test_redeemer_basinMatches() public view {
        assertEq(address(redeemer.basin()), GROVE_BASIN_ADDR);
    }

    function test_redeemer_creditToken() public view {
        assertEq(redeemer.creditToken(), JTRSY_TOKEN);
    }

    function test_redeemer_vault() public view {
        assertEq(redeemer.vault(), Ethereum.CENTRIFUGE_JTRSY);
    }

}

/**********************************************************************************************/
/*** GroveBasin — roles, configuration, and parameters                                      ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_Basin is JTRSYUsdsUsdcDeploymentForkTestBase {

    /*** Roles ***/

    function test_basin_deployerHasNoRoles() public view {
        assertFalse(basin.hasRole(basin.OWNER_ROLE(),              DEPLOYER));
        assertFalse(basin.hasRole(basin.MANAGER_ADMIN_ROLE(),      DEPLOYER));
        assertFalse(basin.hasRole(basin.MANAGER_ROLE(),            DEPLOYER));
        assertFalse(basin.hasRole(basin.PAUSER_ROLE(),             DEPLOYER));
        assertFalse(basin.hasRole(basin.REDEEMER_ROLE(),           DEPLOYER));
        assertFalse(basin.hasRole(basin.REDEEMER_CONTRACT_ROLE(),  DEPLOYER));
    }

    function test_basin_defaultAdminIsTimelock() public view {
        assertTrue(basin.hasRole(basin.OWNER_ROLE(), TIMELOCK_ADDR));
        assertFalse(basin.hasRole(basin.OWNER_ROLE(), DEPLOYER));
    }

    function test_basin_managerAdminIsGroveProxy() public view {
        assertTrue(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), Ethereum.GROVE_PROXY));
        assertFalse(basin.hasRole(basin.MANAGER_ADMIN_ROLE(), DEPLOYER));
    }

    function test_basin_managerIsRelayer() public view {
        assertTrue(basin.hasRole(basin.MANAGER_ROLE(), Ethereum.ALM_RELAYER));
        assertFalse(basin.hasRole(basin.MANAGER_ROLE(), DEPLOYER));
    }

    function test_basin_pauserIsFreezer() public view {
        assertTrue(basin.hasRole(basin.PAUSER_ROLE(), Ethereum.ALM_FREEZER));
        assertFalse(basin.hasRole(basin.PAUSER_ROLE(), DEPLOYER));
    }

    function test_basin_liquidityProviderIsAlmProxy() public view {
        assertEq(basin.liquidityProvider(), Ethereum.ALM_PROXY);
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

    /*** Pocket ***/

    function test_basin_pocketMatches() public view {
        assertEq(basin.pocket(), address(pocket));
        assertTrue(basin.pocket() != address(basin));
    }

    /*** Redeemer contract role ***/

    function test_basin_redeemerContractRoleIsRedeemer() public view {
        assertTrue(basin.hasRole(basin.REDEEMER_CONTRACT_ROLE(), TOKEN_REDEEMER_ADDR));
    }

    function test_basin_redeemerRoleHolder() public view {
        assertTrue(basin.hasRole(basin.REDEEMER_ROLE(), REDEEMER_ROLE_ADDR));
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

}

/**********************************************************************************************/
/*** Actions — simulate role revocations, freezing, deposits, withdrawals, swaps            ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_Actions is JTRSYUsdsUsdcDeploymentForkTestBase {

    /*** DEFAULT_ADMIN_ROLE can revoke MANAGER_ADMIN_ROLE ***/

    function test_action_ownerCanRevokeManagerAdmin() public {
        bytes32 managerAdminRole = basin.MANAGER_ADMIN_ROLE();
        assertTrue(basin.hasRole(managerAdminRole, Ethereum.GROVE_PROXY));

        vm.prank(TIMELOCK_ADDR);
        basin.revokeRole(managerAdminRole, Ethereum.GROVE_PROXY);

        assertFalse(basin.hasRole(managerAdminRole, Ethereum.GROVE_PROXY));
    }

    /*** MANAGER_ADMIN_ROLE can revoke MANAGER_ROLE, PAUSER_ROLE, REDEEMER_CONTRACT_ROLE, REDEEMER_ROLE ***/

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

    function test_action_managerAdminCanRevokeRedeemerContractRole() public {
        bytes32 redeemerContractRole = basin.REDEEMER_CONTRACT_ROLE();
        assertTrue(basin.hasRole(redeemerContractRole, TOKEN_REDEEMER_ADDR));

        vm.prank(Ethereum.GROVE_PROXY);
        basin.revokeRole(redeemerContractRole, TOKEN_REDEEMER_ADDR);

        assertFalse(basin.hasRole(redeemerContractRole, TOKEN_REDEEMER_ADDR));
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
        uint256 depositAmount = 50_000_000e18;

        _deposit(Ethereum.USDS, lp, depositAmount);

        uint256 sharesBefore = basin.shares(lp);
        assertEq(sharesBefore, depositAmount);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 50_000_001e18);

        vm.prank(lp);
        basin.withdraw(Ethereum.USDS, lp, depositAmount);

        assertEq(basin.shares(lp), 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(pocket)), 1e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(lp), depositAmount);
    }

    /*** SwapExactIn and SwapExactOut (JTRSY -> USDS, unpaused direction) ***/

    function test_action_swapExactIn() public {
        address receiver = makeAddr("receiver");

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);

        uint256 amountIn = 1_000e6;
        _dealJTRSY(Ethereum.ALM_PROXY, amountIn);

        vm.startPrank(Ethereum.ALM_PROXY);
        IERC20(JTRSY_TOKEN).approve(address(basin), amountIn);
        uint256 amountOut = basin.swapExactIn(JTRSY_TOKEN, Ethereum.USDS, amountIn, 0, receiver, 0);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);

        console.log("swapExactIn amountIn  (JTRSY):", amountIn);
        console.log("swapExactIn amountOut (USDS):",  amountOut);
    }

    function test_action_swapExactOut() public {
        address receiver = makeAddr("receiver");

        _deposit(Ethereum.USDS, makeAddr("lp1"), 100_000e18);

        uint256 amountOut = 1_000e18;
        uint256 maxIn     = 2_000e6;
        _dealJTRSY(Ethereum.ALM_PROXY, maxIn);

        vm.startPrank(Ethereum.ALM_PROXY);
        IERC20(JTRSY_TOKEN).approve(address(basin), maxIn);
        uint256 amountIn = basin.swapExactOut(JTRSY_TOKEN, Ethereum.USDS, amountOut, maxIn, receiver, 0);
        vm.stopPrank();

        assertGt(amountIn, 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(receiver), amountOut);

        console.log("swapExactOut amountIn  (JTRSY):", amountIn);
        console.log("swapExactOut amountOut (USDS):",  amountOut);
    }

}

/**********************************************************************************************/
/*** ALM Relayer (MANAGER_ROLE) — can call manager-gated functions on Pocket and Redeemer   ***/
/**********************************************************************************************/

contract JTRSYUsdsUsdcDeploymentForkTest_RelayerManager is JTRSYUsdsUsdcDeploymentForkTestBase {

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
        assertGt(IERC20(Ethereum.USDC).balanceOf(GROVE_BASIN_ADDR), 0);
    }

    function test_proxy_canCallRedeemerSweep() public {
        deal(Ethereum.USDC, TOKEN_REDEEMER_ADDR, 100e6);

        vm.prank(Ethereum.GROVE_PROXY);
        redeemer.sweep(Ethereum.USDC, 100e6);

        assertEq(IERC20(Ethereum.USDC).balanceOf(TOKEN_REDEEMER_ADDR), 0);
        assertGt(IERC20(Ethereum.USDC).balanceOf(GROVE_BASIN_ADDR), 0);
    }

}
