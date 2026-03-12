// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import "forge-std/Test.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GroveBasin }  from "src/GroveBasin.sol";
import { UsdtPocket }  from "src/UsdtPocket.sol";

import { ForkTestBase }     from "test/fork/ForkTestBase.sol";
import { MockRateProvider } from "test/mocks/MockRateProvider.sol";
import { MockAaveV3Pool }   from "test/mocks/MockAaveV3Pool.sol";

/**********************************************************************************************/
/*** JTRSY helpers (reused from JTRSYForkTest)                                              ***/
/**********************************************************************************************/

interface IFullRestrictionsLike {
    function updateMember(address token, address user, uint64 validUntil) external;
    function isMember(address token, address user) external view returns (bool isValid, uint64 validUntil);
    function wards(address who) external view returns (uint256);
}

interface IShareTokenLike {
    function balanceOf(address) external view returns (uint256);
    function hookDataOf(address) external view returns (bytes16);
}

/**********************************************************************************************/
/*** Test 1: JTRSY multi-swap (5+ sequential swaps with real JTRSY)                         ***/
/**********************************************************************************************/

contract SecurityForkTest_JTRSYMultiSwap is ForkTestBase {

    address public constant JTRSY_TOKEN       = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address public constant FULL_RESTRICTIONS = 0x8E680873b4C77e6088b4Ba0aBD59d100c3D224a4;

    IFullRestrictionsLike public fullRestrictions = IFullRestrictionsLike(FULL_RESTRICTIONS);

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function _initTokens() internal override {
        swapToken       = IERC20(Ethereum.USDS);
        collateralToken = IERC20(Ethereum.USDC);
        creditToken     = IERC20(JTRSY_TOKEN);
    }

    function _initRateProviders() internal override {
        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1.05e27);
    }

    function _postDeploy() internal override {
        _addToJTRSYAllowlist(address(groveBasin));
        _addToJTRSYAllowlist(pocket);
        _addToJTRSYAllowlist(swapper);
        _addToJTRSYAllowlist(receiver);

        // Seed liquidity
        _deposit(Ethereum.USDS, makeAddr("lp1"), 500_000e18);
        _deposit(Ethereum.USDC, makeAddr("lp2"), 500_000e6);
        _deposit(JTRSY_TOKEN,   makeAddr("lp3"), 500_000e6);
    }

    function _dealToken(address token, address to, uint256 amount) internal override {
        if (token == JTRSY_TOKEN) {
            _dealJTRSY(to, amount);
        } else {
            deal(token, to, amount);
        }
    }

    /**********************************************************************************************/
    /*** JTRSY allowlist / deal helpers                                                         ***/
    /**********************************************************************************************/

    function _addToJTRSYAllowlist(address account) internal {
        vm.store(
            FULL_RESTRICTIONS,
            keccak256(abi.encode(address(this), uint256(0))),
            bytes32(uint256(1))
        );
        fullRestrictions.updateMember(JTRSY_TOKEN, account, type(uint64).max);
    }

    function _dealJTRSY(address to, uint256 amount) internal {
        require(amount <= type(uint128).max, "JTRSY balance overflow");
        _addToJTRSYAllowlist(to);

        IShareTokenLike token = IShareTokenLike(JTRSY_TOKEN);
        bytes16 hookData = token.hookDataOf(to);
        bytes32 slot = _findBalanceSlot(to);

        bytes32 packed = bytes32(uint256(uint128(hookData)) << 128 | uint256(amount));
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

    /**********************************************************************************************/
    /*** Multi-swap test: 6 sequential swaps alternating swapExactIn / swapExactOut             ***/
    /**********************************************************************************************/

    function test_fork_multiSwap_JTRSY_sixSequentialSwaps() public {
        // --- Swap 1: swapExactIn — USDS -> JTRSY (swapToCredit) ---
        uint256 amountIn1 = 5000e18;
        _dealToken(Ethereum.USDS, swapper, amountIn1);

        uint256 preview1 = groveBasin.previewSwapExactIn(Ethereum.USDS, JTRSY_TOKEN, amountIn1);
        assertGt(preview1, 0, "Swap 1: preview should be > 0");

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), amountIn1);
        uint256 out1 = groveBasin.swapExactIn(Ethereum.USDS, JTRSY_TOKEN, amountIn1, 0, receiver, 0);
        vm.stopPrank();

        assertEq(out1, preview1, "Swap 1: actual should match preview");
        assertEq(IERC20(JTRSY_TOKEN).balanceOf(receiver), out1, "Swap 1: receiver balance");

        uint256 receiverJtrsyAfter1 = IERC20(JTRSY_TOKEN).balanceOf(receiver);

        // --- Swap 2: swapExactIn — JTRSY -> USDS (creditToSwap) ---
        uint256 amountIn2 = receiverJtrsyAfter1 / 2;  // Use half the JTRSY received
        _dealToken(JTRSY_TOKEN, swapper, amountIn2);

        uint256 preview2 = groveBasin.previewSwapExactIn(JTRSY_TOKEN, Ethereum.USDS, amountIn2);
        assertGt(preview2, 0, "Swap 2: preview should be > 0");

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), amountIn2);
        uint256 out2 = groveBasin.swapExactIn(JTRSY_TOKEN, Ethereum.USDS, amountIn2, 0, receiver, 0);
        vm.stopPrank();

        assertEq(out2, preview2, "Swap 2: actual should match preview");
        assertGt(IERC20(Ethereum.USDS).balanceOf(receiver), 0, "Swap 2: receiver got USDS");

        // --- Swap 3: swapExactOut — USDC -> JTRSY (collateralToCredit) ---
        uint256 desiredOut3 = 2000e6;  // JTRSY has 6 decimals
        uint256 preview3 = groveBasin.previewSwapExactOut(Ethereum.USDC, JTRSY_TOKEN, desiredOut3);
        assertGt(preview3, 0, "Swap 3: preview should be > 0");

        _dealToken(Ethereum.USDC, swapper, preview3);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDC).approve(address(groveBasin), preview3);
        uint256 in3 = groveBasin.swapExactOut(Ethereum.USDC, JTRSY_TOKEN, desiredOut3, preview3, receiver, 0);
        vm.stopPrank();

        assertEq(in3, preview3, "Swap 3: actual in should match preview");

        // --- Swap 4: swapExactIn — JTRSY -> USDC (creditToCollateral) ---
        uint256 amountIn4 = 1500e6;
        _dealToken(JTRSY_TOKEN, swapper, amountIn4);

        uint256 preview4 = groveBasin.previewSwapExactIn(JTRSY_TOKEN, Ethereum.USDC, amountIn4);
        assertGt(preview4, 0, "Swap 4: preview should be > 0");

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), amountIn4);
        uint256 out4 = groveBasin.swapExactIn(JTRSY_TOKEN, Ethereum.USDC, amountIn4, 0, receiver, 0);
        vm.stopPrank();

        assertEq(out4, preview4, "Swap 4: actual should match preview");

        // --- Swap 5: swapExactOut — JTRSY -> USDS (creditToSwap via exactOut) ---
        uint256 desiredOut5 = 3000e18;
        uint256 preview5 = groveBasin.previewSwapExactOut(JTRSY_TOKEN, Ethereum.USDS, desiredOut5);
        assertGt(preview5, 0, "Swap 5: preview should be > 0");

        _dealToken(JTRSY_TOKEN, swapper, preview5);

        vm.startPrank(swapper);
        IERC20(JTRSY_TOKEN).approve(address(groveBasin), preview5);
        uint256 in5 = groveBasin.swapExactOut(JTRSY_TOKEN, Ethereum.USDS, desiredOut5, preview5, receiver, 0);
        vm.stopPrank();

        assertEq(in5, preview5, "Swap 5: actual in should match preview");

        // --- Swap 6: swapExactOut — USDS -> JTRSY (swapToCredit via exactOut) ---
        uint256 desiredOut6 = 1000e6;  // JTRSY 6 decimals
        uint256 preview6 = groveBasin.previewSwapExactOut(Ethereum.USDS, JTRSY_TOKEN, desiredOut6);
        assertGt(preview6, 0, "Swap 6: preview should be > 0");

        _dealToken(Ethereum.USDS, swapper, preview6);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), preview6);
        uint256 in6 = groveBasin.swapExactOut(Ethereum.USDS, JTRSY_TOKEN, desiredOut6, preview6, receiver, 0);
        vm.stopPrank();

        assertEq(in6, preview6, "Swap 6: actual in should match preview");

        // --- Final sanity: Basin still holds reasonable liquidity ---
        assertGt(groveBasin.totalAssets(), 0, "Basin totalAssets still positive after 6 swaps");
    }

}

