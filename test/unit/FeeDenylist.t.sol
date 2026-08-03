// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

/**********************************************************************************************/
/*** FEE_DENYLISTER_ROLE management tests                                                    ***/
/**********************************************************************************************/

contract GroveBasinFeeDenylisterRoleTests is GroveBasinTestBase {

    address managerAdmin  = makeAddr("managerAdmin");
    address pauser        = makeAddr("pauser");
    address feeDenylister = makeAddr("feeDenylister");

    bytes32 feeDenylisterRole;
    bytes32 managerAdminRole;

    function setUp() public override {
        super.setUp();

        feeDenylisterRole = groveBasin.FEE_DENYLISTER_ROLE();
        managerAdminRole  = groveBasin.MANAGER_ADMIN_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(managerAdminRole, managerAdmin);
    }

    function test_feeDenylisterRole_admin() public view {
        assertEq(groveBasin.getRoleAdmin(feeDenylisterRole), managerAdminRole);
    }

    function test_managerAdmin_grantFeeDenylisterRole() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(feeDenylisterRole, feeDenylister);

        assertTrue(groveBasin.hasRole(feeDenylisterRole, feeDenylister));
    }

    function test_managerAdmin_revokeFeeDenylisterRole() public {
        vm.startPrank(managerAdmin);
        groveBasin.grantRole(feeDenylisterRole, feeDenylister);
        groveBasin.revokeRole(feeDenylisterRole, feeDenylister);
        vm.stopPrank();

        assertFalse(groveBasin.hasRole(feeDenylisterRole, feeDenylister));
    }

    function test_unauthorized_grantFeeDenylisterRole() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.grantRole(feeDenylisterRole, feeDenylister);
    }

    function test_unauthorized_revokeFeeDenylisterRole() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(feeDenylisterRole, feeDenylister);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                managerAdminRole
            )
        );
        groveBasin.revokeRole(feeDenylisterRole, feeDenylister);
    }

    function test_pauser_cannotRevokeFeeDenylisterRole() public {
        vm.startPrank(managerAdmin);
        groveBasin.grantRole(groveBasin.PAUSER_ROLE(), pauser);
        groveBasin.grantRole(feeDenylisterRole,        feeDenylister);
        vm.stopPrank();

        vm.prank(pauser);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                pauser,
                managerAdminRole
            )
        );
        groveBasin.revokeRole(feeDenylisterRole, feeDenylister);

        assertTrue(groveBasin.hasRole(feeDenylisterRole, feeDenylister));
    }

    function test_feeDenylister_cannotGrantFeeDenylisterRole() public {
        vm.prank(managerAdmin);
        groveBasin.grantRole(feeDenylisterRole, feeDenylister);

        vm.prank(feeDenylister);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                feeDenylister,
                managerAdminRole
            )
        );
        groveBasin.grantRole(feeDenylisterRole, makeAddr("otherDenylister"));
    }

}

/**********************************************************************************************/
/*** Fee denylist management tests                                                          ***/
/**********************************************************************************************/

contract GroveBasinFeeDenylistManagementTests is GroveBasinTestBase {

    event FeeDenylistSet(address indexed account, bool denylisted);

    address feeDenylister = makeAddr("feeDenylister");
    address user          = makeAddr("user");

    bytes32 feeDenylisterRole;

    function setUp() public override {
        super.setUp();

        feeDenylisterRole = groveBasin.FEE_DENYLISTER_ROLE();

        vm.prank(owner);
        groveBasin.grantRole(feeDenylisterRole, feeDenylister);
    }

    function test_addToFeeDenylist_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                feeDenylisterRole
            )
        );
        groveBasin.addToFeeDenylist(user);
    }

    function test_removeFromFeeDenylist_unauthorized() public {
        vm.prank(feeDenylister);
        groveBasin.addToFeeDenylist(user);

        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                feeDenylisterRole
            )
        );
        groveBasin.removeFromFeeDenylist(user);
    }

    function test_addToFeeDenylist_managerAdminCannotAdd() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                owner,
                feeDenylisterRole
            )
        );
        groveBasin.addToFeeDenylist(user);
    }

    function test_addToFeeDenylist() public {
        assertFalse(groveBasin.feeDenylist(user));

        vm.prank(feeDenylister);
        vm.expectEmit(address(groveBasin));
        emit FeeDenylistSet(user, true);
        groveBasin.addToFeeDenylist(user);

        assertTrue(groveBasin.feeDenylist(user));
    }

    function test_removeFromFeeDenylist() public {
        vm.prank(feeDenylister);
        groveBasin.addToFeeDenylist(user);

        vm.prank(feeDenylister);
        vm.expectEmit(address(groveBasin));
        emit FeeDenylistSet(user, false);
        groveBasin.removeFromFeeDenylist(user);

        assertFalse(groveBasin.feeDenylist(user));
    }

    function test_addToFeeDenylist_alreadyDenylisted() public {
        vm.startPrank(feeDenylister);
        groveBasin.addToFeeDenylist(user);
        groveBasin.addToFeeDenylist(user);
        vm.stopPrank();

        assertTrue(groveBasin.feeDenylist(user));
    }

    function test_removeFromFeeDenylist_notDenylisted() public {
        vm.prank(feeDenylister);
        groveBasin.removeFromFeeDenylist(user);

        assertFalse(groveBasin.feeDenylist(user));
    }

    function test_feeDenylist_appliesPerAddress() public {
        vm.prank(feeDenylister);
        groveBasin.addToFeeDenylist(user);

        assertTrue(groveBasin.feeDenylist(user));
        assertFalse(groveBasin.feeDenylist(makeAddr("otherUser")));
    }

    function test_revokedFeeDenylister_cannotUpdateDenylist() public {
        vm.prank(owner);
        groveBasin.revokeRole(feeDenylisterRole, feeDenylister);

        vm.prank(feeDenylister);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                feeDenylister,
                feeDenylisterRole
            )
        );
        groveBasin.addToFeeDenylist(user);
    }

}

