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

contract unitTestRevert_MateNameService_flushCustomMetadata is Test, Constants {
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
            mns.getPriceToFlushCustomMetadata(usernameToFlushCustomMetadata) +
                priorityFeeAmount
        );

        totalAmountFlush = mns.getPriceToFlushCustomMetadata(
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

    function makeFlushCustomMetadataSignatures(
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
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
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
                mns.getPriceToFlushCustomMetadata(username),
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
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*

    function test__unit_correct__flushCustomMetadata__bSigAt() external {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    //////////////////////////////////////////////////////////////////

    function test__unit_correct__flushCustomMetadata__() external {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                100010001,
                totalPriorityFeeAmount,
                1000001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    */

    function test__unit_correct__flushCustomMetadata__bSigAtSigner() external {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bSigAtUsername()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "user",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bSigAtNonceMNS()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                777
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtSigner()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtToAddress()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtToIdentity()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "matenameservice",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtTokenAddress()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                ETHER_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtAmount()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                7,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtPriorityFee()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                7,
                1000001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtNonceEVVM()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                777,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtPriorityFlag()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                false,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__bPaySigAtExecutor()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForFlushCustomMetadata(
                "test",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1000001,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__userIsNotOwner()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                100010001,
                totalPriorityFeeAmount,
                1000001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__nonceAlreadyUsed()
        external
    {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                11,
                totalPriorityFeeAmount,
                1000001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            11,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__usernameHasNotCustomMetadata()
        external
    {
        mns._setIdentityBaseMetadata(
            "user",
            MateNameServiceMock.IdentityBaseMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                block.timestamp + 366 days,
                0,
                0,
                0x00
            )
        );

        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "user",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "user",
                100010001,
                totalPriorityFeeAmount,
                1000001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "user",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushCustomMetadata__userHasNotAmount()
        external
    {
        uint256 totalAmountFlush = 0;
        uint256 totalPriorityFeeAmount = 0;

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                100010001,
                totalPriorityFeeAmount,
                1000001,
                true
            );

        uint256 amountOfSlotsBefore = mns.getAmountOfCustomMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            1000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(mns.getAmountOfCustomMetadata("test"), amountOfSlotsBefore);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
