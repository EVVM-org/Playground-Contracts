// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function revert behavior
 * @notice some functions has evvm functions that are implemented
 *         and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract unitTestRevert_EVVM_dispersePay_asyncExecution is Test, Constants {
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

        mns._setIdentityBaseMetadata(
            "dummy",
            MateNameServiceMock.IdentityBaseMetadata({
                owner: COMMON_USER_NO_STAKER_2.Address,
                expireDate: block.timestamp + 366 days,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x00
            })
        );
    }

    function addBalance(
        address user,
        address token,
        uint256 amount,
        uint256 priorityFee
    ) private {
        evvm._addBalance(user, token, amount + priorityFee);
    }

    /**
     * For the signature tes we going to assume the executor is a bad actor,
     * but in the executor test an fisher try to execute the payment who obivously
     * is not the executor.
     * Function to test:
     * bSigAt[section]: incorrect signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unit_revert__dispersePay_asyncExecution__bSigAtAmountOnMetadata()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory correctToData = new EvvmMockStructs.DispersePayMetadata[](2);

        EvvmMockStructs.DispersePayMetadata[]
            memory badToData = new EvvmMockStructs.DispersePayMetadata[](2);

        correctToData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        correctToData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        badToData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.9 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        badToData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(correctToData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            badToData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtToAddressOnMetadata()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory correctToData = new EvvmMockStructs.DispersePayMetadata[](2);

        EvvmMockStructs.DispersePayMetadata[]
            memory badToData = new EvvmMockStructs.DispersePayMetadata[](2);

        correctToData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        correctToData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        badToData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_3.Address,
            to_identity: ""
        });

        badToData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(correctToData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            badToData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtToIdentityOnMetadata()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory correctToData = new EvvmMockStructs.DispersePayMetadata[](2);

        EvvmMockStructs.DispersePayMetadata[]
            memory badToData = new EvvmMockStructs.DispersePayMetadata[](2);

        correctToData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        correctToData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        badToData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        badToData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "fake"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(correctToData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            badToData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtTokenAddress()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            MATE_TOKEN_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtTotalAmount()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.5 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtPriorityFee()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            1 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtNonce()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            777,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtPriorityFlag()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__bSigAtExecutor()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }
    

    function test__unit_revert__dispersePay_asyncExecution__wValAtExecutor()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__nonceAlreadyUsed()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.4 ether,
            0.02 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__amountPlusPFMoreThanBalance()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                2 ether,
                1 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            2 ether,
            1 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_asyncExecution__sumOfDisperseAmounDoesNotMatchTotalAmount()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.5 ether,
            0.01 ether
        );
        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.3 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
                ETHER_ADDRESS,
                0.2 ether,
                0.01 ether,
                110011,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether,
            110011,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.51 ether
        );
    }
}