/**********************************************************************************************/
/*** Test 2: USDC/USDT/USDS multi-swap with real stablecoin contracts                      ***/
/**********************************************************************************************/

contract SecurityForkTest_StablecoinMultiSwap is Test {

    address public owner   = makeAddr("owner");
    address public swapper = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    GroveBasin     public groveBasin;
    MockERC20      public mockCredit;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 24_522_338);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1e27);

        // Deploy a mock credit token (18 decimals)
        mockCredit = new MockERC20("MockCredit", "mCRD", 18);

        // swapToken = USDT, collateralToken = USDC, creditToken = mockCredit
        groveBasin = new GroveBasin(
            owner,
            Ethereum.USDT,
            Ethereum.USDC,
            address(mockCredit),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        vm.stopPrank();

        // Seed liquidity with all three tokens
        _deposit(Ethereum.USDT,        makeAddr("lp1"), 200_000e6);
        _deposit(Ethereum.USDC,        makeAddr("lp2"), 200_000e6);
        _deposit(address(mockCredit),   makeAddr("lp3"), 200_000e18);
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, user);

        if (asset == address(mockCredit)) {
            mockCredit.mint(user, amount);
        } else {
            deal(asset, user, amount);
        }

        vm.startPrank(user);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

    function test_fork_multiSwap_USDC_USDT_USDS_stablecoins() public {
        // --- Swap 1: swapExactIn — mockCredit -> USDT (creditToSwap) ---
        uint256 amountIn1 = 5000e18;
        mockCredit.mint(swapper, amountIn1);

        uint256 preview1 = groveBasin.previewSwapExactIn(address(mockCredit), Ethereum.USDT, amountIn1);
        assertGt(preview1, 0, "Swap 1: preview > 0");

        vm.startPrank(swapper);
        mockCredit.approve(address(groveBasin), amountIn1);
        uint256 out1 = groveBasin.swapExactIn(address(mockCredit), Ethereum.USDT, amountIn1, 0, receiver, 0);
        vm.stopPrank();

        assertEq(out1, preview1, "Swap 1: actual == preview");
        assertEq(IERC20(Ethereum.USDT).balanceOf(receiver), out1, "Swap 1: receiver USDT balance");

        // --- Swap 2: swapExactIn — USDT -> mockCredit (swapToCredit) ---
        uint256 amountIn2 = 3000e6;
        deal(Ethereum.USDT, swapper, amountIn2);

        uint256 preview2 = groveBasin.previewSwapExactIn(Ethereum.USDT, address(mockCredit), amountIn2);
        assertGt(preview2, 0, "Swap 2: preview > 0");

        vm.startPrank(swapper);
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(Ethereum.USDT), address(groveBasin), amountIn2);
        uint256 out2 = groveBasin.swapExactIn(Ethereum.USDT, address(mockCredit), amountIn2, 0, receiver, 0);
        vm.stopPrank();

        assertEq(out2, preview2, "Swap 2: actual == preview");

        // --- Swap 3: swapExactOut — USDC -> mockCredit (collateralToCredit) ---
        uint256 desiredOut3 = 4000e18;
        uint256 preview3 = groveBasin.previewSwapExactOut(Ethereum.USDC, address(mockCredit), desiredOut3);
        assertGt(preview3, 0, "Swap 3: preview > 0");

        deal(Ethereum.USDC, swapper, preview3);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDC).approve(address(groveBasin), preview3);
        uint256 in3 = groveBasin.swapExactOut(Ethereum.USDC, address(mockCredit), desiredOut3, preview3, receiver, 0);
        vm.stopPrank();

        assertEq(in3, preview3, "Swap 3: actual in == preview");

        // --- Swap 4: swapExactIn — mockCredit -> USDC (creditToCollateral) ---
        uint256 amountIn4 = 2000e18;
        mockCredit.mint(swapper, amountIn4);

        uint256 preview4 = groveBasin.previewSwapExactIn(address(mockCredit), Ethereum.USDC, amountIn4);
        assertGt(preview4, 0, "Swap 4: preview > 0");

        vm.startPrank(swapper);
        mockCredit.approve(address(groveBasin), amountIn4);
        uint256 out4 = groveBasin.swapExactIn(address(mockCredit), Ethereum.USDC, amountIn4, 0, receiver, 0);
        vm.stopPrank();

        assertEq(out4, preview4, "Swap 4: actual == preview");

        // --- Swap 5: swapExactOut — mockCredit -> USDT (creditToSwap via exactOut) ---
        uint256 desiredOut5 = 1500e6;
        uint256 preview5 = groveBasin.previewSwapExactOut(address(mockCredit), Ethereum.USDT, desiredOut5);
        assertGt(preview5, 0, "Swap 5: preview > 0");

        mockCredit.mint(swapper, preview5);

        vm.startPrank(swapper);
        mockCredit.approve(address(groveBasin), preview5);
        uint256 in5 = groveBasin.swapExactOut(address(mockCredit), Ethereum.USDT, desiredOut5, preview5, receiver, 0);
        vm.stopPrank();

        assertEq(in5, preview5, "Swap 5: actual in == preview");

        // --- Final sanity ---
        assertGt(groveBasin.totalAssets(), 0, "Basin totalAssets still positive after 5 swaps");
    }

}

