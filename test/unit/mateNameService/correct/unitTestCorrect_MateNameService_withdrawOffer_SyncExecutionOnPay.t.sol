// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

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

contract unitTestCorrect_MateNameService_withdrawOffer_SyncExecutionOnPay is
    Test,
    Constants
{
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
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            0.001 ether,
            10001,
            101,
            true
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

    function makeWithdrawOfferSignatures(
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
                Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
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
                Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                    usernameToFindOffer,
                    index,
                    nonceMNS
                )
            );
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

    function test__unit_correct__withdrawOffer__nS_nPF() external {
        (bytes memory signatureMNS, ) = makeWithdrawOfferSignatures(
            COMMON_USER_NO_STAKER_2,
            false,
            "test",
            0,
            100010001,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
            false
        );

        MateNameServiceMock.OfferMetadata memory checkDataBefore = mns
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        mns.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            0,
            0,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
            false,
            ""
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkDataAfter = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, address(0));
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkDataBefore.amount
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            evvm.seeMateReward() + (((checkDataBefore.amount * 1) / 796))
        );
    }

    function test__unit_correct__withdrawOffer__nS_PF() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeWithdrawOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                0,
                100010001,
                totalPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
                false
            );

        MateNameServiceMock.OfferMetadata memory checkDataBefore = mns
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        mns.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            0,
            totalPriorityFee,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkDataAfter = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, address(0));
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkDataBefore.amount
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            evvm.seeMateReward() +
                (((checkDataBefore.amount * 1) / 796)) +
                totalPriorityFee
        );
    }

    function test__unit_correct__withdrawOffer__S_nPF() external {
        (bytes memory signatureMNS, ) = makeWithdrawOfferSignatures(
            COMMON_USER_NO_STAKER_2,
            false,
            "test",
            0,
            100010001,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
            false
        );

        MateNameServiceMock.OfferMetadata memory checkDataBefore = mns
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            0,
            0,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
            false,
            ""
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkDataAfter = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, address(0));
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkDataBefore.amount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() + (((checkDataBefore.amount * 1) / 796))
        );
    }

    function test__unit_correct__withdrawOffer__S_PF() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeWithdrawOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                0,
                100010001,
                totalPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
                false
            );

        MateNameServiceMock.OfferMetadata memory checkDataBefore = mns
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            0,
            totalPriorityFee,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_2.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkDataAfter = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, address(0));
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            checkDataBefore.amount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                (((checkDataBefore.amount * 1) / 796)) +
                totalPriorityFee
        );
    }
}