/**********************************************************************************************/
/*** Fee denylist swap and preview tests                                                    ***/
/**********************************************************************************************/

contract GroveBasinFeeDenylistSwapTests is GroveBasinTestBase {

    address feeClaimer    = makeAddr("feeClaimer");
    address feeDenylister = makeAddr("feeDenylister");
    address swapper       = makeAddr("swapper");
    address receiver      = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        groveBasin.setFeeBounds(0, 500);
        groveBasin.setPurchaseFee(100);    // 1%
        groveBasin.setRedemptionFee(200);  // 2%
        groveBasin.setFeeClaimer(feeClaimer);
        groveBasin.grantRole(groveBasin.FEE_DENYLISTER_ROLE(), feeDenylister);
        vm.stopPrank();

        _deposit(address(swapToken),       makeAddr("seeder"), 1_000_000e6);
        _deposit(address(collateralToken), makeAddr("seeder"), 1_000_000e18);
        _deposit(address(creditToken),     makeAddr("seeder"), 1_000_000e18);
    }

    /**********************************************************************************************/
    /*** Preview tests                                                                          ***/
    /**********************************************************************************************/

    function test_previewSwapExactIn_denylistedCaller_purchaseFee() public {
        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6), 79.2e18);

        _addToFeeDenylist(swapper);

        // Without the 1% purchase fee: 100 USDC -> 80 credit (rate 1.25)
        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6), 80e18);
    }

    function test_previewSwapExactIn_denylistedCaller_redemptionFee() public {
        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 100e18), 122_500_000);

        _addToFeeDenylist(swapper);

        // Without the 2% redemption fee: 100 credit -> 125 USDC
        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(creditToken), address(swapToken), 100e18), 125e6);
    }

    function test_previewSwapExactOut_denylistedCaller_purchaseFee() public {
        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18), 101_010_102);

        _addToFeeDenylist(swapper);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18), 100e6);
    }

    function test_previewSwapExactOut_denylistedCaller_redemptionFee() public {
        _addToFeeDenylist(swapper);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOut(address(creditToken), address(swapToken), 125e6), 100e18);
    }

    function test_previewSwapFees_denylistedCaller() public {
        _addToFeeDenylist(swapper);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactInFee(address(creditToken), 10_000e18), 0);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOutFee(address(creditToken), 10_000e18), 0);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactInFee(address(swapToken), 10_000e6), 0);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOutFee(address(swapToken), 10_000e6), 0);
    }

    function test_previewSwap_denylistedOtherAccount_chargesFee() public {
        _addToFeeDenylist(makeAddr("otherAccount"));

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6), 79.2e18);

        vm.prank(swapper);
        assertEq(groveBasin.previewSwapExactOut(address(swapToken), address(creditToken), 80e18), 101_010_102);
    }

    function test_previewSwap_feeDenylisterNotExempt() public {
        vm.prank(feeDenylister);
        assertEq(groveBasin.previewSwapExactIn(address(swapToken), address(creditToken), 100e6), 79.2e18);
    }

    /**********************************************************************************************/
    /*** Swap tests                                                                             ***/
    /**********************************************************************************************/

    function test_swapExactIn_denylistedCaller_purchaseFee() public {
        _addToFeeDenylist(swapper);

        uint256 amountOut = _swapExactIn(address(swapToken), address(creditToken), 100e6, swapper);

        assertEq(amountOut,                            80e18);
        assertEq(creditToken.balanceOf(swapper),        80e18);
        assertEq(groveBasin.shares(feeClaimer),         0);
    }

    function test_swapExactIn_denylistedCaller_redemptionFee() public {
        _addToFeeDenylist(swapper);

        uint256 amountOut = _swapExactIn(address(creditToken), address(swapToken), 100e18, swapper);

        assertEq(amountOut,                     125e6);
        assertEq(swapToken.balanceOf(swapper),  125e6);
        assertEq(groveBasin.shares(feeClaimer), 0);
    }

    function test_swapExactOut_denylistedCaller_purchaseFee() public {
        _addToFeeDenylist(swapper);

        uint256 amountIn = _swapExactOut(address(swapToken), address(creditToken), 80e18, swapper);

        assertEq(amountIn,                      100e6);
        assertEq(creditToken.balanceOf(swapper), 80e18);
        assertEq(groveBasin.shares(feeClaimer),  0);
    }

    function test_swapExactOut_denylistedCaller_redemptionFee() public {
        _addToFeeDenylist(swapper);

        uint256 amountIn = _swapExactOut(address(creditToken), address(swapToken), 125e6, swapper);

        assertEq(amountIn,                      100e18);
        assertEq(swapToken.balanceOf(swapper),  125e6);
        assertEq(groveBasin.shares(feeClaimer), 0);
    }

    function test_swapExactIn_denylistedCaller_receiverNotDenylisted() public {
        _addToFeeDenylist(swapper);

        uint256 amountOut = _swapExactIn(address(swapToken), address(creditToken), 100e6, receiver);

        assertEq(amountOut,                      80e18);
        assertEq(creditToken.balanceOf(receiver), 80e18);
        assertEq(groveBasin.shares(feeClaimer),   0);
    }

    function test_swapExactIn_denylistedReceiver_chargesFee() public {
        _addToFeeDenylist(receiver);

        uint256 amountOut = _swapExactIn(address(swapToken), address(creditToken), 100e6, receiver);

        assertEq(amountOut,                      79.2e18);
        assertEq(creditToken.balanceOf(receiver), 79.2e18);
        assertGt(groveBasin.shares(feeClaimer),   0);
    }

    function test_swapExactOut_denylistedReceiver_chargesFee() public {
        _addToFeeDenylist(receiver);

        uint256 amountIn = _swapExactOut(address(swapToken), address(creditToken), 80e18, receiver);

        assertEq(amountIn,                       101_010_102);
        assertEq(creditToken.balanceOf(receiver), 80e18);
        assertGt(groveBasin.shares(feeClaimer),   0);
    }

    function test_swapExactIn_removedFromDenylist_chargesFee() public {
        _addToFeeDenylist(swapper);

        vm.prank(feeDenylister);
        groveBasin.removeFromFeeDenylist(swapper);

        uint256 amountOut = _swapExactIn(address(swapToken), address(creditToken), 100e6, swapper);

        assertEq(amountOut,                     79.2e18);
        assertEq(creditToken.balanceOf(swapper), 79.2e18);
        assertGt(groveBasin.shares(feeClaimer),  0);
    }

    function testFuzz_swapExactIn_denylistedCaller_noFee(uint256 amountIn, uint256 purchaseFee) public {
        amountIn    = _bound(amountIn,    1, 100_000e6);
        purchaseFee = _bound(purchaseFee, 0, 500);

        vm.prank(owner);
        groveBasin.setPurchaseFee(purchaseFee);

        _addToFeeDenylist(swapper);

        uint256 amountOut = _swapExactIn(address(swapToken), address(creditToken), amountIn, swapper);

        // 1e6 precision swap token at $1 into 1e18 precision credit token at a rate of 1.25
        assertEq(amountOut,                     amountIn * 1e12 * 100 / 125);
        assertEq(groveBasin.shares(feeClaimer), 0);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _addToFeeDenylist(address account) internal {
        vm.prank(feeDenylister);
        groveBasin.addToFeeDenylist(account);
    }

    function _swapExactIn(address assetIn, address assetOut, uint256 amountIn, address receiver_)
        internal returns (uint256 amountOut)
    {
        MockERC20(assetIn).mint(swapper, amountIn);

        vm.startPrank(swapper);
        MockERC20(assetIn).approve(address(groveBasin), amountIn);
        amountOut = groveBasin.swapExactIn(assetIn, assetOut, amountIn, 0, receiver_, 0);
        vm.stopPrank();
    }

    function _swapExactOut(address assetIn, address assetOut, uint256 amountOut, address receiver_)
        internal returns (uint256 amountIn)
    {
        vm.prank(swapper);
        uint256 maxAmountIn = groveBasin.previewSwapExactOut(assetIn, assetOut, amountOut);

        MockERC20(assetIn).mint(swapper, maxAmountIn);

        vm.startPrank(swapper);
        MockERC20(assetIn).approve(address(groveBasin), maxAmountIn);
        amountIn = groveBasin.swapExactOut(assetIn, assetOut, amountOut, maxAmountIn, receiver_, 0);
        vm.stopPrank();
    }

}
