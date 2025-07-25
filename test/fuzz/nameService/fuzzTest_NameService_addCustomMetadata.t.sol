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
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract fuzzTest_NameService_addCustomMetadata is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(staking));
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

        makeRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 11, 22);
    }

    function addBalance(
        AccountData memory user,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToAddCustomMetadata() + priorityFeeAmount
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
            nameService.getPricePerRegistration()
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

        nameService.preRegistrationUsername(
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

    function makeAddCustomMetadataSignatures(
        AccountData memory user,
        string memory username,
        string memory customMetadata,
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
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                username,
                customMetadata,
                nonceMNS
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function getARandomCustomMetadata(
        uint256 seed
    ) internal view returns (string memory customMetadata) {
        for (uint i = 0; i < 10; i++) {
            customMetadata = string(
                abi.encodePacked(
                    customMetadata,
                    Strings.toString(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    customMetadata,
                                    seed,
                                    block.timestamp
                                )
                            )
                        ) % 10
                    )
                )
            );
        }
    }

    /**
     * Naming Convention for Fuzz Test Functions
     * Basic Structure:
     * test__[typeOfTest]__[functionName]__[options]
     * General Rules:
     *  - Always start with "test__"
     *  - The name of the function to be executed must immediately follow "test__"
     *  - Options are added at the end, separated by underscores
     *
     * Options for Payment Functions:
     * Add these options at the end of the name, in the following order:
     *  a) Priority Fee:
     *      PF: Includes priority fee
     *      nPF: No priority fee
     *  b) Executor:
     *      EX: Includes executor execution
     *      nEX: Does not include executor execution
     *  d) Identity:
     *     ID: Uses a MNS identity
     *     AD: Uses an address
     *
     * Example:
     * test__payNoMateStaking_sync__PF_nEX
     *
     * Example explanation:
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nEX: Does not include executor execution
     *
     * Notes:
     * Separate different parts of the name with double underscores (__)
     */

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct AddCustomMetadataFuzzTestInput_nPF {
        uint16 nonceMNS;
        uint16 nonceEVVM;
        uint16 seed;
        bool priorityFlagEVVM;
    }

    struct AddCustomMetadataFuzzTestInput_PF {
        uint16 nonceMNS;
        uint16 nonceEVVM;
        uint16 seed;
        uint16 priorityFee;
        bool priorityFlagEVVM;
    }

    function test__fuzz__addCustomMetadata__nS_nPF(
        AddCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        input.nonceMNS = uint16(
            bound(input.nonceMNS, 1000, type(uint16).max - 10)
        );
        input.nonceEVVM = uint16(
            bound(input.nonceEVVM, 1000, type(uint16).max - 10)
        );

        vm.assume(input.nonceMNS != input.nonceEVVM);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 nonce;
        string memory customMetadata;

        for (uint i = 0; i < 4; i++) {
            addBalance(COMMON_USER_NO_STAKER_1, 0);
            customMetadata = getARandomCustomMetadata(input.seed + i);

            nonce = input.priorityFlagEVVM
                ? input.nonceEVVM + i
                : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

            (signatureMNS, signatureEVVM) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                customMetadata,
                input.nonceMNS + i,
                0,
                nonce,
                input.priorityFlagEVVM
            );

            vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
            nameService.addCustomMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                input.nonceMNS + i,
                "test",
                customMetadata,
                0,
                signatureMNS,
                nonce,
                input.priorityFlagEVVM,
                signatureEVVM
            );
            vm.stopPrank();

            assertEq(
                bytes(nameService.getSingleCustomMetadataOfIdentity("test", i)).length,
                bytes(customMetadata).length
            );

            assertEq(
                keccak256(
                    bytes(nameService.getSingleCustomMetadataOfIdentity("test", i))
                ),
                keccak256(bytes(customMetadata))
            );

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
    }

    function test__fuzz__addCustomMetadata__nS_PF(
        AddCustomMetadataFuzzTestInput_PF memory input
    ) external {
        input.nonceMNS = uint16(
            bound(input.nonceMNS, 1000, type(uint16).max - 10)
        );
        input.nonceEVVM = uint16(
            bound(input.nonceEVVM, 1000, type(uint16).max - 10)
        );

        vm.assume(input.nonceMNS != input.nonceEVVM);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 nonce;
        string memory customMetadata;

        for (uint i = 0; i < 4; i++) {
            addBalance(COMMON_USER_NO_STAKER_1, input.priorityFee);
            customMetadata = getARandomCustomMetadata(input.seed + i);

            nonce = input.priorityFlagEVVM
                ? input.nonceEVVM + i
                : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

            (signatureMNS, signatureEVVM) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                customMetadata,
                input.nonceMNS + i,
                input.priorityFee,
                nonce,
                input.priorityFlagEVVM
            );

            vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
            nameService.addCustomMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                input.nonceMNS + i,
                "test",
                customMetadata,
                input.priorityFee,
                signatureMNS,
                nonce,
                input.priorityFlagEVVM,
                signatureEVVM
            );
            vm.stopPrank();

            assertEq(
                bytes(nameService.getSingleCustomMetadataOfIdentity("test", i)).length,
                bytes(customMetadata).length
            );

            assertEq(
                keccak256(
                    bytes(nameService.getSingleCustomMetadataOfIdentity("test", i))
                ),
                keccak256(bytes(customMetadata))
            );

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
    }

    function test__fuzz__addCustomMetadata__S_nPF(
        AddCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        input.nonceMNS = uint16(
            bound(input.nonceMNS, 1000, type(uint16).max - 10)
        );
        input.nonceEVVM = uint16(
            bound(input.nonceEVVM, 1000, type(uint16).max - 10)
        );

        vm.assume(input.nonceMNS != input.nonceEVVM);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 nonce;
        string memory customMetadata;

        uint256 amountBeforeExecution;

        for (uint i = 0; i < 4; i++) {
            addBalance(COMMON_USER_NO_STAKER_1, 0);
            customMetadata = getARandomCustomMetadata(input.seed + i);

            nonce = input.priorityFlagEVVM
                ? input.nonceEVVM + i
                : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

            (signatureMNS, signatureEVVM) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                customMetadata,
                input.nonceMNS + i,
                0,
                nonce,
                input.priorityFlagEVVM
            );

            amountBeforeExecution = evvm.getBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            );
            vm.startPrank(COMMON_USER_STAKER.Address);
            nameService.addCustomMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                input.nonceMNS + i,
                "test",
                customMetadata,
                0,
                signatureMNS,
                nonce,
                input.priorityFlagEVVM,
                signatureEVVM
            );
            vm.stopPrank();

            assertEq(
                bytes(nameService.getSingleCustomMetadataOfIdentity("test", i)).length,
                bytes(customMetadata).length
            );

            assertEq(
                keccak256(
                    bytes(nameService.getSingleCustomMetadataOfIdentity("test", i))
                ),
                keccak256(bytes(customMetadata))
            );

            assertEq(
                evvm.getBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                0
            );
            assertEq(
                evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
                amountBeforeExecution +
                    ((5 * evvm.getRewardAmount()) +
                        ((nameService.getPriceToAddCustomMetadata() * 50) / 100))
            );
        }
    }

    function test__fuzz__addCustomMetadata__S_PF(
        AddCustomMetadataFuzzTestInput_PF memory input
    ) external {
        input.nonceMNS = uint16(
            bound(input.nonceMNS, 1000, type(uint16).max - 10)
        );
        input.nonceEVVM = uint16(
            bound(input.nonceEVVM, 1000, type(uint16).max - 10)
        );

        vm.assume(input.nonceMNS != input.nonceEVVM);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 nonce;
        string memory customMetadata;

        uint256 amountBeforeExecution;

        for (uint i = 0; i < 4; i++) {
            addBalance(COMMON_USER_NO_STAKER_1, input.priorityFee);
            customMetadata = getARandomCustomMetadata(input.seed + i);

            nonce = input.priorityFlagEVVM
                ? input.nonceEVVM + i
                : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

            (signatureMNS, signatureEVVM) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                customMetadata,
                input.nonceMNS + i,
                input.priorityFee,
                nonce,
                input.priorityFlagEVVM
            );

            amountBeforeExecution = evvm.getBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            );
            vm.startPrank(COMMON_USER_STAKER.Address);
            nameService.addCustomMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                input.nonceMNS + i,
                "test",
                customMetadata,
                input.priorityFee,
                signatureMNS,
                nonce,
                input.priorityFlagEVVM,
                signatureEVVM
            );
            vm.stopPrank();

            assertEq(
                bytes(nameService.getSingleCustomMetadataOfIdentity("test", i)).length,
                bytes(customMetadata).length
            );

            assertEq(
                keccak256(
                    bytes(nameService.getSingleCustomMetadataOfIdentity("test", i))
                ),
                keccak256(bytes(customMetadata))
            );

            assertEq(
                evvm.getBalance(
                    COMMON_USER_NO_STAKER_1.Address,
                    MATE_TOKEN_ADDRESS
                ),
                0
            );
            assertEq(
                evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
                amountBeforeExecution +
                    ((5 * evvm.getRewardAmount()) +
                        ((nameService.getPriceToAddCustomMetadata() * 50) / 100) +
                        input.priorityFee)
            );
        }
    }
}
