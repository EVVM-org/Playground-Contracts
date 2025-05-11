// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

/**

:::::::::: :::    ::: ::::::::: :::::::::      ::::::::::: :::::::::: :::::::: ::::::::::: 
:+:        :+:    :+:      :+:       :+:           :+:     :+:       :+:    :+:    :+:     
+:+        +:+    +:+     +:+       +:+            +:+     +:+       +:+           +:+     
:#::+::#   +#+    +:+    +#+       +#+             +#+     +#++:++#  +#++:++#++    +#+     
+#+        +#+    +#+   +#+       +#+              +#+     +#+              +#+    +#+     
#+#        #+#    #+#  #+#       #+#               #+#     #+#       #+#    #+#    #+#     
###         ########  ######### #########          ###     ########## ########     ###     


 * @title fuzz test for sMate function correct behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract fuzzTest_SMate_publicStaking is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        giveMateToExecute(COMMON_USER_NO_STAKER_1.Address, 10, 0);

        (
            bytes memory signatureEVVM,
            bytes memory signatureSMate
        ) = makeSignature(
                true,
                10,
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                0
            );

        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            0,
            10,
            signatureSMate,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
    }

    function giveMateToExecute(
        address user,
        uint256 sMateAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (sMate.priceOfSMate() * sMateAmount) + priorityFee
        );

        totalOfMate = (sMate.priceOfSMate() * sMateAmount);
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
        returns (bytes memory signatureEVVM, bytes memory signatureSMate)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(sMate),
                    "",
                    MATE_TOKEN_ADDRESS,
                    sMate.priceOfSMate() * amountOfSmate,
                    priorityFee,
                    nonceEVVM,
                    priorityEVVM,
                    address(sMate)
                )
            );
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(sMate),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFee,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(sMate)
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
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function calculateRewardPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
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
        uint144 nonceSMate;
        uint144 nonceEVVM;
        bool priorityEVVM;
        bool givePriorityFee;
        uint16 priorityFeeAmountEVVM;
    }

    function test__fuzz__publicStaking(
        PublicStakingFuzzTestInput[20] memory input
    ) external {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        SMateMock.HistoryMetadata memory history;
        uint256 amountBeforeFisher;
        uint256 amountBeforeUser;
        uint256 totalStakedBefore;
        AccountData memory FISHER;
        uint256 incorrectTxCount = 0;
        uint256 sMateFullAmountBefore;

        for (uint256 i = 0; i < input.length; i++) {
            if (
                sMate.checkIfStakeNonceUsed(
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].nonceSMate
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

            amountBeforeFisher = evvm.seeBalance(
                FISHER.Address,
                MATE_TOKEN_ADDRESS
            );

            amountBeforeUser = evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            );

            totalStakedBefore = sMate.getUserAmountStaked(
                COMMON_USER_NO_STAKER_1.Address
            );

            if (input[i].isStaking) {
                // staking
                if (
                    sMate.getUserAmountStaked(
                        COMMON_USER_NO_STAKER_1.Address
                    ) == 0
                ) {
                    vm.warp(
                        sMate.getTimeToUserUnlockStakingTime(
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

                (signatureEVVM, signatureSMate) = makeSignature(
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
                    input[i].nonceSMate
                );

                vm.startPrank(FISHER.Address);

                sMate.publicStaking(
                    input[i].isStaking,
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].nonceSMate,
                    input[i].stakingAmount,
                    signatureSMate,
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
                    sMate.getUserAmountStaked(COMMON_USER_NO_STAKER_1.Address)
                ) {
                    vm.warp(
                        sMate.getTimeToUserUnlockFullUnstakingTime(
                            COMMON_USER_NO_STAKER_1.Address
                        )
                    );

                    sMateFullAmountBefore = sMate.getUserAmountStaked(
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

                    (signatureEVVM, signatureSMate) = makeSignature(
                        input[i].isStaking,
                        sMateFullAmountBefore,
                        totalOfPriorityFee,
                        (
                            input[i].priorityEVVM
                                ? input[i].nonceEVVM
                                : evvm.getNextCurrentSyncNonce(
                                    COMMON_USER_NO_STAKER_1.Address
                                )
                        ),
                        input[i].priorityEVVM,
                        input[i].nonceSMate
                    );

                    vm.startPrank(FISHER.Address);

                    sMate.publicStaking(
                        input[i].isStaking,
                        COMMON_USER_NO_STAKER_1.Address,
                        input[i].nonceSMate,
                        sMateFullAmountBefore,
                        signatureSMate,
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

                    (signatureEVVM, signatureSMate) = makeSignature(
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
                        input[i].nonceSMate
                    );

                    vm.startPrank(FISHER.Address);

                    sMate.publicStaking(
                        input[i].isStaking,
                        COMMON_USER_NO_STAKER_1.Address,
                        input[i].nonceSMate,
                        input[i].stakingAmount,
                        signatureSMate,
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

            history = sMate.getAddressHistoryByIndex(
                COMMON_USER_NO_STAKER_1.Address,
                (i + 1) - incorrectTxCount
            );

            if (input[i].usingStaker) {
                assertEq(
                    evvm.seeBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
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
                    evvm.seeBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                    amountBeforeFisher
                );
            }

            assertEq(
                evvm.seeBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                amountBeforeUser +
                    (
                        input[i].isStaking
                            ? 0
                            : (
                                sMate.getUserAmountStaked(
                                    COMMON_USER_NO_STAKER_1.Address
                                ) == 0
                                    ? sMate.priceOfSMate() *
                                        sMateFullAmountBefore
                                    : sMate.priceOfSMate() *
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
                        sMate.getUserAmountStaked(
                            COMMON_USER_NO_STAKER_1.Address
                        ) == 0
                            ? sMateFullAmountBefore
                            : input[i].stakingAmount
                    )
                );

                assertEq(
                    history.totalStaked,
                    totalStakedBefore -
                        (
                            sMate.getUserAmountStaked(
                                COMMON_USER_NO_STAKER_1.Address
                            ) == 0
                                ? sMateFullAmountBefore
                                : input[i].stakingAmount
                        )
                );
            }
        }
    }
}
