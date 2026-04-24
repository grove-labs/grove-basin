// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { GroveBasin }        from "src/GroveBasin.sol";
import { GroveBasinFactory } from "src/GroveBasinFactory.sol";
import { IGroveBasin }       from "src/interfaces/IGroveBasin.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

import { GroveBasinTestBase } from "test/GroveBasinTestBase.sol";
import { MockPocket }         from "test/mocks/MockPocket.sol";

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

    function test_depositInitial_globalPaused() public {
        vm.startPrank(owner);
        freshBasin.grantRole(freshBasin.MANAGER_ADMIN_ROLE(), owner);
        freshBasin.grantRole(freshBasin.PAUSER_ROLE(), owner);
        freshBasin.setPaused(bytes4(0));
        vm.stopPrank();

        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(freshBasin), 100e6);
        vm.expectRevert(IGroveBasin.Paused.selector);
        freshBasin.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();
    }

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
        vm.expectRevert(IGroveBasin.InsufficientInitialDeposit.selector);
        freshBasin.depositInitial(address(swapToken), 0);
    }

    function test_depositInitial_invalidAsset() public {
        vm.expectRevert();
        freshBasin.depositInitial(makeAddr("bad-asset"), 100e6);
    }

    function test_depositInitial_insufficientInitialDeposit_swapToken() public {
        vm.expectRevert(IGroveBasin.InsufficientInitialDeposit.selector);
        freshBasin.depositInitial(address(swapToken), 1e6 - 1);
    }

    function test_depositInitial_insufficientInitialDeposit_collateralToken() public {
        vm.expectRevert(IGroveBasin.InsufficientInitialDeposit.selector);
        freshBasin.depositInitial(address(collateralToken), 1e18 - 1);
    }

    function test_depositInitial_insufficientInitialDeposit_creditToken() public {
        vm.expectRevert(IGroveBasin.InsufficientInitialDeposit.selector);
        freshBasin.depositInitial(address(creditToken), 1e18 - 1);
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

    function test_depositInitial_noNewShares() public {
        mockSwapTokenRateProvider.__setConversionRate(1);

        GroveBasin zeroShareBasin = new GroveBasin(
            owner, lp,
            address(swapToken), address(collateralToken), address(creditToken),
            address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider)
        );

        swapToken.mint(depositor, 1e6);
        vm.startPrank(depositor);
        swapToken.approve(address(zeroShareBasin), 1e6);
        vm.expectRevert(IGroveBasin.NoNewShares.selector);
        zeroShareBasin.depositInitial(address(swapToken), 1e6);
        vm.stopPrank();

        mockSwapTokenRateProvider.__setConversionRate(1e27);
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
        amount = _bound(amount, 1e6, SWAP_TOKEN_MAX);

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
        amount = _bound(amount, 1e18, COLLATERAL_TOKEN_MAX);

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
        amount = _bound(amount, 1e18, CREDIT_TOKEN_MAX);

        creditToken.mint(depositor, amount);
        vm.startPrank(depositor);
        creditToken.approve(address(freshBasin), amount);
        uint256 newShares = freshBasin.depositInitial(address(creditToken), amount);
        vm.stopPrank();

        assertEq(newShares, amount * 125 / 100);
        assertEq(freshBasin.totalShares(),      amount * 125 / 100);
        assertEq(freshBasin.shares(address(0)), amount * 125 / 100);
    }

    function test_depositInitial_swapToken_pocketDepositFails_tokensRemainInPocket() public {
        GroveBasin basinWithPocket = new GroveBasin(
            owner, lp,
            address(swapToken), address(collateralToken), address(creditToken),
            address(swapTokenRateProvider), address(collateralTokenRateProvider), address(creditTokenRateProvider)
        );

        MockPocket failPocket = new MockPocket(
            address(basinWithPocket),
            address(swapToken),
            address(usds),
            address(psm)
        );

        vm.startPrank(owner);
        basinWithPocket.grantRole(basinWithPocket.MANAGER_ADMIN_ROLE(), owner);
        basinWithPocket.grantRole(basinWithPocket.MANAGER_ROLE(), owner);
        basinWithPocket.setPocket(address(failPocket));
        vm.stopPrank();

        vm.mockCallRevert(
            address(failPocket),
            abi.encodeWithSelector(IGroveBasinPocket.depositLiquidity.selector),
            "pocket deposit failed"
        );

        swapToken.mint(depositor, 100e6);
        vm.startPrank(depositor);
        swapToken.approve(address(basinWithPocket), 100e6);

        vm.expectEmit(true, true, true, true);
        emit IGroveBasin.DepositLiquidityFailed(address(failPocket), address(swapToken), 100e6);

        uint256 newShares = basinWithPocket.depositInitial(address(swapToken), 100e6);
        vm.stopPrank();

        assertEq(newShares, 100e18);
        assertEq(swapToken.balanceOf(address(failPocket)), 100e6);
        assertEq(basinWithPocket.totalShares(), 100e18);
        assertEq(basinWithPocket.shares(address(0)), 100e18);
    }

    /**********************************************************************************************/
    /*** Factory integration tests                                                              ***/
    /**********************************************************************************************/

    function test_depositInitial_viaFactory() public {
        GroveBasinFactory factory = new GroveBasinFactory();

        swapToken.mint(address(this), 1e6);
        swapToken.approve(address(factory), 1e6);

        address newBasin = factory.deploy(
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
