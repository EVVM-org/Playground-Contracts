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

import {Constants, MockContract} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

import {SMate} from "@EVVM/playground/staking/SMate.sol";
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract fuzzTest_SMate_publicServiceStaking is Test, Constants {
    SMate sMate;
    Evvm evvm;
    Estimator estimator;
    Mns mns;
    MockContract mockContract;

    function setUp() public {
        sMate = new SMate(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new Mns(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mns));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        mockContract = new MockContract(address(sMate));

        giveMateToExecute(COMMON_USER_NO_STAKER_1.Address, 10, 0);

        (
            bytes memory signatureEVVM,
            bytes memory signatureSMate
        ) = makeSignature(
                address(mockContract),
                true,
                10,
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                0
            );

        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mockContract),
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
        address serviceAddress,
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                serviceAddress,
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

    struct PublicServiceStakingFuzzTestInput {
        bool isStaking;
        bool usingStaker;
        uint8 stakingAmount;
        uint144 nonceSMate;
        uint144 nonceEVVM;
        bool priorityEVVM;
        bool givePriorityFee;
        uint16 priorityFeeAmountEVVM;
    }

    struct AmountBeforeMetadata {
        uint256 fisher;
        uint256 user;
        uint256 service;
    }

    function test__fuzz__publicServiceStaking(
        PublicServiceStakingFuzzTestInput[20] memory input
    ) external {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        SMate.HistoryMetadata memory history;
        AmountBeforeMetadata memory amountBefore;
        uint256 totalStakedBefore;
        AccountData memory FISHER;
        uint256 incorrectTxCount = 0;
        uint256 sMateFullAmountBefore;

        for (uint256 i = 0; i < input.length; i++) {
            if (
                sMate.checkIfStakeNonceUsed(
                    (
                        input[i].isStaking
                            ? COMMON_USER_NO_STAKER_1.Address
                            : address(mockContract)
                    ),
                    input[i].nonceSMate
                )
            ) {
                incorrectTxCount++;
                continue;
            }

            if (
                evvm.getIfUsedAsyncNonce(
                    (
                        input[i].isStaking
                            ? COMMON_USER_NO_STAKER_1.Address
                            : address(mockContract)
                    ),
                    input[i].nonceEVVM
                )
            ) {
                incorrectTxCount++;
                continue;
            }

            FISHER = input[i].usingStaker
                ? COMMON_USER_STAKER
                : COMMON_USER_NO_STAKER_2;

            amountBefore = AmountBeforeMetadata({
                fisher: evvm.seeBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                user: evvm.seeBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                service: evvm.seeBalance(
                    address(mockContract),
                    MATE_TOKEN_ADDRESS
                )
            });

            totalStakedBefore = sMate.getUserAmountStaked(
                address(mockContract)
            );

            if (input[i].isStaking) {
                // staking
                if (sMate.getUserAmountStaked(address(mockContract)) == 0) {
                    vm.warp(
                        sMate.getTimeToUserUnlockStakingTime(
                            address(mockContract)
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
                    address(mockContract),
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

                sMate.publicServiceStaking(
                    input[i].isStaking,
                    COMMON_USER_NO_STAKER_1.Address,
                    address(mockContract),
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
                    sMate.getUserAmountStaked(address(mockContract))
                ) {
                    vm.warp(
                        sMate.getTimeToUserUnlockFullUnstakingTime(
                            address(mockContract)
                        )
                    );

                    sMateFullAmountBefore = sMate.getUserAmountStaked(
                        address(mockContract)
                    );

                    mockContract.unstake(
                        sMateFullAmountBefore,
                        input[i].nonceSMate,
                        address(mockContract)
                    );
                } else {
                    mockContract.unstake(
                        input[i].stakingAmount,
                        input[i].nonceSMate,
                        address(mockContract)
                    );
                }
            }

            history = sMate.getAddressHistoryByIndex(
                address(mockContract),
                (i + 1) - incorrectTxCount
            );

            if (input[i].usingStaker && input[i].isStaking) {
                assertEq(
                    evvm.seeBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                    amountBefore.fisher +
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
                    amountBefore.fisher
                );
            }

            assertEq(
                evvm.seeBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                amountBefore.user
            );

            if (!input[i].isStaking) {
                if (sMate.getUserAmountStaked(address(mockContract)) == 0) {
                    assert(
                        evvm.seeBalance(
                            address(mockContract),
                            MATE_TOKEN_ADDRESS
                        ) ==
                            (amountBefore.service +
                                (sMateFullAmountBefore * sMate.priceOfSMate()))
                    );
                } else {

                    assert(
                        evvm.seeBalance(
                            address(mockContract),
                            MATE_TOKEN_ADDRESS
                        ) ==
                            ((amountBefore.service +
                                (input[i].stakingAmount *
                                    sMate.priceOfSMate())) +
                                (evvm.seeMateReward() * 2))
                    );
                }
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
                        sMate.getUserAmountStaked(address(mockContract)) == 0
                            ? sMateFullAmountBefore
                            : input[i].stakingAmount
                    )
                );

                assertEq(
                    history.totalStaked,
                    totalStakedBefore -
                        (
                            sMate.getUserAmountStaked(address(mockContract)) ==
                                0
                                ? sMateFullAmountBefore
                                : input[i].stakingAmount
                        )
                );
            }
        }
    }
}
