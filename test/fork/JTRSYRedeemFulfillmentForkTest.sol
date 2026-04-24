// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { JTRSYGroveBasinForkTestBase } from "test/fork/JTRSYGroveBasinForkTest.sol";

interface ICentrifugeAsyncVault {
    function poolId()                          external view returns (uint64);
    function scId()                            external view returns (bytes16);
    function maxWithdraw(address controller)   external view returns (uint256);
    function maxRedeem(address controller)     external view returns (uint256);
}

interface ICentrifugeAsyncRequestManager {
    function callback(uint64 poolId, bytes16 scId, uint128 assetId, bytes calldata payload) external;
    function poolEscrow(uint64 poolId) external view returns (address);
    function vaultRegistry()           external view returns (address);
    function spoke()                   external view returns (address);
}

interface ICentrifugeVaultRegistry {
    function vaultDetails(address vault)
        external view
        returns (uint128 assetId, address asset, uint256 tokenId, bool isLinked);
}

interface ICentrifugePoolEscrow {
    function deposit(bytes16 scId, address asset, uint256 tokenId, uint128 value) external;
}

interface ICentrifugeSpoke {
    function pricePoolPerShare(uint64 poolId, bytes16 scId, bool checkValidity)
        external view returns (uint128 price);
    function pricePoolPerAsset(uint64 poolId, bytes16 scId, uint128 assetId, bool checkValidity)
        external view returns (uint128 price);
}

