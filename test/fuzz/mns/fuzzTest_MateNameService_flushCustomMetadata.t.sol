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

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract fuzzTest_MateNameService_flushCustomMetadata is Test, Constants {
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

        makeRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101,
            20202
        );
    }

    function addBalance(
        AccountData memory user,
        string memory usernameToFlushCustomMetadata,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount)
    {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            mns.getPriceToFlushCustomMetadata(usernameToFlushCustomMetadata) +
                priorityFeeAmount
        );

        totalAmountFlush = mns.getPriceToFlushCustomMetadata(
            usernameToFlushCustomMetadata
        );
        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makeRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNSPre,
        uint256 nonceMNS
    ) private {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            mns.getPricePerRegistration()
        );

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceMNSPre
            )
        );

        mns.preRegistrationUsername(
            user.Address,
            nonceMNSPre,
            keccak256(abi.encodePacked(username, uint256(clowNumber))),
            0,
            Erc191TestBuilder.buildERC191Signature(v, r, s),
            0,
            false,
            hex""
        );

        skip(30 minutes);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                username,
                clowNumber,
                nonceMNS
            )
        );
        bytes memory signatureMNS = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                mns.getPricePerRegistration(),
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                address(mns)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        mns.registrationUsername(
            user.Address,
            nonceMNS,
            username,
            clowNumber,
            signatureMNS,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
    }

    function makeAddCustomMetadata(
        AccountData memory user,
        string memory username,
        string memory customMetadata,
        uint256 nonceMNS,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    ) private {
        uint8 v;
        bytes32 r;
        bytes32 s;

        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            mns.getPriceToAddCustomMetadata()
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                username,
                customMetadata,
                nonceMNS
            )
        );
        bytes memory signatureMNS = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                mns.getPriceToAddCustomMetadata(),
                0,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        mns.addCustomMetadata(
            user.Address,
            nonceMNS,
            username,
            customMetadata,
            0,
            signatureMNS,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeFlushCustomMetadataSignatures(
        AccountData memory user,
        string memory username,
        uint256 nonceMNS,
        uint256 priorityFeeAmountEVVM,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    )
        private
        view
        returns (bytes memory signatureMNS, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                username,
                nonceMNS
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                mns.getPriceToFlushCustomMetadata(username),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function setAmountOfCustomMetadata(
        AccountData memory user,
        string memory username,
        uint256 amount
    ) private {
        for (uint256 i = 0; i < amount; i++) {
            makeAddCustomMetadata(
                user,
                username,
                string.concat("test>", Strings.toString(i)),
                i,
                i,
                true
            );
        }
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct FlushCustomMetadataFuzzTestInput_nPF {
        uint8 amountOfCustomMetadata;
        uint32 nonceMNS;
        uint32 nonceEVVM;
        bool priorityFlagEVVM;
    }

    struct FlushCustomMetadataFuzzTestInput_PF {
        uint8 amountOfCustomMetadata;
        uint32 nonceMNS;
        uint32 nonceEVVM;
        uint16 priorityFeeAmountEVVM;
        bool priorityFlagEVVM;
    }

    function test__fuzz__flushCustomMetadata__nS_nPF(
        FlushCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        vm.assume(
            input.nonceMNS > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceMNS != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceMNS != 20202 &&
                input.nonceEVVM != 20202 &&
                uint256(input.amountOfCustomMetadata) > 0
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        setAmountOfCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            input.amountOfCustomMetadata
        );
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceMNS,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__flushCustomMetadata__nS_PF(
        FlushCustomMetadataFuzzTestInput_PF memory input
    ) external {
        vm.assume(
            input.nonceMNS > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceMNS != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceMNS != 20202 &&
                input.nonceEVVM != 20202 &&
                uint256(input.amountOfCustomMetadata) > 0 &&
                input.priorityFeeAmountEVVM > 0
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        setAmountOfCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            input.amountOfCustomMetadata
        );
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            input.priorityFeeAmountEVVM
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceMNS,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__flushCustomMetadata__S_nPF(
        FlushCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        vm.assume(
            input.nonceMNS > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceMNS != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceMNS != 20202 &&
                input.nonceEVVM != 20202 &&
                uint256(input.amountOfCustomMetadata) > 0
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        setAmountOfCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            input.amountOfCustomMetadata
        );
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceMNS,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            ((5 * evvm.seeMateReward()) * input.amountOfCustomMetadata) +
                totalPriorityFeeAmount
        );
    }

    function test__fuzz__flushCustomMetadata__S_PF(
        FlushCustomMetadataFuzzTestInput_PF memory input
    ) external {
        vm.assume(
            input.nonceMNS > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceMNS != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceMNS != 20202 &&
                input.nonceEVVM != 20202 &&
                uint256(input.amountOfCustomMetadata) > 0 &&
                input.priorityFeeAmountEVVM > 0
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        setAmountOfCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            input.amountOfCustomMetadata
        );
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            input.priorityFeeAmountEVVM
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceMNS,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            ((5 * evvm.seeMateReward()) * input.amountOfCustomMetadata) +
                totalPriorityFeeAmount
        );
    }
}
