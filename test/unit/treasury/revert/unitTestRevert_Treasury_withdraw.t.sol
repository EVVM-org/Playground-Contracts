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
import {Erc191TestBuilder} from "@EVVM/playground/library/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

import {ErrorsLib} from "@EVVM/playground/contracts/treasury/lib/ErrorsLib.sol";

contract unitTestRevert_Treasury_withdraw is Test, Constants {
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

    function depositHostNative(
        AccountData memory user,
        uint256 amount
    ) internal {
        vm.deal(user.Address, amount);

        vm.startPrank(user.Address);

        treasury.deposit{value: amount}(address(0), amount);

        vm.stopPrank();
    }

    function depositToken(AccountData memory user, uint256 amount) internal {
        testToken.mint(user.Address, amount);

        vm.startPrank(user.Address);

        testToken.approve(address(treasury), amount);

        treasury.deposit(address(testToken), amount);

        vm.stopPrank();
    }

    function test__unit_revert__withdraw__hostNative__InsufficientBalance()
        external
    {
        depositHostNative(COMMON_USER_NO_STAKER_1, 0.005 ether);
        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        treasury.withdraw(address(0), 0.01 ether);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, address(0)),
            0.005 ether
        );

        assertEq(COMMON_USER_NO_STAKER_1.Address.balance, 0 ether);

        assertEq(address(treasury).balance, 0.005 ether);
    }

    function test__unit_revert__withdraw__PrincipalTokenIsNotWithdrawable()
        external
    {
        address principalToken = evvm.getEvvmMetadata().principalTokenAddress;

        evvm.addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            principalToken,
            10 ether
        );

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert(ErrorsLib.PrincipalTokenIsNotWithdrawable.selector);
        treasury.withdraw(principalToken, 10 ether);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                evvm.getEvvmMetadata().principalTokenAddress
            ),
            10 ether
        );
    }

    function test__unit_revert__withdraw__token__InsufficientBalance()
        external
    {
        depositToken(COMMON_USER_NO_STAKER_1, 5 ether);
        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        treasury.withdraw(address(testToken), 10 ether);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                address(testToken)
            ),
            5 ether
        );

        assertEq(testToken.balanceOf(COMMON_USER_NO_STAKER_1.Address), 0);
        assertEq(testToken.balanceOf(address(treasury)), 5 ether);
    }
}
