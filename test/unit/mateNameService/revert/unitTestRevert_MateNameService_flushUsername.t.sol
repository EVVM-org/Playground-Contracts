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

import {SMate} from "@EVVM/playground/staking/SMate.sol";
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestRevert_MateNameService_flushUsername is Test, Constants {
    SMate sMate;
    Evvm evvm;
    Estimator estimator;
    Mns mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMate(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new Mns(address(evvm), ADMIN.Address);

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
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*
    function test__unit_correct__flushUsername__bSigAt() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    ////////////////////////////////////////////////////////////////////////////

    function test__unit_correct__flushUsername__() external {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
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

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_correct__flushUsername__bSigAtSigner() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bSigAtUsername() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "user",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bSigAtNonceMNS() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername("test", 777)
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtSigner() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtToAddress() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtToIdentity() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "matenameservices",
                MATE_TOKEN_ADDRESS,
                totalAmountFlush,
                totalPriorityFeeAmount,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtTokenAddress()
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtAmount() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtPriorityFee()
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtNonceEVVM() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                7,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtPriorityFlag()
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                false,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__bPaySigAtExecutor() external {
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                "test",
                110010011
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
                1001,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__nonceAlreadyUsed() external {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
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
                11,
                totalPriorityFeeAmount,
                1001,
                true
            );

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            totalPriorityFeeAmount,
            11,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, uint256 expireDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__userIsNotOwner() external {
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            "test",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushUsernameSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                110010011,
                totalPriorityFeeAmount,
                1001,
                true
            );

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushUsername(
            COMMON_USER_NO_STAKER_2.Address,
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__userTryToFlushAfterExpire()
        external
    {
        skip(400 days);

        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
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

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__identityIsNotAUsername() external {
        mns._setIdentityBaseMetadata(
            "test@mail.com",
            Mns.IdentityBaseMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                block.timestamp + 366 days,
                0,
                0,
                0x01
            )
        );
        (uint256 totalAmountFlush, uint256 totalPriorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test@mail.com",
            0.0001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeFlushUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test@mail.com",
                110010011,
                totalPriorityFeeAmount,
                1001,
                true
            );

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test@mail.com");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.flushUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test@mail.com",
            totalPriorityFeeAmount,
            110010011,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, uint256 expireDate) = mns.getIdentityBasicMetadata(
            "test@mail.com"
        );

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_correct__flushUsername__userHasNotEnoughBalance() external {
        uint256 totalAmountFlush=0; uint256 totalPriorityFeeAmount=0;

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

        (address userBefore, uint256 expireDateBefore) = mns
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
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

        assertEq(user, userBefore);
        assertEq(expireDate, expireDateBefore);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalAmountFlush + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
