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

contract unitTestCorrect_MateNameService_flushUsername_AsyncExecutionOnPay is
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

        makeAddCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            "test>1",
            11,
            11,
            true
        );
        makeAddCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            "test>2",
            22,
            22,
            true
        );
        makeAddCustomMetadata(
            COMMON_USER_NO_STAKER_1,
            "test",
            "test>3",
            33,
            33,
            true
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
            mns.getPriceToFlushUsername(usernameToFlushCustomMetadata) +
                priorityFeeAmount
        );

        totalAmountFlush = mns.getPriceToFlushUsername(
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

    function makeFlushUsernameSignatures(
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
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
                mns.getPriceToFlushUsername(username),
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

    function test__unit_correct__flushUsername__nS_nPF() external {
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                110010011,
                totalPriorityFeeAmount,
                1001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.flushUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            totalPriorityFeeAmount,
            110010011,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, uint256 expireDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, address(0));
        assertEq(expireDate, 0);

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
            ((5 * evvm.seeMateReward()) * amountOfSlotsBefore) +
                totalPriorityFeeAmount
        );
    }

        function test__unit_correct__flushUsername__nS_PF() external {
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                110010011,
                totalPriorityFeeAmount,
                1001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.flushUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            totalPriorityFeeAmount,
            110010011,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, uint256 expireDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, address(0));
        assertEq(expireDate, 0);

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
            ((5 * evvm.seeMateReward()) * amountOfSlotsBefore) +
                totalPriorityFeeAmount
        );
    }

    function test__unit_correct__flushUsername__S_nPF() external {
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                110010011,
                totalPriorityFeeAmount,
                1001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.flushUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            totalPriorityFeeAmount,
            110010011,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, uint256 expireDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, address(0));
        assertEq(expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            ),
            ((5 * evvm.seeMateReward()) * amountOfSlotsBefore) +
                totalPriorityFeeAmount
        );
    }

        function test__unit_correct__flushUsername__S_PF() external {
        (, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                110010011,
                totalPriorityFeeAmount,
                1001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.flushUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            totalPriorityFeeAmount,
            110010011,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, uint256 expireDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, address(0));
        assertEq(expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            ),
            ((5 * evvm.seeMateReward()) * amountOfSlotsBefore) +
                totalPriorityFeeAmount
        );
    }
}
