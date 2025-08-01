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
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestRevert_EVVM_dispersePay_syncExecution is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                principalTokenName: "EVVM Staking Token",
                principalTokenSymbol: "EVVM-STK",
                principalTokenAddress: 0x0000000000000000000000000000000000000001,
                totalSupply: 2033333333000000000000000000,
                eraTokens: 2033333333000000000000000000 / 2,
                reward: 5000000000000000000
            })
        );
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

        nameService._setIdentityBaseMetadata(
            "dummy",
            NameService.IdentityBaseMetadata({
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

    function test__unit_revert__dispersePay_syncExecution__bSigAtAmountOnMetadata()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory correctToData = new EvvmStructs.DispersePayMetadata[](2);

        EvvmStructs.DispersePayMetadata[]
            memory badToData = new EvvmStructs.DispersePayMetadata[](2);

        correctToData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        correctToData[1] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        badToData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.9 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        badToData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtToAddressOnMetadata()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory correctToData = new EvvmStructs.DispersePayMetadata[](2);

        EvvmStructs.DispersePayMetadata[]
            memory badToData = new EvvmStructs.DispersePayMetadata[](2);

        correctToData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        correctToData[1] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        badToData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_3.Address,
            to_identity: ""
        });

        badToData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtToIdentityOnMetadata()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory correctToData = new EvvmStructs.DispersePayMetadata[](2);

        EvvmStructs.DispersePayMetadata[]
            memory badToData = new EvvmStructs.DispersePayMetadata[](2);

        correctToData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        correctToData[1] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: address(0),
            to_identity: "dummy"
        });

        badToData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        badToData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtTokenAddress()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtTotalAmount()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtPriorityFee()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtNonce()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                777,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtPriorityFlag()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            true,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__bSigAtExecutor()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__wValAtExecutor()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__amountPlusPFMoreThanBalance()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 1 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.21 ether
        );
    }

    function test__unit_revert__dispersePay_syncExecution__sumOfDisperseAmounDoesNotMatchTotalAmount()
        external
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.5 ether,
            0.01 ether
        );
        EvvmStructs.DispersePayMetadata[]
            memory toData = new EvvmStructs.DispersePayMetadata[](2);

        toData[0] = EvvmStructs.DispersePayMetadata({
            amount: 0.3 ether,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: ""
        });

        toData[1] = EvvmStructs.DispersePayMetadata({
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
                0,
                false,
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
            0,
            false,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.51 ether
        );
    }
}
