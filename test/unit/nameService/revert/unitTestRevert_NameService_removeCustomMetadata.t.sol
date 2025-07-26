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

contract unitTestRevert_NameService_removeCustomMetadata is
    Test,
    Constants
{
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
        uint256 priorityFeeAmount
    )
        private
        returns (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        )
    {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToRemoveCustomMetadata() + priorityFeeAmount
        );

        totalPriceRemovedCustomMetadata = nameService.getPriceToRemoveCustomMetadata();
        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makeRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceNameServicePre,
        uint256 nonceNameService
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
                nonceNameServicePre
            )
        );

        nameService.preRegistrationUsername(
            user.Address,
            nonceNameServicePre,
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
                nonceNameService
            )
        );
        bytes memory signatureNameService = Erc191TestBuilder.buildERC191Signature(
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
            nonceNameService,
            username,
            clowNumber,
            signatureNameService,
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
        uint256 nonceNameService,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    ) private {
        uint8 v;
        bytes32 r;
        bytes32 s;

        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToAddCustomMetadata()
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAddCustomMetadata(
                username,
                customMetadata,
                nonceNameService
            )
        );
        bytes memory signatureNameService = Erc191TestBuilder.buildERC191Signature(
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
                nameService.getPriceToAddCustomMetadata(),
                0,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        nameService.addCustomMetadata(
            user.Address,
            nonceNameService,
            username,
            customMetadata,
            0,
            signatureNameService,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeRemoveCustomMetadataSignatures(
        AccountData memory user,
        string memory username,
        uint256 indexCustomMetadata,
        uint256 nonceNameService,
        uint256 priorityFeeAmountEVVM,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    )
        private
        view
        returns (bytes memory signatureNameService, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                username,
                indexCustomMetadata,
                nonceNameService
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToRemoveCustomMetadata(),
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
    function test__unit_revert__removeCustomMetadata__bSigAt() external {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                "test",
                1,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToRemoveCustomMetadata(),
                totalPriorityFeeAmount,
                100010001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    //////////////////////////////////////////////////////////////////////

    function test__unit_revert__removeCustomMetadata__S_PF() external {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1,
                100010001,
                totalPriorityFeeAmount,
                100010001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_revert__removeCustomMetadata__bSigAtSigner() external {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                "test",
                1,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToRemoveCustomMetadata(),
                totalPriorityFeeAmount,
                100010001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__bSigAtUsername()
        external
    {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                "user",
                1,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToRemoveCustomMetadata(),
                totalPriorityFeeAmount,
                100010001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__bSigAtIndex() external {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                "test",
                777,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToRemoveCustomMetadata(),
                totalPriorityFeeAmount,
                100010001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__bSigAtNonceNameService()
        external
    {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRemoveCustomMetadata(
                "test",
                1,
                777
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceToRemoveCustomMetadata(),
                totalPriorityFeeAmount,
                100010001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__notOwnerOfUsername()
        external
    {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_2, 0.0001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                1,
                100010001,
                totalPriorityFeeAmount,
                100010001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_2.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__nonceAlreadyUsed()
        external
    {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1,
                11,
                totalPriorityFeeAmount,
                100010001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            11,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__indexMoreThanMax()
        external
    {
        (
            uint256 totalPriceRemovedCustomMetadata,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, 0.0001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                100010001,
                totalPriorityFeeAmount,
                100010001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            777,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriceRemovedCustomMetadata + totalPriorityFeeAmount
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__removeCustomMetadata__userDontHaveFunds()
        external
    {
        uint256 totalPriorityFeeAmount = 0;

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRemoveCustomMetadataSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1,
                100010001,
                totalPriorityFeeAmount,
                100010001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.removeCustomMetadata(
            COMMON_USER_NO_STAKER_1.Address,
            100010001,
            "test",
            1,
            totalPriorityFeeAmount,
            signatureNameService,
            100010001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        string memory customMetadata = nameService.getSingleCustomMetadataOfIdentity(
            "test",
            1
        );

        assertEq(bytes(customMetadata).length, bytes("test>2").length);
        assertEq(keccak256(bytes(customMetadata)), keccak256(bytes("test>2")));

        assertEq(nameService.getCustomMetadataMaxSlotsOfIdentity("test"), 3);

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
