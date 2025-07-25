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

contract fuzzTest_NameService_makeOffer is Test, Constants {
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
        AccountData memory user,
        uint256 offerAmount,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 totalOfferAmount, uint256 totalPriorityFeeAmount)
    {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            offerAmount + priorityFeeAmount
        );

        totalOfferAmount = offerAmount;
        totalPriorityFeeAmount = priorityFeeAmount;

        makeRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101,
            20202
        );
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

    function makeMakeOfferSignatures(
        AccountData memory user,
        string memory usernameToMakeOffer,
        uint256 expireDate,
        uint256 amountToOffer,
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
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                usernameToMakeOffer,
                expireDate,
                amountToOffer,
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
                amountToOffer,
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
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct MakeOfferFuzzTestInput_nPF {
        uint8 nonceMNS;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 clowNumber;
        uint16 seed;
        uint128 daysForExpire;
        uint64 offerAmount;
        bool electionOne;
        bool electionTwo;
    }

    struct MakeOfferFuzzTestInput_PF {
        uint8 nonceMNS;
        uint8 nonceEVVM;
        uint32 priorityFeeAmountEVVM;
        bool priorityFlagEVVM;
        uint16 clowNumber;
        uint16 seed;
        uint128 daysForExpire;
        uint64 offerAmount;
        bool electionOne;
        bool electionTwo;
    }


    function test__unit_correct__makeOffer__nPF(
        MakeOfferFuzzTestInput_nPF memory input
    ) external {
        vm.assume(input.offerAmount > 0 && input.daysForExpire > 0);

        AccountData memory selectedUser = (input.electionOne)
            ? COMMON_USER_NO_STAKER_2
            : COMMON_USER_NO_STAKER_3;

        AccountData memory selectedFisher = (input.electionTwo)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_STAKER;

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(
            selectedUser,
            input.offerAmount,
            0
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                selectedUser,
                "test",
                block.timestamp + uint256(input.daysForExpire),
                input.offerAmount,
                input.nonceMNS,
                0,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(selectedFisher.Address);

        nameService.makeOffer(
            selectedUser.Address,
            input.nonceMNS,
            "test",
            input.offerAmount,
            block.timestamp + input.daysForExpire,
            0,
            signatureMNS,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, selectedUser.Address);
        assertEq(checkData.amount, ((uint256(input.offerAmount) * 995) / 1000));
        assertEq(checkData.expireDate, block.timestamp + uint256(input.daysForExpire));

        assertEq(evvm.getBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.getBalance(selectedFisher.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() + (uint256(input.offerAmount) * 125) / 100_000
        );
    }

    function test__unit_correct__makeOffer__PF(
        MakeOfferFuzzTestInput_PF memory input
    ) external {
        vm.assume(input.offerAmount > 0 && input.daysForExpire > 0);

        AccountData memory selectedUser = (input.electionOne)
            ? COMMON_USER_NO_STAKER_2
            : COMMON_USER_NO_STAKER_3;

        AccountData memory selectedFisher = (input.electionTwo)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_STAKER;

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(
            selectedUser,
            input.offerAmount,
            input.priorityFeeAmountEVVM
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                selectedUser,
                "test",
                block.timestamp + uint256(input.daysForExpire),
                input.offerAmount,
                input.nonceMNS,
                input.priorityFeeAmountEVVM,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(selectedFisher.Address);

        nameService.makeOffer(
            selectedUser.Address,
            input.nonceMNS,
            "test",
            input.offerAmount,
            block.timestamp + input.daysForExpire,
            input.priorityFeeAmountEVVM,
            signatureMNS,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, selectedUser.Address);
        assertEq(checkData.amount, ((uint256(input.offerAmount) * 995) / 1000));
        assertEq(checkData.expireDate, block.timestamp + uint256(input.daysForExpire));

        assertEq(evvm.getBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.getBalance(selectedFisher.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() + (uint256(input.offerAmount) * 125) / 100_000 + input.priorityFeeAmountEVVM
        );
    }
}
