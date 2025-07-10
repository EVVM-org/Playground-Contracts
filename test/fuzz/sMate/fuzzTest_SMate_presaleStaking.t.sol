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
import {EvvmMockStructs} from "@EVVM/playground/core/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";

contract fuzzTest_SMate_presaleStaking is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new EvvmMock(ADMIN.Address, address(sMate));
        estimator = new EstimatorMock(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new MateNameServiceMock(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mns));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPresaleStaking();
        skip(1 days);
        sMate.confirmChangeAllowPresaleStaking();

        sMate.addPresaleStaker(COMMON_USER_NO_STAKER_1.Address);
        vm.stopPrank();

        giveMateToExecute(COMMON_USER_NO_STAKER_1, true, 0);

        (
            bytes memory signatureEVVM,
            bytes memory signatureSMate
        ) = makeSignature(true, 0, 0, 0, false);

        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            0,
            signatureSMate,
            0,
            0,
            false,
            signatureEVVM
        );
    }

    function giveMateToExecute(
        AccountData memory user,
        bool isStaking,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            (isStaking ? (sMate.priceOfSMate() * 1) : 0) + priorityFee
        );

        totalOfMate = (isStaking ? (sMate.priceOfSMate() * 1) : 0);
        totalOfPriorityFee = priorityFee;
    }

    function makeSignature(
        bool isStaking,
        uint256 priorityFee,
        uint256 nonceSmate,
        uint256 nonceEVVM,
        bool priorityEVVM
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
                    sMate.priceOfSMate() * 1,
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
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                isStaking,
                1,
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

    struct PresaleStakingFuzzTestInput {
        bool isStaking;
        bool usingStaker;
        uint144 nonceSMate;
        uint144 nonceEVVM;
        bool priorityEVVM;
        bool givePriorityFee;
        uint16 priorityFeeAmountEVVM;
    }

    function test__fuzz__presaleStaking_AsyncExecution(
        PresaleStakingFuzzTestInput[20] memory input
    ) external {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        SMateMock.HistoryMetadata memory history;
        uint256 amountBeforeFisher;
        uint256 amountBeforeUser;
        uint256 totalStakedBefore;
        AccountData memory FISHER;

        uint256 incorrectTxCount = 0;

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
                    ) == 2
                ) {
                    incorrectTxCount++;
                    continue;
                }
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

                giveMateToExecute(
                    COMMON_USER_NO_STAKER_1,
                    true,
                    (
                        input[i].givePriorityFee
                            ? uint256(input[i].priorityFeeAmountEVVM)
                            : 0
                    )
                );

                (signatureEVVM, signatureSMate) = makeSignature(
                    input[i].isStaking,
                    (
                        input[i].givePriorityFee
                            ? uint256(input[i].priorityFeeAmountEVVM)
                            : 0
                    ),
                    input[i].nonceSMate,
                    (
                        input[i].priorityEVVM
                            ? input[i].nonceEVVM
                            : evvm.getNextCurrentSyncNonce(
                                COMMON_USER_NO_STAKER_1.Address
                            )
                    ),
                    input[i].priorityEVVM
                );

                vm.startPrank(FISHER.Address);
                sMate.presaleStaking(
                    input[i].isStaking,
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].nonceSMate,
                    signatureSMate,
                    (
                        input[i].givePriorityFee
                            ? uint256(input[i].priorityFeeAmountEVVM)
                            : 0
                    ),
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
                    sMate.getUserAmountStaked(
                        COMMON_USER_NO_STAKER_1.Address
                    ) == 0
                ) {
                    incorrectTxCount++;
                    continue;
                }

                if (
                    sMate.getUserAmountStaked(
                        COMMON_USER_NO_STAKER_1.Address
                    ) == 1
                ) {
                    vm.warp(
                        sMate.getTimeToUserUnlockFullUnstakingTime(
                            COMMON_USER_NO_STAKER_1.Address
                        )
                    );
                }

                if (input[i].givePriorityFee) {
                    giveMateToExecute(
                        COMMON_USER_NO_STAKER_1,
                        false,
                        uint256(input[i].priorityFeeAmountEVVM)
                    );
                }

                (signatureEVVM, signatureSMate) = makeSignature(
                    input[i].isStaking,
                    (
                        input[i].givePriorityFee
                            ? uint256(input[i].priorityFeeAmountEVVM)
                            : 0
                    ),
                    input[i].nonceSMate,
                    (
                        input[i].priorityEVVM
                            ? input[i].nonceEVVM
                            : evvm.getNextCurrentSyncNonce(
                                COMMON_USER_NO_STAKER_1.Address
                            )
                    ),
                    input[i].priorityEVVM
                );

                vm.startPrank(FISHER.Address);
                sMate.presaleStaking(
                    input[i].isStaking,
                    COMMON_USER_NO_STAKER_1.Address,
                    input[i].nonceSMate,
                    signatureSMate,
                    (
                        input[i].givePriorityFee
                            ? uint256(input[i].priorityFeeAmountEVVM)
                            : 0
                    ),
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

            history = sMate.getAddressHistoryByIndex(
                COMMON_USER_NO_STAKER_1.Address,
                (i + 1) - incorrectTxCount
            );

            assertEq(
                evvm.seeBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                amountBeforeUser +
                    (input[i].isStaking ? 0 : sMate.priceOfSMate() * 1)
            );

            if (FISHER.Address == COMMON_USER_STAKER.Address) {
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

            assertEq(history.timestamp, block.timestamp);
            assert(
                history.transactionType ==
                    (
                        input[i].isStaking
                            ? DEPOSIT_HISTORY_SMATE_IDENTIFIER
                            : WITHDRAW_HISTORY_SMATE_IDENTIFIER
                    )
            );

            assertEq(history.amount, 1);

            if (input[i].isStaking) {
                assertEq(history.totalStaked, totalStakedBefore + 1);
            } else {
                assertEq(history.totalStaked, totalStakedBefore - 1);
            }
        }
    }
}
