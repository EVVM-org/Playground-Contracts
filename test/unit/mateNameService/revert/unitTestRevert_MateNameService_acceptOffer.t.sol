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

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";
import {AdvancedStrings} from "@RollAMate/libraries/AdvancedStrings.sol";

contract unitTestRevert_MateNameService_acceptOffer is Test, Constants {
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
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*
    function test__unit_revert__acceptOffer__bPaySigAt() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    /////////////////////////////////////////////////////////////////////////////

    function test__unit_revert__acceptOffer__() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                0,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

   function test__unit_revert__acceptOffer__bSigAtSigner() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bSigAtUsername() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "user",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bSigAtOfferID() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                1,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bSigAtNonceMNS() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
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
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtSigner() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtToAddress() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtToIdentity() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "matenameservice",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtTokenAddress() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                ETHER_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtAmount() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                0,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtPriorityFee() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                1,
                1001,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtNonceEVVM() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                777,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtPriorityFlag() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                false,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtExecutor() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__userIsNotOwner() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                0,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__nonceMnsAlreadyUsed() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                0,
                10101,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            0,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__offerExpired() external {
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 5 days,
            0.001 ether,
            777,
            777,
            true
        );

        skip(10 days);

        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                1,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            1,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__offerOutOfBounds() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                1,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        mns.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            1,
            amountPriorityFee,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
