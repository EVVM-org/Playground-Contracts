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

import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestRevert_NameService_addCustomMetadata is Test, Constants {
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
    )
        private
        returns (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        )
    {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToAddCustomMetadata() + priorityFeeAmount
        );

        totalPriceToAddCustomMetadata = nameService.getPriceToAddCustomMetadata();
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
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
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
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*
    function test__unit_revert__addCustomMetadata__bPaySigAt() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    /////////////////

    function test__unit_revert__addCustomMetadata__() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_revert__addCustomMetadata__bSigAtSigner() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bSigAtUsername() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "user",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bSigAtCustomMetadata()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "number>777",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bSigAtNonceMNS() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                777
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtSigner() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtToAddress()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
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
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtToIdentity()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "mtenameservices",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtTokenAddress()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                ETHER_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtAmount() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                7,
                totalPriorityFeeAmount,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtPriorityFee()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                7,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtNonceEVVM()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                777,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtPriorityFlag()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                false,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__bPaySigAtExecutor()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                "test",
                "test>1",
                100010001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToAddCustomMetadata(),
                totalPriorityFeeAmount,
                1001,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__userNotOwner() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_2, 0.0001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__nonceAlreadyUsed() external {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                10101,
                totalPriorityFeeAmount,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__noDataOnCustomMetadata()
        external
    {
        (
            uint256 totalPriceToAddCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "",
                100010001,
                totalPriorityFeeAmount,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceToAddCustomMetadata + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__addCustomMetadata__userHasNotEnoughBalance()
        external
    {
        uint256 totalPriorityFeeAmount = 0;

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeAddCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                "test>1",
                100010001,
                totalPriorityFeeAmount,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.addCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            "test>1",
            totalPriorityFeeAmount,
            signatureMNS,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            0
        );

        assert(
            bytes(customMetadata).length == bytes("").length &&
                keccak256(bytes(customMetadata)) == keccak256(bytes(""))
        );

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
