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

import {SMateMock} from "@EVVM/Playground/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/Playground/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/Playground/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/Playground/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/Playground/EvvmMockStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestRevert_MateNameService_makeOffer is Test, Constants {
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
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountToOffer,
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

    function test__unit_revert__makeOffer__bPaySigAt() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
             totalOfferAmount +  priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }


    ////////////////////////////////////////////////////
    function test__unit_revert__makeOffer__bPaySigAt() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();
        
        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
             totalOfferAmount +  priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    */

    function test__unit_revert__makeOffer__bSigAtSigner() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtUsername() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "user",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtExpirationDate() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 1 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtOfferAmount() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                0.0000001 ether,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtNonceMNS() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                777
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtSigner() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtToAddress() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtToIdentity() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "matenameservice",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtTokenAddress() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                ETHER_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtAmount() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                priorityFeeAmount,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtPriorityFeeAmount()
        external
    {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                1 ether,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtNonceEVVM() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                777,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtPriorityFlag() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                false,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtExecutor() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(evvm)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__NonceMnsAlreadyUsed() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10101,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__identityDoesNotExist() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "fake",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "fake",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__identityIsNotAUsername() external {
        mns._setIdentityBaseMetadata(
            "test@mail.com",
            MateNameServiceMock.IdentityBaseMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                block.timestamp + 366 days,
                0,
                0,
                0x01
            )
        );
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test@mail.com",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test@mail.com",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test@mail.com", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__amountToOfferIsZero() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__expireDateLessThanNow() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp - 1,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp - 1,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        MateNameServiceMock.OfferMetadata memory checkData = mns
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
