// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for 
 * @notice some functions has evvm functions that are implemented
 *         and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";
import {EvvmMockStructs} from "@EVVM/Playground/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/Playground/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/Playground/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/Playground/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/Playground/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/Playground/EvvmMockStorage.sol";

contract unitTestCorrect_SMate_publicStaking_SyncExecutionOnPay is
    Test,
    Constants
{
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();
    }

    function giveMateToExecute(
        address user,
        uint256 sMateAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (sMate.priceOfSMate() * sMateAmount) + priorityFee
        );

        totalOfMate = (sMate.priceOfSMate() * sMateAmount);
        totalOfPriorityFee = priorityFee;
    }

    function makeSignature(
        bool isStaking,
        uint256 amountOfSmate,
        uint256 priorityFee,
        uint256 nonceEVVM,
        bool priorityEVVM,
        uint256 nonceSmate
    )
        private
        view
        returns (bytes memory signatureEVVM, bytes memory signatureSMate)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(sMate),
                    "",
                    MATE_TOKEN_ADDRESS,
                    sMate.priceOfSMate() * amountOfSmate,
                    priorityFee,
                    nonceEVVM,
                    priorityEVVM,
                    address(sMate)
                )
            );
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(sMate),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFee,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(sMate)
                )
            );
        }

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                isStaking,
                amountOfSmate,
                nonceSmate
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * nPF: No priority fee
     * PF: Includes priority fee
     */

    function test__unit_correct__publicStaking__stake_nS_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__unstake_nS_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            5,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            5,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_correct__publicStaking__fullUnstake_nS_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_nS_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1003,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (sMate.getSecondsToUnlockFullUnstaking() +
                    sMate.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockStaking()
        );
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);

        assertEq(history[2].timestamp, block.timestamp);
        assert(history[2].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 10);
        assertEq(history[2].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__stake_nS_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.001 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__unstake_nS_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            5,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            5,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_correct__publicStaking__fullUnstake_nS_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_nS_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.003 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1003,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (sMate.getSecondsToUnlockFullUnstaking() +
                    sMate.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockStaking()
        );
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);

        assertEq(history[2].timestamp, block.timestamp);
        assert(history[2].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 10);
        assertEq(history[2].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__stake_S_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__unstake_S_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            5,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            5,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_correct__publicStaking__fullUnstake_S_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_S_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1003,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (sMate.getSecondsToUnlockFullUnstaking() +
                    sMate.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockStaking()
        );
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);

        assertEq(history[2].timestamp, block.timestamp);
        assert(history[2].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 10);
        assertEq(history[2].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__stake_S_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.001 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicStaking__unstake_S_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            5,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            5,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_correct__publicStaking__fullUnstake_S_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_S_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.003 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1002,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1003,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (sMate.getSecondsToUnlockFullUnstaking() +
                    sMate.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockStaking()
        );
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);

        assertEq(history[2].timestamp, block.timestamp);
        assert(history[2].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 10);
        assertEq(history[2].totalStaked, 10);
    }
}
