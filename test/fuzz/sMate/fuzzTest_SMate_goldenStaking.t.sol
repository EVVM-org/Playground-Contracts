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

contract fuzzTest_SMate_goldenStaking is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        uint256 totalAmount = giveMateToExecute(GOLDEN_STAKER.Address, 10);

        bytes memory signatureEVVM = makePaySignature(totalAmount);

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 10, signatureEVVM);

        vm.stopPrank();
    }

    function giveMateToExecute(
        address user,
        uint256 sMateAmount
    ) private returns (uint256 totalAmount) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            sMate.priceOfSMate() * sMateAmount
        );

        totalAmount = sMate.priceOfSMate() * sMateAmount;
    }

    function calculateRewardPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
    }

    function makePaySignature(
        uint256 amount
    ) private returns (bytes memory signatureEVVM) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                amount,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    struct GoldenStakingFuzzTestInput {
        bool isStaking;
        uint8 amount;
    }

    function test__fuzz__goldenStaking__staking(
        GoldenStakingFuzzTestInput[10] memory input
    ) external {
        uint256 totalAmount;
        bytes memory signatureEVVM;
        uint256 amountBefore;
        uint256 sMateFullAmountBefore;
        uint256 totalStakedBefore;

        for (uint256 i = 0; i < input.length; i++) {
            console2.log("isStaking", input[i].isStaking);
            console2.log("amount", input[i].amount);

            totalStakedBefore = sMate.getUserAmountStaked(
                GOLDEN_STAKER.Address
            );

            amountBefore = evvm.seeBalance(
                GOLDEN_STAKER.Address,
                MATE_TOKEN_ADDRESS
            );
            if (input[i].isStaking) {
                // staking
                if (sMate.getUserAmountStaked(GOLDEN_STAKER.Address) == 0) {
                    vm.warp(
                        sMate.getTimeToUserUnlockStakingTime(
                            GOLDEN_STAKER.Address
                        )
                    );
                }

                totalAmount = giveMateToExecute(
                    GOLDEN_STAKER.Address,
                    input[i].amount
                );

                signatureEVVM = makePaySignature(totalAmount);

                vm.startPrank(GOLDEN_STAKER.Address);

                sMate.goldenStaking(
                    input[i].isStaking,
                    input[i].amount,
                    signatureEVVM
                );

                vm.stopPrank();

                assert(evvm.isMateStaker(GOLDEN_STAKER.Address));
            } else {
                // unstaking
                if (
                    input[i].amount >=
                    sMate.getUserAmountStaked(GOLDEN_STAKER.Address)
                ) {
                    vm.warp(
                        sMate.getTimeToUserUnlockFullUnstakingTime(
                            GOLDEN_STAKER.Address
                        )
                    );

                    sMateFullAmountBefore = sMate.getUserAmountStaked(
                        GOLDEN_STAKER.Address
                    );
                    vm.startPrank(GOLDEN_STAKER.Address);

                    sMate.goldenStaking(
                        input[i].isStaking,
                        sMate.getUserAmountStaked(GOLDEN_STAKER.Address),
                        signatureEVVM
                    );

                    vm.stopPrank();

                    assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
                } else {
                    vm.startPrank(GOLDEN_STAKER.Address);

                    sMate.goldenStaking(
                        input[i].isStaking,
                        input[i].amount,
                        signatureEVVM
                    );

                    vm.stopPrank();
                }
            }

            SMateMock.HistoryMetadata memory history = sMate
                .getAddressHistoryByIndex(GOLDEN_STAKER.Address, i + 1);

            assertEq(
                evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
                amountBefore +
                    calculateRewardPerExecution(
                        evvm.isMateStaker(GOLDEN_STAKER.Address) ? 1 : 0
                    ) +
                    (
                        input[i].isStaking
                            ? 0
                            : (
                                sMate.getUserAmountStaked(
                                    GOLDEN_STAKER.Address
                                ) == 0
                                    ? sMate.priceOfSMate() *
                                        sMateFullAmountBefore
                                    : sMate.priceOfSMate() * input[i].amount
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
            assertEq(
                history.amount,
                (
                    input[i].isStaking
                        ? input[i].amount
                        : (
                            sMate.getUserAmountStaked(GOLDEN_STAKER.Address) ==
                                0
                                ? sMateFullAmountBefore
                                : input[i].amount
                        )
                )
            );
            if (input[i].isStaking) {
                assertEq(
                    history.totalStaked,
                    totalStakedBefore + input[i].amount
                );
            } else {
                assertEq(
                    history.totalStaked,
                    totalStakedBefore -
                        (
                            sMate.getUserAmountStaked(GOLDEN_STAKER.Address) ==
                                0
                                ? sMateFullAmountBefore
                                : input[i].amount
                        )
                );
            }
        }
    }
}
