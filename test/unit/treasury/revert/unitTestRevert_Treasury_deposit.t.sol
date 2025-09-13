// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for 
 * @notice some functions has evvm functions that are implemented
 *         and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants, TestERC20} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

import {ErrorsLib} from "@EVVM/playground/contracts/treasury/lib/ErrorsLib.sol";

contract unitTestRevert_Treasury_deposit is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;
    TestERC20 testToken;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: 777,
                principalTokenName: "EVVM Staking Token",
                principalTokenSymbol: "EVVM-STK",
                principalTokenAddress: 0x0000000000000000000000000000000000000001,
                totalSupply: 2033333333000000000000000000,
                eraTokens: 2033333333000000000000000000 / 2,
                reward: 5000000000000000000
            })
        );
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(staking),
            ADMIN.Address
        );
        nameService = new NameService(address(evvm), ADMIN.Address);

        staking._setupEstimatorAndEvvm(address(estimator), address(evvm));
        treasury = new Treasury(address(evvm));
        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasury)
        );

        evvm.setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        testToken = new TestERC20();
    }

    function test__unit_revert__deposit__hostNative__DepositAmountMustBeGreaterThanZero()
        external
    {
        vm.deal(COMMON_USER_NO_STAKER_1.Address, 0.01 ether);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert(ErrorsLib.DepositAmountMustBeGreaterThanZero.selector);

        treasury.deposit{value: 0 ether}(address(0), 0 ether);

        vm.stopPrank();
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, address(0)),
            0
        );
        assertEq(COMMON_USER_NO_STAKER_1.Address.balance, 0.01 ether);
        assertEq(address(treasury).balance, 0 ether);
    }

    function test__unit_revert__deposit__hostNative__InvalidDepositAmount()
        external
    {
        vm.deal(COMMON_USER_NO_STAKER_1.Address, 0.01 ether);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert(ErrorsLib.InvalidDepositAmount.selector);
        treasury.deposit{value: 0.01 ether}(address(0), 0.001 ether);

        vm.stopPrank();
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, address(0)),
            0
        );
        assertEq(COMMON_USER_NO_STAKER_1.Address.balance, 0.01 ether);
        assertEq(address(treasury).balance, 0 ether);
    }

    function test__unit_revert__deposit__token__InvalidDepositAmount()
        external
    {
        testToken.mint(COMMON_USER_NO_STAKER_1.Address, 10 ether);
        vm.deal(COMMON_USER_NO_STAKER_1.Address, 0.01 ether);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        testToken.approve(address(treasury), 10 ether);

        vm.expectRevert(ErrorsLib.InvalidDepositAmount.selector);
        treasury.deposit{value: 0.01 ether}(address(testToken), 10 ether);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                address(testToken)
            ),
            0
        );
        assertEq(
            testToken.balanceOf(COMMON_USER_NO_STAKER_1.Address),
            10 ether
        );
        assertEq(testToken.balanceOf(address(treasury)), 0 ether);
    }

    function test__unit_revert__deposit__token_DepositAmountMustBeGreaterThanZero()
        external
    {
        testToken.mint(COMMON_USER_NO_STAKER_1.Address, 10 ether);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        testToken.approve(address(treasury), 10 ether);

        vm.expectRevert(ErrorsLib.DepositAmountMustBeGreaterThanZero.selector);
        treasury.deposit(address(testToken), 0);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                address(testToken)
            ),
            0
        );
        assertEq(
            testToken.balanceOf(COMMON_USER_NO_STAKER_1.Address),
            10 ether
        );
        assertEq(testToken.balanceOf(address(treasury)), 0 ether);
    }

    function test__unit_revert__deposit__token__NoAllowance() external {
        testToken.mint(COMMON_USER_NO_STAKER_1.Address, 10 ether);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        treasury.deposit(address(testToken), 10 ether);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                address(testToken)
            ),
            0
        );
        assertEq(
            testToken.balanceOf(COMMON_USER_NO_STAKER_1.Address),
            10 ether
        );
        assertEq(testToken.balanceOf(address(treasury)), 0 ether);
    }
}
