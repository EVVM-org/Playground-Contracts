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

contract fuzzTest_NameService_preRegistrationUsername is Test, Constants {
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
    }

    function addBalance(
        address user,
        address token,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(user, token, priorityFeeAmount);

        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makePreRegistrationUsernameSignature(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNS,
        bool givePriorityFee,
        uint256 priorityFeeAmount,
        uint256 nonceEVVM,
        bool priorityEVVM
    )
        private
        view
        returns (bytes memory signatureMNS, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (givePriorityFee) {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                    keccak256(abi.encodePacked(username, uint256(clowNumber))),
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
                    priorityFeeAmount,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(nameService)
                )
            );
            signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
        } else {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                    keccak256(abi.encodePacked(username, uint256(clowNumber))),
                    nonceMNS
                )
            );
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            signatureEVVM = "";
        }
    }

    function makeUsername(
        uint16 seed
    ) private pure returns (string memory username) {
        /// creas un nombre de usuario aleatorio de seed/2 caracteres
        /// este debe ser de la A-Z y a-z
        bytes memory usernameBytes = new bytes(seed / 2);
        for (uint256 i = 0; i < seed / 2; i++) {
            uint256 random = uint256(keccak256(abi.encodePacked(seed, i))) % 52;
            if (random < 26) {
                usernameBytes[i] = bytes1(uint8(random + 65));
            } else {
                usernameBytes[i] = bytes1(uint8(random + 71));
            }
        }
        username = string(usernameBytes);
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct PreRegistrationUsernameFuzzTestInput_nPF {
        uint8 nonceMNS;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 clowNumber;
        uint16 seed;
    }

    struct PreRegistrationUsernameFuzzTestInput_PF {
        uint8 nonceMNS;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 priorityFeeAmount;
        uint16 clowNumber;
        uint16 seed;
    }

    function test__fuzz__preRegistrationUsername__nS_nPF(
        PreRegistrationUsernameFuzzTestInput_nPF memory input
    ) external {
        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;

        vm.assume((input.seed / 2) >= 4);
        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        (bytes memory signatureMNS, ) = makePreRegistrationUsernameSignature(
            selectedUser,
            username,
            input.clowNumber,
            input.nonceMNS,
            false,
            0,
            nonce,
            input.priorityFlagEVVM
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        nameService.preRegistrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            keccak256(abi.encodePacked(username, uint256(input.clowNumber))),
            0,
            signatureMNS,
            nonce,
            input.priorityFlagEVVM,
            hex""
        );

        vm.stopPrank();

        (address ownerAddress, ) = nameService.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(
                        abi.encodePacked(username, uint256(input.clowNumber))
                    )
                )
            )
        );

        assertEq(ownerAddress, selectedUser.Address);

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

    function test__fuzz__preRegistrationUsername__nS_PF(
        PreRegistrationUsernameFuzzTestInput_PF memory input
    ) external {
        vm.assume((input.seed / 2) >= 4);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;

        addBalance(
            selectedUser.Address,
            MATE_TOKEN_ADDRESS,
            input.priorityFeeAmount
        );

        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makePreRegistrationUsernameSignature(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceMNS,
                true,
                input.priorityFeeAmount,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        nameService.preRegistrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            keccak256(abi.encodePacked(username, uint256(input.clowNumber))),
            input.priorityFeeAmount,
            signatureMNS,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        (address ownerAddress, ) = nameService.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(
                        abi.encodePacked(username, uint256(input.clowNumber))
                    )
                )
            )
        );

        assertEq(ownerAddress, selectedUser.Address);

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

    function test__fuzz__preRegistrationUsername__S_nPF(
        PreRegistrationUsernameFuzzTestInput_nPF memory input
    ) external {
        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;

        vm.assume((input.seed / 2) >= 4);
        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        (bytes memory signatureMNS, ) = makePreRegistrationUsernameSignature(
            selectedUser,
            username,
            input.clowNumber,
            input.nonceMNS,
            false,
            0,
            nonce,
            input.priorityFlagEVVM
        );

        uint256 balanceStakerBefore = evvm.getBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.preRegistrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            keccak256(abi.encodePacked(username, uint256(input.clowNumber))),
            0,
            signatureMNS,
            nonce,
            input.priorityFlagEVVM,
            hex""
        );

        vm.stopPrank();

        (address ownerAddress, ) = nameService.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(
                        abi.encodePacked(username, uint256(input.clowNumber))
                    )
                )
            )
        );

        assertEq(ownerAddress, selectedUser.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() + balanceStakerBefore
        );
    }

    function test__fuzz__preRegistrationUsername__S_PF(
        PreRegistrationUsernameFuzzTestInput_PF memory input
    ) external {
        vm.assume((input.seed / 2) >= 4);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;

        addBalance(
            selectedUser.Address,
            MATE_TOKEN_ADDRESS,
            input.priorityFeeAmount
        );

        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makePreRegistrationUsernameSignature(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceMNS,
                true,
                input.priorityFeeAmount,
                nonce,
                input.priorityFlagEVVM
            );

        uint256 balanceStakerBefore = evvm.getBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.preRegistrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            keccak256(abi.encodePacked(username, uint256(input.clowNumber))),
            input.priorityFeeAmount,
            signatureMNS,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        (address ownerAddress, ) = nameService.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(
                        abi.encodePacked(username, uint256(input.clowNumber))
                    )
                )
            )
        );

        assertEq(ownerAddress, selectedUser.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() + balanceStakerBefore + input.priorityFeeAmount
        );
    }
}
