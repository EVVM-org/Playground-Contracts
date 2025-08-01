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

import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

contract fuzzTest_NameService_flushCustomMetadata is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
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
        evvm._setupNameServiceAddress(address(nameService));

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
            nameService.getPriceToFlushCustomMetadata(
                usernameToFlushCustomMetadata
            ) + priorityFeeAmount
        );

        totalAmountFlush = nameService.getPriceToFlushCustomMetadata(
            usernameToFlushCustomMetadata
        );
        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makeRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceNameServicePre,
        uint256 nonceNameService
    ) private {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPricePerRegistration()
        );

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceNameServicePre
            )
        );

        nameService.preRegistrationUsername(
            user.Address,
            nonceNameServicePre,
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
                nonceNameService
            )
        );
        bytes memory signatureNameService = Erc191TestBuilder
            .buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                address(nameService)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        nameService.registrationUsername(
            user.Address,
            nonceNameService,
            username,
            clowNumber,
            signatureNameService,
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
        uint256 nonceNameService,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    ) private {
        uint8 v;
        bytes32 r;
        bytes32 s;

        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToAddCustomMetadata()
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                username,
                customMetadata,
                nonceNameService
            )
        );
        bytes memory signatureNameService = Erc191TestBuilder
            .buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                0,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        nameService.addCustomMetadata(
            user.Address,
            nonceNameService,
            username,
            customMetadata,
            0,
            signatureNameService,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeFlushCustomMetadataSignatures(
        AccountData memory user,
        string memory username,
        uint256 nonceNameService,
        uint256 priorityFeeAmountEVVM,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    )
        private
        view
        returns (bytes memory signatureNameService, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                username,
                nonceNameService
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToFlushCustomMetadata(username),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
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
        uint32 nonceNameService;
        uint32 nonceEVVM;
        bool priorityFlagEVVM;
    }

    struct FlushCustomMetadataFuzzTestInput_PF {
        uint8 amountOfCustomMetadata;
        uint32 nonceNameService;
        uint32 nonceEVVM;
        uint16 priorityFeeAmountEVVM;
        bool priorityFlagEVVM;
    }

    function test__fuzz__flushCustomMetadata__nS_nPF(
        FlushCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        vm.assume(
            input.nonceNameService > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceNameService != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceNameService != 20202 &&
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceNameService,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        nameService.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(nameService.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
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
            input.nonceNameService > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceNameService != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceNameService != 20202 &&
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceNameService,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        nameService.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(nameService.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
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
            input.nonceNameService > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceNameService != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceNameService != 20202 &&
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceNameService,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(nameService.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            ((5 * evvm.getRewardAmount()) * input.amountOfCustomMetadata) +
                totalPriorityFeeAmount
        );
    }

    function test__fuzz__flushCustomMetadata__S_PF(
        FlushCustomMetadataFuzzTestInput_PF memory input
    ) external {
        vm.assume(
            input.nonceNameService > uint256(input.amountOfCustomMetadata) &&
                input.nonceEVVM > uint256(input.amountOfCustomMetadata) &&
                input.nonceNameService != 10101 &&
                input.nonceEVVM != 10101 &&
                input.nonceNameService != 20202 &&
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.nonceNameService,
                totalPriorityFeeAmount,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(nameService.getAmountOfCustomMetadata("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            ((5 * evvm.getRewardAmount()) * input.amountOfCustomMetadata) +
                totalPriorityFeeAmount
        );
    }
}
