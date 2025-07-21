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

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract fuzzTest_MateNameService_acceptOffer is Test, Constants {
    SMateMock sMate;
    Evvm evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
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
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(user.Address, MATE_TOKEN_ADDRESS, priorityFeeAmount);

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

    function makeOffer(
        AccountData memory user,
        string memory usernameToMakeOffer,
        uint256 expireDate,
        uint256 amountToOffer,
        uint256 nonceMNS,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    ) private {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        evvm._addBalance(user.Address, MATE_TOKEN_ADDRESS, amountToOffer);

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
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountToOffer,
                0,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        mns.makeOffer(
            user.Address,
            nonceMNS,
            usernameToMakeOffer,
            amountToOffer,
            expireDate,
            0,
            signatureMNS,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeAcceptOfferSignatures(
        AccountData memory user,
        bool givePriorityFee,
        string memory usernameToFindOffer,
        uint256 index,
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

        if (givePriorityFee) {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                    usernameToFindOffer,
                    index,
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
                    priorityFeeAmountEVVM,
                    0,
                    nonceEVVM,
                    priorityFlagEVVM,
                    address(mns)
                )
            );
            signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
        } else {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                    usernameToFindOffer,
                    index,
                    nonceMNS
                )
            );
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            signatureEVVM = "";
        }
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct AcceptOfferFuzzTestInput_nPF {
        uint16 amountToOffer;
        uint8 nonceMNS;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
    }

    struct AcceptOfferFuzzTestInput_PF {
        uint16 amountToOffer;
        uint8 nonceMNS;
        uint32 priorityFeeAmountEVVM;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
    }

    function test__fuzz__acceptOffer__nS_nPF(
        AcceptOfferFuzzTestInput_nPF memory input
    ) external {
        vm.assume(input.amountToOffer > 0);

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            input.amountToOffer,
            10001,
            101,
            true
        );

        (bytes memory signatureMNS, ) = makeAcceptOfferSignatures(
            COMMON_USER_NO_STAKER_1,
            false,
            "test",
            0,
            input.nonceMNS,
            0,
            nonceEvvm,
            input.priorityFlagEVVM
        );

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            0,
            0,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            ""
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_2.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkData.amount
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__acceptOffer__nS_PF(
        AcceptOfferFuzzTestInput_PF memory input
    ) external {
        vm.assume(input.amountToOffer > 0 && input.priorityFeeAmountEVVM > 0);

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.priorityFeeAmountEVVM
        );

        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            input.amountToOffer,
            10001,
            101,
            true
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                0,
                input.nonceMNS,
                input.priorityFeeAmountEVVM,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_2.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkData.amount
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__acceptOffer__S_nPF(
        AcceptOfferFuzzTestInput_nPF memory input
    ) external {
        vm.assume(input.amountToOffer > 0);

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            input.amountToOffer,
            10001,
            101,
            true
        );

        (bytes memory signatureMNS, ) = makeAcceptOfferSignatures(
            COMMON_USER_NO_STAKER_1,
            false,
            "test",
            0,
            input.nonceMNS,
            0,
            nonceEvvm,
            input.priorityFlagEVVM
        );

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        uint256 amountOfStakerBefore = evvm.seeBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            0,
            0,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            ""
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_2.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkData.amount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (evvm.seeMateReward()) +
                (((checkData.amount * 1) / 199) / 4) +
                amountOfStakerBefore
        );
    }

    function test__fuzz__acceptOffer__S_PF(
        AcceptOfferFuzzTestInput_PF memory input
    ) external {
        vm.assume(input.amountToOffer > 0 && input.priorityFeeAmountEVVM > 0);

        uint256 nonceEvvm = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.priorityFeeAmountEVVM
        );

        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            input.amountToOffer,
            10001,
            101,
            true
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                0,
                input.nonceMNS,
                input.priorityFeeAmountEVVM,
                nonceEvvm,
                input.priorityFlagEVVM
            );

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        uint256 amountOfStakerBefore = evvm.seeBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            input.nonceMNS,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            nonceEvvm,
            input.priorityFlagEVVM,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_2.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkData.amount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (evvm.seeMateReward()) +
                (((checkData.amount * 1) / 199) / 4) +
                input.priorityFeeAmountEVVM +
                amountOfStakerBefore
        );
    }
}
