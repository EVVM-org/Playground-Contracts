// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense

/**

:::::::::: :::    ::: ::::::::: :::::::::      ::::::::::: :::::::::: :::::::: ::::::::::: 
:+:        :+:    :+:      :+:       :+:           :+:     :+:       :+:    :+:    :+:     
+:+        +:+    +:+     +:+       +:+            +:+     +:+       +:+           +:+     
:#::+::#   +#+    +:+    +#+       +#+             +#+     +#++:++#  +#++:++#++    +#+     
+#+        +#+    +#+   +#+       +#+              +#+     +#+              +#+    +#+     
#+#        #+#    #+#  #+#       #+#               #+#     #+#       #+#    #+#    #+#     
###         ########  ######### #########          ###     ########## ########     ###     


 * @title fuzz test for staking function correct behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract fuzzTest_Staking_publicStaking is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
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
        evvm._setupNameServiceAndTreasuryAddress(address(nameService), address(treasury));

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        staking.prepareChangeAllowPublicStaking();
        skip(1 days);
        staking.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        giveMateToExecute(COMMON_USER_NO_STAKER_1.Address, 10, 0);

        (
            bytes memory signatureEVVM,
            bytes memory signatureStaking
        ) = makeSignature(
                true,
                10,
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                0
            );

        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            0,
            signatureStaking,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
    }

    function giveMateToExecute(
        address user,
        uint256 stakingAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (staking.priceOfStaking() * stakingAmount) + priorityFee
        );

        totalOfMate = (staking.priceOfStaking() * stakingAmount);
        totalOfPriorityFee = priorityFee;
    }

    function makeSignature(
        bool isStaking,
        uint256 amountOfSmate,
        uint256 priorityFee,
        uint256 nonceEVVM,
        bool priorityEVVM,
        uint256 nonceSmate
    )
        private
        view
        returns (bytes memory signatureEVVM, bytes memory signatureStaking)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(staking),
                    "",
                    MATE_TOKEN_ADDRESS,
                    staking.priceOfStaking() * amountOfSmate,
                    priorityFee,
                    nonceEVVM,
                    priorityEVVM,
                    address(staking)
                )
            );
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(staking),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFee,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(staking)
                )
            );
        }

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                isStaking,
                amountOfSmate,
                nonceSmate
            )
        );
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function calculateRewardPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.getRewardAmount() * 2) * numberOfTx;
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * nPF: No priority fee
     * PF: Includes priority fee
     */

    struct PublicStakingFuzzTestInput {
        bool isStaking;
        bool usingStaker;
        uint8 stakingAmount;
        uint144 nonceStaking;
        uint144 nonceEVVM;
        bool priorityEVVM;
        bool givePriorityFee;
        uint16 priorityFeeAmountEVVM;
    }

    function test__fuzz__publicStaking(
        PublicStakingFuzzTestInput[20] memory input
    ) external {
        bytes memory signatureEVVM;
        bytes memory signatureStaking;
        Staking.HistoryMetadata memory history;
        uint256 amountBeforeFisher;
        uint256 amountBeforeUser;
        uint256 totalStakedBefore;
        AccountData memory FISHER;
        uint256 incorrectTxCount = 0;
        uint256 stakingFullAmountBefore;

        for (uint256 i = 0; i < input.length; i++) {
            if (
                staking.checkIfStakeNonceUsed(
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].nonceStaking
                )
            ) {
                incorrectTxCount++;
                continue;
            }

            if (
                evvm.getIfUsedAsyncNonce(
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].nonceEVVM
                )
            ) {
                incorrectTxCount++;
                continue;
            }

            FISHER = input[i].usingStaker
                ? COMMON_USER_STAKER
                : COMMON_USER_NO_STAKER_2;

            amountBeforeFisher = evvm.getBalance(
                FISHER.Address,
                MATE_TOKEN_ADDRESS
            );

            amountBeforeUser = evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            );

            totalStakedBefore = staking.getUserAmountStaked(
                COMMON_USER_NO_STAKER_1.Address
            );

            if (input[i].isStaking) {
                // staking
                if (
                    staking.getUserAmountStaked(
                        COMMON_USER_NO_STAKER_1.Address
                    ) == 0
                ) {
                    vm.warp(
                        staking.getTimeToUserUnlockStakingTime(
                            COMMON_USER_NO_STAKER_1.Address
                        )
                    );
                }

                (, uint256 totalOfPriorityFee) = giveMateToExecute(
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].stakingAmount,
                    (
                        input[i].givePriorityFee
                            ? input[i].priorityFeeAmountEVVM
                            : 0
                    )
                );

                (signatureEVVM, signatureStaking) = makeSignature(
                    input[i].isStaking,
                    input[i].stakingAmount,
                    totalOfPriorityFee,
                    (
                        input[i].priorityEVVM
                            ? input[i].nonceEVVM
                            : evvm.getNextCurrentSyncNonce(
                                COMMON_USER_NO_STAKER_1.Address
                            )
                    ),
                    input[i].priorityEVVM,
                    input[i].nonceStaking
                );

                vm.startPrank(FISHER.Address);

                staking.publicStaking(
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].isStaking,
                    input[i].stakingAmount,
                    input[i].nonceStaking,
                    signatureStaking,
                    totalOfPriorityFee,
                    (
                        input[i].priorityEVVM
                            ? input[i].nonceEVVM
                            : evvm.getNextCurrentSyncNonce(
                                COMMON_USER_NO_STAKER_1.Address
                            )
                    ),
                    input[i].priorityEVVM,
                    signatureEVVM
                );

                vm.stopPrank();
            } else {
                // unstaking
                if (
                    input[i].stakingAmount >=
                    staking.getUserAmountStaked(COMMON_USER_NO_STAKER_1.Address)
                ) {
                    vm.warp(
                        staking.getTimeToUserUnlockFullUnstakingTime(
                            COMMON_USER_NO_STAKER_1.Address
                        )
                    );

                    stakingFullAmountBefore = staking.getUserAmountStaked(
                        COMMON_USER_NO_STAKER_1.Address
                    );

                    (, uint256 totalOfPriorityFee) = giveMateToExecute(
                        COMMON_USER_NO_STAKER_1.Address,
                        0,
                        (
                            input[i].givePriorityFee
                                ? input[i].priorityFeeAmountEVVM
                                : 0
                        )
                    );

                    (signatureEVVM, signatureStaking) = makeSignature(
                        input[i].isStaking,
                        stakingFullAmountBefore,
                        totalOfPriorityFee,
                        (
                            input[i].priorityEVVM
                                ? input[i].nonceEVVM
                                : evvm.getNextCurrentSyncNonce(
                                    COMMON_USER_NO_STAKER_1.Address
                                )
                        ),
                        input[i].priorityEVVM,
                        input[i].nonceStaking
                    );

                    vm.startPrank(FISHER.Address);

                    staking.publicStaking(
                        COMMON_USER_NO_STAKER_1.Address,
                        input[i].isStaking,
                        stakingFullAmountBefore,
                        input[i].nonceStaking,
                        signatureStaking,
                        totalOfPriorityFee,
                        (
                            input[i].priorityEVVM
                                ? input[i].nonceEVVM
                                : evvm.getNextCurrentSyncNonce(
                                    COMMON_USER_NO_STAKER_1.Address
                                )
                        ),
                        input[i].priorityEVVM,
                        signatureEVVM
                    );

                    vm.stopPrank();
                } else {
                    (, uint256 totalOfPriorityFee) = giveMateToExecute(
                        COMMON_USER_NO_STAKER_1.Address,
                        0,
                        (
                            input[i].givePriorityFee
                                ? input[i].priorityFeeAmountEVVM
                                : 0
                        )
                    );

                    (signatureEVVM, signatureStaking) = makeSignature(
                        input[i].isStaking,
                        input[i].stakingAmount,
                        totalOfPriorityFee,
                        (
                            input[i].priorityEVVM
                                ? input[i].nonceEVVM
                                : evvm.getNextCurrentSyncNonce(
                                    COMMON_USER_NO_STAKER_1.Address
                                )
                        ),
                        input[i].priorityEVVM,
                        input[i].nonceStaking
                    );

                    vm.startPrank(FISHER.Address);

                    staking.publicStaking(
                        COMMON_USER_NO_STAKER_1.Address,
                        input[i].isStaking,
                        input[i].stakingAmount,
                        input[i].nonceStaking,
                        signatureStaking,
                        totalOfPriorityFee,
                        (
                            input[i].priorityEVVM
                                ? input[i].nonceEVVM
                                : evvm.getNextCurrentSyncNonce(
                                    COMMON_USER_NO_STAKER_1.Address
                                )
                        ),
                        input[i].priorityEVVM,
                        signatureEVVM
                    );

                    vm.stopPrank();
                }
            }

            history = staking.getAddressHistoryByIndex(
                COMMON_USER_NO_STAKER_1.Address,
                (i + 1) - incorrectTxCount
            );

            if (input[i].usingStaker) {
                assertEq(
                    evvm.getBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                    amountBeforeFisher +
                        calculateRewardPerExecution(1) +
                        (
                            input[i].givePriorityFee
                                ? uint256(input[i].priorityFeeAmountEVVM)
                                : 0
                        )
                );
            } else {
                assertEq(
                    evvm.getBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                    amountBeforeFisher
                );
            }

            assertEq(
                evvm.getBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                amountBeforeUser +
                    (
                        input[i].isStaking
                            ? 0
                            : (
                                staking.getUserAmountStaked(
                                    COMMON_USER_NO_STAKER_1.Address
                                ) == 0
                                    ? staking.priceOfStaking() *
                                        stakingFullAmountBefore
                                    : staking.priceOfStaking() *
                                        input[i].stakingAmount
                            )
                    )
            );

            assertEq(history.timestamp, block.timestamp);
            assert(
                history.transactionType ==
                    (
                        input[i].isStaking
                            ? DEPOSIT_HISTORY_SMATE_IDENTIFIER
                            : WITHDRAW_HISTORY_SMATE_IDENTIFIER
                    )
            );

            if (input[i].isStaking) {
                assertEq(history.amount, input[i].stakingAmount);

                assertEq(
                    history.totalStaked,
                    totalStakedBefore + input[i].stakingAmount
                );
            } else {
                assertEq(
                    history.amount,
                    (
                        staking.getUserAmountStaked(
                            COMMON_USER_NO_STAKER_1.Address
                        ) == 0
                            ? stakingFullAmountBefore
                            : input[i].stakingAmount
                    )
                );

                assertEq(
                    history.totalStaked,
                    totalStakedBefore -
                        (
                            staking.getUserAmountStaked(
                                COMMON_USER_NO_STAKER_1.Address
                            ) == 0
                                ? stakingFullAmountBefore
                                : input[i].stakingAmount
                        )
                );
            }
        }
    }
}