/**********************************************************************************************/
/*** Test 3: Pocket exhaustion — swaps drain idle balance requiring Aave withdrawal         ***/
/**********************************************************************************************/

contract SecurityForkTest_PocketExhaustion is Test {

    address public owner   = makeAddr("owner");
    address public manager = makeAddr("manager");
    address public swapper = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    GroveBasin     public groveBasin;
    UsdtPocket     public pocket;

    MockRateProvider public swapTokenRateProvider;
    MockRateProvider public collateralTokenRateProvider;
    MockRateProvider public creditTokenRateProvider;

    MockERC20      public mockAUsdt;
    MockAaveV3Pool public mockAaveV3Pool;

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 24_522_338);

        swapTokenRateProvider       = new MockRateProvider();
        collateralTokenRateProvider = new MockRateProvider();
        creditTokenRateProvider     = new MockRateProvider();

        swapTokenRateProvider.__setConversionRate(1e27);
        collateralTokenRateProvider.__setConversionRate(1e27);
        creditTokenRateProvider.__setConversionRate(1e27);

        // swapToken = USDT, collateralToken = USDC, creditToken = USDS
        groveBasin = new GroveBasin(
            owner,
            Ethereum.USDT,
            Ethereum.USDC,
            Ethereum.USDS,
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        mockAUsdt      = new MockERC20("aUSDT", "aUSDT", 6);
        mockAaveV3Pool = new MockAaveV3Pool(address(mockAUsdt), Ethereum.USDT);

        // Fund the mock Aave pool with USDT for withdrawals
        deal(Ethereum.USDT, address(mockAaveV3Pool), 10_000_000e6);
        mockAUsdt.mint(address(mockAaveV3Pool), 10_000_000e6);

        pocket = new UsdtPocket(
            address(groveBasin),
            manager,
            Ethereum.USDT,
            address(mockAUsdt),
            address(mockAaveV3Pool)
        );

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.MANAGER_ADMIN_ROLE(), owner);
        groveBasin.setMaxSwapSize(10_000_000_000_000_000e18);
        groveBasin.setPocket(address(pocket));
        vm.stopPrank();

        // Seed liquidity: deposit USDT (goes through pocket), USDC, and USDS
        _deposit(Ethereum.USDS, makeAddr("lp1"), 200_000e18);
        _deposit(Ethereum.USDC, makeAddr("lp2"), 200_000e6);
        _deposit(Ethereum.USDT, makeAddr("lp3"), 200_000e6);
    }

    function _deposit(address asset, address user, uint256 amount) internal {
        bytes32 lpRole = groveBasin.LIQUIDITY_PROVIDER_ROLE();
        vm.prank(owner);
        groveBasin.grantRole(lpRole, user);

        deal(asset, user, amount);
        vm.startPrank(user);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), 0);
        SafeERC20.safeApprove(IERC20(asset), address(groveBasin), amount);
        groveBasin.deposit(asset, user, amount);
        vm.stopPrank();
    }

    function test_fork_pocketExhaustion_swapsDrainIdleRequiringAaveWithdrawal() public {
        // After depositing USDT through Basin, the pocket auto-deposits to Aave.
        // Pocket idle = 0, aUSDT = 200_000e6. Simulate a state where pocket has
        // some idle USDT and some in Aave, then perform swaps that exceed idle.

        // Verify initial state: pocket has aUSDT from deposits, no idle USDT
        uint256 aUsdtInitial = mockAUsdt.balanceOf(address(pocket));
        assertGt(aUsdtInitial, 0, "Pocket should have aUSDT from deposits");

        uint256 pocketIdleInitial = IERC20(Ethereum.USDT).balanceOf(address(pocket));
        assertEq(pocketIdleInitial, 0, "Pocket idle USDT should be 0 (all in Aave)");

        // Give pocket a small idle buffer (simulate partial withdrawal by manager)
        uint256 idleBuffer = 2000e6;
        deal(Ethereum.USDT, address(pocket), idleBuffer);

        uint256 pocketIdleAfter = IERC20(Ethereum.USDT).balanceOf(address(pocket));
        assertEq(pocketIdleAfter, idleBuffer, "Pocket idle buffer set");

        // Step 1: Swap that exceeds idle balance, forcing Aave withdrawal
        // Swap USDS -> USDT (creditToSwap). Need more USDT than the idle buffer.
        uint256 swapAmount1 = 5000e18;  // 5000 USDS => ~5000 USDT at 1:1 rate
        deal(Ethereum.USDS, swapper, swapAmount1);

        uint256 preview1 = groveBasin.previewSwapExactIn(Ethereum.USDS, Ethereum.USDT, swapAmount1);
        assertGt(preview1, idleBuffer, "Swap output should exceed idle buffer");

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), swapAmount1);
        uint256 amountOut1 = groveBasin.swapExactIn(
            Ethereum.USDS,
            Ethereum.USDT,
            swapAmount1,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut1, preview1, "Swap 1 output should match preview");
        assertEq(IERC20(Ethereum.USDT).balanceOf(receiver), amountOut1, "Receiver got correct USDT");

        // Verify pocket's aUSDT was drawn down (Aave withdrawal occurred)
        uint256 aUsdtAfterSwap1 = mockAUsdt.balanceOf(address(pocket));
        assertLt(aUsdtAfterSwap1, aUsdtInitial, "aUSDT should decrease after Aave withdrawal");

        // Step 2: Perform another large swap to further drain pocket
        uint256 swapAmount2 = 10_000e18;
        deal(Ethereum.USDS, swapper, swapAmount2);

        uint256 preview2 = groveBasin.previewSwapExactIn(Ethereum.USDS, Ethereum.USDT, swapAmount2);
        assertGt(preview2, 0, "Second swap preview > 0");

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), swapAmount2);
        uint256 amountOut2 = groveBasin.swapExactIn(
            Ethereum.USDS,
            Ethereum.USDT,
            swapAmount2,
            0,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(amountOut2, preview2, "Second swap output matches preview");
        assertGt(IERC20(Ethereum.USDT).balanceOf(receiver), amountOut1, "Receiver accumulated USDT");

        // Verify further aUSDT drawdown
        uint256 aUsdtAfterSwap2 = mockAUsdt.balanceOf(address(pocket));
        assertLt(aUsdtAfterSwap2, aUsdtAfterSwap1, "aUSDT further decreased");

        // Step 3: Verify pocket reports correct available balance
        uint256 available = pocket.availableBalance(Ethereum.USDT);
        uint256 pocketUsdtFinal = IERC20(Ethereum.USDT).balanceOf(address(pocket));
        uint256 aUsdtFinal = mockAUsdt.balanceOf(address(pocket));
        assertEq(available, pocketUsdtFinal + aUsdtFinal, "availableBalance = idle + aUSDT");

        // Step 4: Perform swapExactOut that also requires Aave withdrawal
        uint256 desiredOut = 3000e6;
        uint256 previewIn = groveBasin.previewSwapExactOut(Ethereum.USDS, Ethereum.USDT, desiredOut);
        assertGt(previewIn, 0, "ExactOut preview > 0");

        deal(Ethereum.USDS, swapper, previewIn);

        vm.startPrank(swapper);
        IERC20(Ethereum.USDS).approve(address(groveBasin), previewIn);
        uint256 actualIn = groveBasin.swapExactOut(
            Ethereum.USDS,
            Ethereum.USDT,
            desiredOut,
            previewIn,
            receiver,
            0
        );
        vm.stopPrank();

        assertEq(actualIn, previewIn, "ExactOut swap in matches preview");

        // Final: Basin is still functional
        assertGt(groveBasin.totalAssets(), 0, "Basin totalAssets positive after exhaustion swaps");
    }

}
