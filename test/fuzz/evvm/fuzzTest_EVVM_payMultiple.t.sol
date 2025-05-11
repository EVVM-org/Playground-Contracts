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

 * @title unit test for EVVM function correct behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

contract fuzzTest_EVVM_payMultiple is Test, Constants, EvvmMockStructs {
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
        mns._setIdentityBaseMetadata(
            "dummy",
            MateNameServiceMock.IdentityBaseMetadata({
                owner: COMMON_USER_NO_STAKER_2.Address,
                expireDate: block.timestamp + 366 days,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x00
            })
        );
    }

    function addBalance(
        AccountData memory user,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee
    ) private returns (uint256 totalAmount, uint256 totalPriorityFee) {
        evvm._addBalance(user.Address, tokenAddress, amount + priorityFee);

        totalAmount = amount;
        totalPriorityFee = priorityFee;
    }

    function makeSignaturePay(
        AccountData memory user,
        address toAddress,
        string memory toIdentity,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        address executor
    ) private pure returns (bytes memory signatureEVVM) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                toAddress,
                toIdentity,
                tokenAddress,
                amount,
                priorityFee,
                nonce,
                priorityFlag,
                executor
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    /**
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nPF: No priority fee
     * EX: Includes executor execution
     * nEX: Does not include executor execution
     * ID: Uses a MNS identity
     * AD: Uses an address
     */

    struct PayMultipleFuzzTestInput {
        bool useStaker;
        bool[2] useToAddress;
        bool[2] useExecutor;
        address[2] token;
        uint16[2] amount;
        uint16[2] priorityFee;
        uint176[2] nonce;
        bool[2] priorityFlag;
    }

    function test__unit_correct__payMultiple__nonStaker(
        PayMultipleFuzzTestInput memory input
    ) external {
        vm.assume(
            input.amount[0] > 0 &&
                input.amount[1] > 0 &&
                input.token[0] != input.token[1] &&
                input.token[0] != MATE_TOKEN_ADDRESS &&
                input.token[1] != MATE_TOKEN_ADDRESS
        );

        EvvmMockStructs.PayData[]
            memory payData = new EvvmMockStructs.PayData[](2);

        AccountData memory FISHER = input.useStaker
            ? COMMON_USER_STAKER
            : COMMON_USER_NO_STAKER_3;

        bytes[3] memory signature;

        signature[0] = makeSignaturePay(
            COMMON_USER_NO_STAKER_1,
            input.useToAddress[0]
                ? COMMON_USER_NO_STAKER_2.Address
                : address(0),
            input.useToAddress[0] ? "" : "dummy",
            input.token[0],
            input.amount[0],
            input.priorityFee[0],
            input.priorityFlag[0]
                ? input.nonce[0]
                : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            input.priorityFlag[0],
            input.useExecutor[0] ? FISHER.Address : address(0)
        );

        signature[1] = makeSignaturePay(
            COMMON_USER_NO_STAKER_1,
            input.useToAddress[1]
                ? COMMON_USER_NO_STAKER_2.Address
                : address(0),
            input.useToAddress[1] ? "" : "dummy",
            input.token[1],
            input.amount[1],
            input.priorityFee[1],
            input.priorityFlag[1]
                ? input.nonce[1]
                : (
                    input.priorityFlag[0] == false
                        ? evvm.getNextCurrentSyncNonce(
                            COMMON_USER_NO_STAKER_1.Address
                        ) + 1
                        : evvm.getNextCurrentSyncNonce(
                            COMMON_USER_NO_STAKER_1.Address
                        )
                ),
            input.priorityFlag[1],
            input.useExecutor[1] ? FISHER.Address : address(0)
        );

        for (uint256 i = 0; i < 2; i++) {
            addBalance(
                COMMON_USER_NO_STAKER_1,
                input.token[i],
                input.amount[i],
                input.priorityFee[i]
            );

            payData[i] = EvvmMockStructs.PayData({
                from: COMMON_USER_NO_STAKER_1.Address,
                to_address: input.useToAddress[i]
                    ? COMMON_USER_NO_STAKER_2.Address
                    : address(0),
                to_identity: input.useToAddress[i] ? "" : "dummy",
                token: input.token[i],
                amount: input.amount[i],
                priorityFee: input.priorityFee[i],
                nonce: input.priorityFlag[i]
                    ? input.nonce[i]
                    : (
                        input.priorityFlag[0] == false && i == 1
                            ? evvm.getNextCurrentSyncNonce(
                                COMMON_USER_NO_STAKER_1.Address
                            ) + 1
                            : evvm.getNextCurrentSyncNonce(
                                COMMON_USER_NO_STAKER_1.Address
                            )
                    ),
                priority: input.priorityFlag[i],
                executor: input.useExecutor[i] ? FISHER.Address : address(0),
                signature: signature[i]
            });
        }

        vm.startPrank(FISHER.Address);
        (
            uint256 successfulTransactions,
            uint256 failedTransactions,
            bool[] memory status
        ) = evvm.payMultiple(payData);
        vm.stopPrank();

        assertEq(successfulTransactions, 2);
        assertEq(failedTransactions, 0);
        assertEq(status[0], true);
        assertEq(status[1], true);

        for (uint256 i = 0; i < 2; i++) {
            assertEq(
                evvm.seeBalance(
                    COMMON_USER_NO_STAKER_2.Address,
                    input.token[i]
                ),
                input.amount[i]
            );
        }

        if (FISHER.Address == COMMON_USER_STAKER.Address) {
            for (uint256 i = 0; i < 2; i++) {
                assertEq(
                    evvm.seeBalance(COMMON_USER_STAKER.Address, input.token[i]),
                    input.priorityFee[i]
                );
            }

            assertEq(
                evvm.seeBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward() * 2
            );
        } else {
            for (uint256 i = 0; i < 2; i++) {
                assertEq(
                    evvm.seeBalance(
                        COMMON_USER_NO_STAKER_1.Address,
                        input.token[i]
                    ),
                    input.priorityFee[i]
                );
            }

            assertEq(
                evvm.seeBalance(
                    COMMON_USER_NO_STAKER_3.Address,
                    MATE_TOKEN_ADDRESS
                ),
                0
            );
        }

        for (uint256 i = 0; i < 2; i++) {
            assertEq(
                evvm.seeBalance(
                    COMMON_USER_NO_STAKER_2.Address,
                    input.token[i]
                ),
                input.amount[i]
            );
        }
    }
}
