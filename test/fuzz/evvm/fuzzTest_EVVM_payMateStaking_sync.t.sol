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

contract fuzzTest_EVVM_payMateStaking_sync is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_STAKER_1 = COMMON_USER_STAKER;
    AccountData COMMON_USER_STAKER_2 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());
        evvm._setPointStaker(COMMON_USER_STAKER_1.Address, 0x01);
        evvm._setPointStaker(COMMON_USER_STAKER_2.Address, 0x01);

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

    /**
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nPF: No priority fee
     * EX: Includes executor execution
     * nEX: Does not include executor execution
     * ID: Uses a MNS identity
     * AD: Uses an address
     */

    struct PayMateStakingSyncFuzzTestInput_nPF {
        bool useToAddress;
        bool useExecutor;
        bool useNoStaker3;
        address token;
        uint16 amount;
    }

    struct PayMateStakingSyncFuzzTestInput_PF {
        bool useToAddress;
        bool useExecutor;
        bool useNoStaker3;
        address token;
        uint16 amount;
        uint16 priorityFee;
    }

    function test__fuzz__payMateStaking_sync__nPF(
        PayMateStakingSyncFuzzTestInput_nPF memory input
    ) external {
        vm.assume(input.amount > 0);

        AccountData memory selectedExecuter = input.useNoStaker3
            ? COMMON_USER_STAKER_1
            : COMMON_USER_STAKER_2;

        (uint256 totalAmount, uint256 totalPriorityFee) = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.token,
            input.amount,
            0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                input.useToAddress
                    ? COMMON_USER_NO_STAKER_2.Address
                    : address(0),
                input.useToAddress ? "" : "dummy",
                input.token,
                totalAmount,
                totalPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                input.useExecutor ? selectedExecuter.Address : address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            input.useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            input.useToAddress ? "" : "dummy",
            input.token,
            totalAmount,
            totalPriorityFee,
            input.useExecutor ? selectedExecuter.Address : address(0),
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            0
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            totalAmount
        );

        if (input.token == MATE_TOKEN_ADDRESS) {
            assertEq(
                evvm.seeBalance(selectedExecuter.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward() + totalPriorityFee
            );
        } else {
            assertEq(
                evvm.seeBalance(selectedExecuter.Address, input.token),
                totalPriorityFee
            );
            assertEq(
                evvm.seeBalance(selectedExecuter.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward()
            );
        }
    }

    function test__fuzz__payMateStaking_sync__PF(
        PayMateStakingSyncFuzzTestInput_PF memory input
    ) external {
        vm.assume(input.amount > 0);

        AccountData memory selectedExecuter = input.useNoStaker3
            ? COMMON_USER_STAKER_1
            : COMMON_USER_STAKER_2;

        (uint256 totalAmount, uint256 totalPriorityFee) = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.token,
            input.amount,
            input.priorityFee
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                input.useToAddress
                    ? COMMON_USER_NO_STAKER_2.Address
                    : address(0),
                input.useToAddress ? "" : "dummy",
                input.token,
                totalAmount,
                totalPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                input.useExecutor ? selectedExecuter.Address : address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            input.useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            input.useToAddress ? "" : "dummy",
            input.token,
            totalAmount,
            totalPriorityFee,
            input.useExecutor ? selectedExecuter.Address : address(0),
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            0
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            totalAmount
        );

        if (input.token == MATE_TOKEN_ADDRESS) {
            assertEq(
                evvm.seeBalance(selectedExecuter.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward() + totalPriorityFee
            );
        } else {
            assertEq(
                evvm.seeBalance(selectedExecuter.Address, input.token),
                totalPriorityFee
            );
            assertEq(
                evvm.seeBalance(selectedExecuter.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward()
            );
        }
    }
}