contract JTRSYRedeemDustForkTest is JTRSYGroveBasinForkTestBase {

    // Centrifuge V3 mainnet AsyncRequestManager (env/ethereum.json in protocol-v3 repo).
    address public constant ASYNC_REQUEST_MANAGER = 0xF48256AbDDf96EcDDc4B3DbD23E8C1921f9761Ae;

    // RequestCallbackType enum values from RequestCallbackMessageLib.
    uint8 internal constant CALLBACK_REVOKED_SHARES           = 3;
    uint8 internal constant CALLBACK_FULFILLED_REDEEM_REQUEST = 5;

    address public issuer = makeAddr("issuer");

    uint64  public poolId;
    bytes16 public scId;
    uint128 public assetId;
    address public centrifugePoolEscrow;
    address public centrifugeSpoke;

    // Live JTRSY prices read from the Spoke at the fork block. Both are D18 fixed-point.
    uint128 public livePricePoolPerShare;
    uint128 public livePricePoolPerAsset;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.grantRole(groveBasin.REDEEMER_ROLE(), issuer);
        vm.stopPrank();

        ICentrifugeAsyncVault          v   = ICentrifugeAsyncVault(CENTRIFUGE_JTRSY_VAULT);
        ICentrifugeAsyncRequestManager mgr = ICentrifugeAsyncRequestManager(ASYNC_REQUEST_MANAGER);

        poolId               = v.poolId();
        scId                 = v.scId();
        centrifugePoolEscrow = mgr.poolEscrow(poolId);
        centrifugeSpoke      = mgr.spoke();
        (assetId,,,)         = ICentrifugeVaultRegistry(mgr.vaultRegistry())
            .vaultDetails(CENTRIFUGE_JTRSY_VAULT);

        livePricePoolPerShare = ICentrifugeSpoke(centrifugeSpoke)
            .pricePoolPerShare(poolId, scId, false);
        livePricePoolPerAsset = ICentrifugeSpoke(centrifugeSpoke)
            .pricePoolPerAsset(poolId, scId, assetId, false);

        // Make ourselves a ward on AsyncRequestManager (so we can deliver hub-style fulfillment
        // callbacks) and on the pool escrow (so we can credit asset accounting in `_fulfillRedeem`).
        // wards mapping sits at slot 0 in both (Auth.sol pattern).
        _becomeWard(ASYNC_REQUEST_MANAGER);
        _becomeWard(centrifugePoolEscrow);

        vm.label(ASYNC_REQUEST_MANAGER, "asyncRequestManager");
        vm.label(centrifugePoolEscrow,  "centrifugePoolEscrow");
    }

    function _becomeWard(address target) internal {
        vm.store(
            target,
            keccak256(abi.encode(address(this), uint256(0))),
            bytes32(uint256(1))
        );
    }

    /// @dev Simulates Hub-side fulfillment of a redeem: delivers a RevokedShares callback
    ///      (asset/share accounting) followed by a FulfilledRedeemRequest callback (per-user
    ///      weighted-average redeemPrice update). Pool escrow is funded with the assets so the
    ///      eventual `vault.redeem` can transfer them out.
    function _fulfillRedeem(
        address investor,
        uint128 fulfilledAssets,
        uint128 fulfilledShares
    ) internal {
        // Bump both the underlying ERC20 balance and the pool escrow's internal `holding.total`
        // accounting, so that the eventual `escrow.withdraw(...)` in `_processRedeem` succeeds.
        deal(
            address(collateralToken),
            centrifugePoolEscrow,
            collateralToken.balanceOf(centrifugePoolEscrow) + fulfilledAssets
        );
        ICentrifugePoolEscrow(centrifugePoolEscrow)
            .deposit(scId, address(collateralToken), 0, fulfilledAssets);

        bytes memory revokedSharesPayload = abi.encodePacked(
            CALLBACK_REVOKED_SHARES,
            fulfilledAssets,
            fulfilledShares,
            uint128(1e18)        // pricePoolPerShare; doesn't affect the per-user redeemPrice math.
        );
        ICentrifugeAsyncRequestManager(ASYNC_REQUEST_MANAGER)
            .callback(poolId, scId, assetId, revokedSharesPayload);

        bytes memory fulfilledPayload = abi.encodePacked(
            CALLBACK_FULFILLED_REDEEM_REQUEST,
            bytes32(bytes20(investor)),
            fulfilledAssets,
            fulfilledShares,
            uint128(0)           // cancelledShareAmount
        );
        ICentrifugeAsyncRequestManager(ASYNC_REQUEST_MANAGER)
            .callback(poolId, scId, assetId, fulfilledPayload);
    }

    function _sequentialRedeem(uint128 x1, uint128 x2) internal {
        vm.assume(x1 >= 1 && x2 >= 1);

        ICentrifugeAsyncVault v = ICentrifugeAsyncVault(CENTRIFUGE_JTRSY_VAULT);

        // --- First redemption: x1 ---

        uint128 fulfilledAssets1 = uint128(
            uint256(x1) * livePricePoolPerShare / livePricePoolPerAsset
        );

        _dealJTRSY(address(groveBasin), x1);

        vm.prank(issuer);
        bytes32 requestId1 = groveBasin.initiateRedeem(address(tokenRedeemer), x1);

        _fulfillRedeem(address(tokenRedeemer), fulfilledAssets1, x1);

        assertEq(v.maxWithdraw(address(tokenRedeemer)), fulfilledAssets1);
        assertEq(v.maxRedeem(address(tokenRedeemer)),   x1);

        vm.prank(issuer);
        groveBasin.completeRedeem(requestId1);

        assertEq(v.maxRedeem(address(tokenRedeemer)), 0);
        assertEq(v.maxWithdraw(address(tokenRedeemer)), 0);

        // --- Second redemption: x2 ---

        uint128 fulfilledAssets2 = uint128(
            uint256(x2) * livePricePoolPerShare / livePricePoolPerAsset
        );

        _dealJTRSY(address(groveBasin), x2);

        vm.prank(issuer);
        bytes32 requestId2 = groveBasin.initiateRedeem(address(tokenRedeemer), x2);

        _fulfillRedeem(address(tokenRedeemer), fulfilledAssets2, x2);

        assertEq(v.maxWithdraw(address(tokenRedeemer)), fulfilledAssets2);
        assertEq(v.maxRedeem(address(tokenRedeemer)),   x2);

        vm.prank(issuer);
        groveBasin.completeRedeem(requestId2);

        assertEq(v.maxRedeem(address(tokenRedeemer)), 0);
        assertEq(v.maxWithdraw(address(tokenRedeemer)), 0);
    }

    /// @dev Fuzz: small amounts, sub-$10 (1 to 10e6 JTRSY, i.e. 0.000001 to 10 tokens).
    function testFuzz_dust_sequential_small(uint128 x1, uint128 x2) public {
        x1 = uint128(bound(x1, 1, 10e6));
        x2 = uint128(bound(x2, 1, 10e6));
        _sequentialRedeem(x1, x2);
    }

    /// @dev Fuzz: large amounts, $50M-$100M range (50_000_000e6 to 100_000_000e6 JTRSY).
    function testFuzz_dust_sequential_large(uint128 x1, uint128 x2) public {
        x1 = uint128(bound(x1, 50_000_000e6, 100_000_000e6));
        x2 = uint128(bound(x2, 50_000_000e6, 100_000_000e6));
        _sequentialRedeem(x1, x2);
    }
}
