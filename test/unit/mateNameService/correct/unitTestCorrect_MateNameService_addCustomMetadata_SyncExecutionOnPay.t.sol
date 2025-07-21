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

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/evvm/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/evvm/lib/EvvmMockStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestCorrect_MateNameService_addCustomMetadata_SyncExecutionOnPay is
    Test,
    Constants
{
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
        string memory username,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            mns.getPriceToAddCustomMetadata() + priorityFeeAmount
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
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                mns.getPriceToAddCustomMetadata(),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
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

    function test__unit_correct__addCustomMetadata__nS_nPF() external {
        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = mns.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("test>1").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes("test>1"))
        );

        assertEq(mns.getCustomMetadataMaxSlotsOfIdentity("test"), 1);

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

    function test__unit_correct__addCustomMetadata__nS_PF() external {
        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = mns.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("test>1").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes("test>1"))
        );

        assertEq(mns.getCustomMetadataMaxSlotsOfIdentity("test"), 1);

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

    function test__unit_correct__addCustomMetadata__S_nPF() external {
        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = mns.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("test>1").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes("test>1"))
        );

        assertEq(mns.getCustomMetadataMaxSlotsOfIdentity("test"), 1);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (5 * evvm.seeMateReward()) +
                ((mns.getPriceToAddCustomMetadata() * 50) / 100) +
                totalPriorityFeeAmount
        );
    }

    function test__unit_correct__addCustomMetadata__S_PF() external {
        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = mns.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("test>1").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes("test>1"))
        );

        assertEq(mns.getCustomMetadataMaxSlotsOfIdentity("test"), 1);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (5 * evvm.seeMateReward()) +
                ((mns.getPriceToAddCustomMetadata() * 50) / 100) +
                totalPriorityFeeAmount
        );
    }
}
