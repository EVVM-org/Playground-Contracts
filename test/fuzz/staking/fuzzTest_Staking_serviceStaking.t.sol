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

import {Constants, MockContractToStake} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/library/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract fuzzTest_Staking_serviceStaking is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    MockContractToStake mockContract;
    Treasury treasury;

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

        vm.startPrank(ADMIN.Address);

        staking.prepareChangeAllowPublicStaking();
        skip(1 days);
        staking.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        mockContract = new MockContractToStake(address(staking));

        giveMateToExecute(address(mockContract), 10);

        mockContract.stake(10);
    }

    function giveMateToExecute(
        address user,
        uint256 stakingAmount
    ) private returns (uint256 totalOfMate) {
        evvm.addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (staking.priceOfStaking() * stakingAmount)
        );

        totalOfMate = (staking.priceOfStaking() * stakingAmount);
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.getRewardAmount() * 2) * numberOfTx;
    }

    struct FuzzTestInput {
        bool isStaking;
        uint8 amount;
    }

    function test__fuzz__publicServiceStaking(
        FuzzTestInput[20] memory input
    ) external {
        uint256 counterTx = 0;
        uint256 amountStakingBefore;

        for (uint256 i = 0; i < input.length; i++) {
            amountStakingBefore = staking.getUserAmountStaked(
                address(mockContract)
            );

            if (input[i].isStaking) {
                if (
                    evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS) <
                    staking.priceOfStaking() * input[i].amount
                ) {
                    uint256 totalOfStakeNeeded = input[i].amount -
                        (evvm.getBalance(
                            address(mockContract),
                            MATE_TOKEN_ADDRESS
                        ) / staking.priceOfStaking());
                    giveMateToExecute(
                        address(mockContract),
                        totalOfStakeNeeded
                    );
                }

                if (staking.getUserAmountStaked(address(mockContract)) == 0)
                    skip(staking.getSecondsToUnlockStaking());

                mockContract.stake(input[i].amount);
            } else {
                if (
                    input[i].amount >
                    staking.getUserAmountStaked(address(mockContract))
                ) {
                    input[i].amount = uint8(
                        staking.getUserAmountStaked(address(mockContract))
                    );
                }

                if (input[i].amount == 0) continue;

                if (
                    staking.getUserAmountStaked(address(mockContract)) ==
                    input[i].amount
                ) skip(staking.getSecondsToUnlockFullUnstaking());

                mockContract.unstake(input[i].amount);
            }

            counterTx++;

            Staking.HistoryMetadata memory history = staking
                .getAddressHistoryByIndex(address(mockContract), counterTx);

            assertEq(history.timestamp, block.timestamp);
            assertEq(
                history.transactionType,
                input[i].isStaking
                    ? DEPOSIT_HISTORY_SMATE_IDENTIFIER
                    : WITHDRAW_HISTORY_SMATE_IDENTIFIER
            );
            assertEq(history.amount, input[i].amount);
            if (input[i].isStaking)
                assertEq(
                    history.totalStaked,
                    amountStakingBefore + input[i].amount
                );
            else
                assertEq(
                    history.totalStaked,
                    amountStakingBefore - input[i].amount
                );
        }
    }
}
