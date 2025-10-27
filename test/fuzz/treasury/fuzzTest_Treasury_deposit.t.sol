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

contract fuzzTest_Treasury_deposit is Test, Constants {
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

    struct depositFuzzTestInput {
        bool isHostNative;
        uint24 depositAmount;
        address user;
    }

    function test__fuzz__deposit(depositFuzzTestInput memory input) external {
        vm.assume(input.user != address(0) && input.user != address(treasury));
        vm.assume(input.depositAmount > 0);

        if (input.isHostNative) {
            vm.deal(input.user, input.depositAmount);
        } else {
            testToken.mint(input.user, input.depositAmount);
        }

        vm.startPrank(input.user);
        if (input.isHostNative) {
            treasury.deposit{value: input.depositAmount}(
                address(0),
                input.depositAmount
            );
        } else {
            testToken.approve(address(treasury), input.depositAmount);

            treasury.deposit(address(testToken), input.depositAmount);
        }

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                input.user,
                (address(input.isHostNative ? address(0) : address(testToken)))
            ),
            input.depositAmount
        );
        if (input.isHostNative) {
            assertEq(address(treasury).balance, input.depositAmount);
            assertEq(address(input.user).balance, 0);
        } else {
            assertEq(
                testToken.balanceOf(address(treasury)),
                input.depositAmount
            );
            assertEq(testToken.balanceOf(input.user), 0);
        }
    }
}
