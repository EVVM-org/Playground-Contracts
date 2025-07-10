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

contract fuzzTest_MateNameService_registrationUsername is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

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
    }

    function addBalance(
        address user,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 registrationPrice, uint256 totalPriorityFeeAmount)
    {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            mns.getPricePerRegistration() + priorityFeeAmount
        );

        registrationPrice = mns.getPricePerRegistration();
        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makePreRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNS
    ) private {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceMNS
            )
        );

        mns.preRegistrationUsername(
            user.Address,
            nonceMNS,
            keccak256(abi.encodePacked(username, uint256(clowNumber))),
            0,
            Erc191TestBuilder.buildERC191Signature(v, r, s),
            0,
            false,
            hex""
        );
    }

    function makeRegistrationUsernameSignatures(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
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
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                username,
                clowNumber,
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
                mns.getPricePerRegistration(),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
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

    struct RegistrationUsernameFuzzTestInput_nPF {
        uint8 nonceMNS;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 clowNumber;
        uint16 seed;
    }

    struct RegistrationUsernameFuzzTestInput_PF {
        uint8 nonceMNS;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 priorityFeeAmount;
        uint16 clowNumber;
        uint16 seed;
    }

    function test__fuzz__registrationUsername__nS_nPF(
        RegistrationUsernameFuzzTestInput_nPF memory input
    ) external {
        vm.assume((input.seed / 2) >= 4 && input.nonceMNS != 10);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, 0);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceMNS,
                0,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);
        mns.registrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            username,
            input.clowNumber,
            signatureMNS,
            0,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            username
        );

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.seeBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__registrationUsername__nS_PF(
        RegistrationUsernameFuzzTestInput_PF memory input
    ) external {
        vm.assume((input.seed / 2) >= 4 && input.nonceMNS != 10);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, input.priorityFeeAmount);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceMNS,
                input.priorityFeeAmount,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);
        mns.registrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            username,
            input.clowNumber,
            signatureMNS,
            input.priorityFeeAmount,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            username
        );

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.seeBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__registrationUsername__S_nPF(
        RegistrationUsernameFuzzTestInput_nPF memory input
    ) external {
        vm.assume((input.seed / 2) >= 4 && input.nonceMNS != 10);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, 0);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceMNS,
                0,
                nonce,
                input.priorityFlagEVVM
            );

        uint256 balanceStakerBefore = evvm.seeBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        mns.registrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            username,
            input.clowNumber,
            signatureMNS,
            0,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            username
        );

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.seeBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (evvm.seeMateReward() * 50) + balanceStakerBefore
        );
    }

    function test__fuzz__registrationUsername__S_PF(
        RegistrationUsernameFuzzTestInput_PF memory input
    ) external {
        vm.assume((input.seed / 2) >= 4 && input.nonceMNS != 10);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, input.priorityFeeAmount);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceMNS,
                input.priorityFeeAmount,
                nonce,
                input.priorityFlagEVVM
            );

        uint256 balanceStakerBefore = evvm.seeBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        mns.registrationUsername(
            selectedUser.Address,
            input.nonceMNS,
            username,
            input.clowNumber,
            signatureMNS,
            input.priorityFeeAmount,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            username
        );

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.seeBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (evvm.seeMateReward() * 50) +
                balanceStakerBefore +
                input.priorityFeeAmount
        );
    }
}
