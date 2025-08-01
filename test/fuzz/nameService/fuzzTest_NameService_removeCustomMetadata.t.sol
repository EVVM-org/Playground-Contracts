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

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

contract fuzzTest_NameService_removeCustomMetadata is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    uint256 constant MAX_AMOUNT_SLOTS_REGISTERED = uint256(type(uint8).max) + 1;

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

        for (uint256 i = 0; i < MAX_AMOUNT_SLOTS_REGISTERED; i++) {
            makeAddCustomMetadata(
                COMMON_USER_NO_STAKER_1,
                "test",
                string.concat("test>", Strings.toString(i)),
                uint256(type(uint32).max) + 1 + i,
                uint256(type(uint32).max) + 1 + i,
                true
            );
        }
    }

    function addBalance(
        AccountData memory user,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToRemoveCustomMetadata() + priorityFeeAmount
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

    function makeRemoveCustomMetadataSignatures(
        AccountData memory user,
        string memory username,
        uint256 indexCustomMetadata,
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
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                username,
                indexCustomMetadata,
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
                nameService.getPriceToRemoveCustomMetadata(),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct RemoveCustomMetadataFuzzTestInput_nPF {
        uint8 indexToRemove;
        uint32 nonceNameService;
        uint32 nonceEVVM;
        bool priorityFlagEVVM;
    }

    struct RemoveCustomMetadataFuzzTestInput_PF {
        uint8 indexToRemove;
        uint32 nonceNameService;
        uint32 nonceEVVM;
        uint16 priorityFeeAmountEVVM;
        bool priorityFlagEVVM;
    }

    function test__fuzz__removeCustomMetadata__nS_nPF(
        RemoveCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        vm.assume(
            input.nonceNameService > uint256(type(uint8).max) &&
                input.nonceEVVM > uint256(type(uint8).max)
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        uint256 priorityFeeAmountEVVM = addBalance(COMMON_USER_NO_STAKER_1, 0);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.indexToRemove,
                input.nonceNameService,
                priorityFeeAmountEVVM,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            input.indexToRemove,
            priorityFeeAmountEVVM,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService
            .getSingleCustomMetadataOfIdentity("test", input.indexToRemove);

        console2.log("customMetadata: ", customMetadata);

        if (input.indexToRemove != type(uint8).max) {
            assertEq(
                bytes(customMetadata).length,
                bytes(
                    string.concat(
                        "test>",
                        Strings.toString(input.indexToRemove + 1)
                    )
                ).length
            );
            assertEq(
                keccak256(bytes(customMetadata)),
                keccak256(
                    bytes(
                        string.concat(
                            "test>",
                            Strings.toString(input.indexToRemove + 1)
                        )
                    )
                )
            );
        } else {
            assertEq(bytes(customMetadata).length, bytes("").length);
            assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("")));
        }

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

        assertEq(
            nameService.getCustomMetadataMaxSlotsOfIdentity("test"),
            MAX_AMOUNT_SLOTS_REGISTERED - 1
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

    function test__fuzz__removeCustomMetadata__nS_PF(
        RemoveCustomMetadataFuzzTestInput_PF memory input
    ) external {
        vm.assume(
            input.nonceNameService > uint256(type(uint8).max) &&
                input.nonceEVVM > uint256(type(uint8).max)
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        uint256 priorityFeeAmountEVVM = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.priorityFeeAmountEVVM
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.indexToRemove,
                input.nonceNameService,
                priorityFeeAmountEVVM,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            input.indexToRemove,
            priorityFeeAmountEVVM,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService
            .getSingleCustomMetadataOfIdentity("test", input.indexToRemove);

        console2.log("customMetadata: ", customMetadata);

        if (input.indexToRemove != type(uint8).max) {
            assertEq(
                bytes(customMetadata).length,
                bytes(
                    string.concat(
                        "test>",
                        Strings.toString(input.indexToRemove + 1)
                    )
                ).length
            );
            assertEq(
                keccak256(bytes(customMetadata)),
                keccak256(
                    bytes(
                        string.concat(
                            "test>",
                            Strings.toString(input.indexToRemove + 1)
                        )
                    )
                )
            );
        } else {
            assertEq(bytes(customMetadata).length, bytes("").length);
            assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("")));
        }

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

        assertEq(
            nameService.getCustomMetadataMaxSlotsOfIdentity("test"),
            MAX_AMOUNT_SLOTS_REGISTERED - 1
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

    function test__fuzz__removeCustomMetadata__S_nPF(
        RemoveCustomMetadataFuzzTestInput_nPF memory input
    ) external {
        vm.assume(
            input.nonceNameService > uint256(type(uint8).max) &&
                input.nonceEVVM > uint256(type(uint8).max)
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        uint256 priorityFeeAmountEVVM = addBalance(COMMON_USER_NO_STAKER_1, 0);

        string memory customMetadata = nameService
            .getSingleCustomMetadataOfIdentity("test", input.indexToRemove);

        console2.log("customMetadata: ", customMetadata);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.indexToRemove,
                input.nonceNameService,
                priorityFeeAmountEVVM,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            input.indexToRemove,
            priorityFeeAmountEVVM,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            input.indexToRemove
        );

        console2.log("customMetadata: ", customMetadata);

        if (input.indexToRemove != type(uint8).max) {
            assertEq(
                bytes(customMetadata).length,
                bytes(
                    string.concat(
                        "test>",
                        Strings.toString(input.indexToRemove + 1)
                    )
                ).length
            );
            assertEq(
                keccak256(bytes(customMetadata)),
                keccak256(
                    bytes(
                        string.concat(
                            "test>",
                            Strings.toString(input.indexToRemove + 1)
                        )
                    )
                )
            );
        } else {
            assertEq(bytes(customMetadata).length, bytes("").length);
            assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("")));
        }

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

        assertEq(
            nameService.getCustomMetadataMaxSlotsOfIdentity("test"),
            MAX_AMOUNT_SLOTS_REGISTERED - 1
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
            (5 * evvm.getRewardAmount()) + priorityFeeAmountEVVM
        );
    }

    function test__fuzz__removeCustomMetadata__S_PF(
        RemoveCustomMetadataFuzzTestInput_PF memory input
    ) external {
        vm.assume(
            input.nonceNameService > uint256(type(uint8).max) &&
                input.nonceEVVM > uint256(type(uint8).max)
        );

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        uint256 priorityFeeAmountEVVM = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.priorityFeeAmountEVVM
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                input.indexToRemove,
                input.nonceNameService,
                priorityFeeAmountEVVM,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceNameService,
            "test",
            input.indexToRemove,
            priorityFeeAmountEVVM,
            signatureNameService,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService
            .getSingleCustomMetadataOfIdentity("test", input.indexToRemove);

        console2.log("customMetadata: ", customMetadata);

        if (input.indexToRemove != type(uint8).max) {
            assertEq(
                bytes(customMetadata).length,
                bytes(
                    string.concat(
                        "test>",
                        Strings.toString(input.indexToRemove + 1)
                    )
                ).length
            );
            assertEq(
                keccak256(bytes(customMetadata)),
                keccak256(
                    bytes(
                        string.concat(
                            "test>",
                            Strings.toString(input.indexToRemove + 1)
                        )
                    )
                )
            );
        } else {
            assertEq(bytes(customMetadata).length, bytes("").length);
            assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("")));
        }

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

        assertEq(
            nameService.getCustomMetadataMaxSlotsOfIdentity("test"),
            MAX_AMOUNT_SLOTS_REGISTERED - 1
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
            (5 * evvm.getRewardAmount()) + priorityFeeAmountEVVM
        );
    }
}
