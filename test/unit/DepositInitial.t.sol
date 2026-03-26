// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }  from "src/GroveBasin.sol";
import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

import { GroveBasinDeploy } from "deploy/GroveBasinDeploy.sol";

import { MockERC20, GroveBasinTestBase } from "test/GroveBasinTestBase.sol";

contract DepositInitialTests is GroveBasinTestBase {

    GroveBasin public freshBasin;

    address depositor = makeAddr("depositor");

    function setUp() public override {
        super.setUp();

        freshBasin = new GroveBasin(
            owner, lp,
            address(swapToken), address(collateralToken), address(creditToken),
            address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider)
        );
    }

    /**********************************************************************************************/
    /*** Revert tests                                                                           ***/
    /**********************************************************************************************/

    function test_depositInitial_alreadySeeded() public {
        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();

        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);
        vm.expectRevert(IGroveBasin.AlreadySeeded.selector);
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();
    }

    function test_depositInitial_zeroAmount() public {
        vm.expectRevert(IGroveBasin.ZeroAmount.selector);
        freshBasin.depositInitial(address(swapToken), 0);
    }

    function test_depositInitial_invalidAsset() public {
        vm.expectRevert(IGroveBasin.InvalidAsset.selector);
        freshBasin.depositInitial(makeAddr("bad-asset"), 100e6);
    }

    function test_depositInitial_insufficientApprove() public {
        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 99e6);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();
    }

    function test_depositInitial_insufficientBalance() public {
        swapToken.mint(depositor, 99e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Success tests                                                                          ***/
    /**********************************************************************************************/

    function test_depositInitial_anyoneCanCall() public {
        address anyone = makeAddr("anyone");

        swapToken.mint(anyone, 100e6);
        vm.startPrank(anyone);
        swapToken.approve(address(freshBasin), 100e6);
        uint256 newShares = freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();

        assertEq(newShares, 100e18);
        assertEq(freshBasin.shares(address(0)), 100e18);
        assertEq(freshBasin.shares(anyone),     0);
        assertEq(freshBasin.shares(lp),         0);
        assertEq(freshBasin.totalShares(),      100e18);
    }

    function test_depositInitial_sharesToZeroAddress() public {
        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();

        assertEq(freshBasin.shares(address(0)), 100e18);
        assertEq(freshBasin.shares(lp),         0);
        assertEq(freshBasin.shares(depositor),  0);
    }

    function test_depositInitial_swapToken() public {
        swapToken.mint(depositor, 100e6);

        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);

        assertEq(freshBasin.totalShares(), 0);
        assertEq(freshBasin.totalAssets(), 0);

        uint256 newShares = freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();

        assertEq(newShares, 100e18);

        assertEq(swapToken.balanceOf(depositor),          0);
        assertEq(swapToken.balanceOf(address(freshBasin)), 100e6);

        assertEq(freshBasin.totalShares(),      100e18);
        assertEq(freshBasin.shares(address(0)), 100e18);
        assertEq(freshBasin.shares(lp),         0);
    }

    function test_depositInitial_collateralToken() public {
        collateralToken.mint(depositor, 100e18);

        vm.startPrank(depositor);
        collateralToken.approve(address(freshBasin), 100e18);
        uint256 newShares = freshBasin.depositInitial(address(collateralToken), 100e18);
        vm.stopPrank();

        assertEq(newShares, 100e18);

        assertEq(collateralToken.balanceOf(depositor),          0);
        assertEq(collateralToken.balanceOf(address(freshBasin)), 100e18);

        assertEq(freshBasin.totalShares(),      100e18);
        assertEq(freshBasin.shares(address(0)), 100e18);
        assertEq(freshBasin.shares(lp),         0);
    }

    function test_depositInitial_creditToken() public {
        creditToken.mint(depositor, 100e18);

        vm.startPrank(depositor);
        creditToken.approve(address(freshBasin), 100e18);
        uint256 newShares = freshBasin.depositInitial(address(creditToken), 100e18);
        vm.stopPrank();

        // Credit token rate is 1.25, so 100e18 credit = 125e18 value = 125e18 shares
        assertEq(newShares, 125e18);

        assertEq(creditToken.balanceOf(depositor),          0);
        assertEq(creditToken.balanceOf(address(freshBasin)), 100e18);

        assertEq(freshBasin.totalShares(),      125e18);
        assertEq(freshBasin.shares(address(0)), 125e18);
        assertEq(freshBasin.shares(lp),         0);
    }

    function test_depositInitial_event() public {
        swapToken.mint(depositor, 100e6);

        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);

        vm.expectEmit(address(freshBasin));
        emit IGroveBasin.Deposit(address(swapToken), depositor, address(0), 100e6, 100e18);
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();
    }

    function test_depositInitial_lpCanStillDepositAfter() public {
        swapToken.mint(depositor, 10e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 10e6);
        freshBasin.depositInitial(address(swapToken), 10e6);
        vm.stopPrank();

        assertEq(freshBasin.totalShares(),      10e18);
        assertEq(freshBasin.shares(address(0)), 10e18);
        assertEq(freshBasin.shares(lp),         0);

        // LP can still use regular deposit
        swapToken.mint(lp, 90e6);
        vm.startPrank(lp);
        swapToken.approve(address(freshBasin), 90e6);
        uint256 newShares = freshBasin.deposit(address(swapToken), lp, 90e6);
        vm.stopPrank();

        assertEq(newShares, 90e18);
        assertEq(freshBasin.totalShares(),      100e18);
        assertEq(freshBasin.shares(address(0)), 10e18);
        assertEq(freshBasin.shares(lp),         90e18);
    }

    /**********************************************************************************************/
    /*** Fuzz tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_depositInitial_swapToken(uint256 amount) public {
        amount = _bound(amount, 1, SWAP_TOKEN_MAX);

        swapToken.mint(depositor, amount);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), amount);
        uint256 newShares = freshBasin.depositInitial(address(swapToken), amount);
        vm.stopPrank();

        assertEq(newShares, amount * 1e12);
        assertEq(freshBasin.totalShares(),      amount * 1e12);
        assertEq(freshBasin.shares(address(0)), amount * 1e12);
    }

    function testFuzz_depositInitial_collateralToken(uint256 amount) public {
        amount = _bound(amount, 1, COLLATERAL_TOKEN_MAX);

        collateralToken.mint(depositor, amount);
        vm.startPrank(depositor);
        collateralToken.approve(address(freshBasin), amount);
        uint256 newShares = freshBasin.depositInitial(address(collateralToken), amount);
        vm.stopPrank();

        assertEq(newShares, amount);
        assertEq(freshBasin.totalShares(),      amount);
        assertEq(freshBasin.shares(address(0)), amount);
    }

    function testFuzz_depositInitial_creditToken(uint256 amount) public {
        amount = _bound(amount, 1, CREDIT_TOKEN_MAX);

        creditToken.mint(depositor, amount);
        vm.startPrank(depositor);
        creditToken.approve(address(freshBasin), amount);
        uint256 newShares = freshBasin.depositInitial(address(creditToken), amount);
        vm.stopPrank();

        assertEq(newShares, amount * 125 / 100);
        assertEq(freshBasin.totalShares(),      amount * 125 / 100);
        assertEq(freshBasin.shares(address(0)), amount * 125 / 100);
    }

    /**********************************************************************************************/
    /*** Deploy library integration tests                                                       ***/
    /**********************************************************************************************/

    function test_depositInitial_viaDeploy() public {
        swapToken.mint(address(this), 1e6);

        address newBasin = GroveBasinDeploy.deploy(
            owner,
            lp,
            address(swapToken),
            address(collateralToken),
            address(creditToken),
            address(swapTokenRateProvider),
            address(collateralTokenRateProvider),
            address(creditTokenRateProvider)
        );

        assertEq(GroveBasin(newBasin).totalShares(),      1e18);
        assertEq(GroveBasin(newBasin).shares(address(0)), 1e18);
        assertEq(GroveBasin(newBasin).shares(lp),         0);
        assertEq(swapToken.balanceOf(newBasin),            1e6);
    }

}
