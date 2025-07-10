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

import {Constants, MockContract} from "test/Constants.sol";
import {EvvmMockStructs} from "@EVVM/playground/core/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";

contract unitTestCorrect_SMate_publicServiceStaking_SyncExecutionOnPay is
    Test,
    Constants
{
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;
    MockContract mock;

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

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        mock = new MockContract(address(sMate));
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
        address serviceAddress,
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                serviceAddress,
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

    function test__unit_correct__publicServiceStaking__stake_nS_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicServiceStaking__unstake_nS_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        mock.unstake(5, 1002, address(mock));

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_correct__publicServiceStaking__fullUnstake_nS_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
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

        mock.unstake(10, 1002, address(mock));

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

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

    function test__unit_correct__publicServiceStaking__stakeAfterFullUnstake_nS_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
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

        mock.unstake(10, 1002, address(mock));

        mock.getBackMate(COMMON_USER_NO_STAKER_1.Address);

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1003,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

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

    function test__unit_correct__publicServiceStaking__stake_nS_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.001 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicServiceStaking__unstake_nS_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        mock.unstake(5, 1002, address(mock));

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_correct__publicServiceStaking__fullUnstake_nS_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
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

        mock.unstake(10, 1002, address(mock));

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

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

    function test__unit_correct__publicServiceStaking__stakeAfterFullUnstake_nS_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.003 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
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

        mock.unstake(10, 1002, address(mock));

        mock.getBackMate(COMMON_USER_NO_STAKER_1.Address);

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1003,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

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

    function test__unit_correct__publicServiceStaking__stake_S_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicServiceStaking__unstake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        mock.unstake(5, 1002, address(mock));

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
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

    function test__unit_correct__publicServiceStaking__fullUnstake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
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

        mock.unstake(10, 1002, address(mock));

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
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

    function test__unit_correct__publicServiceStaking__stakeAfterFullUnstake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
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

        mock.unstake(10, 1002, address(mock));

        mock.getBackMate(COMMON_USER_NO_STAKER_1.Address);

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1003,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(2) + totalOfPriorityFee
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

    function test__unit_correct__publicServiceStaking__stake_S_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.001 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            totalOfPriorityFee,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__publicServiceStaking__unstake_S_PF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.002 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            0.002 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        mock.unstake(5, 1002, address(mock));

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + (totalOfPriorityFee)
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

    function test__unit_correct__publicServiceStaking__fullUnstake_S_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.002 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.002 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            0.002 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        mock.unstake(10, 1002, address(mock));

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
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

    function test__unit_correct__publicServiceStaking__stakeAfterFullUnstake_S_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.003 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.002 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001,
            10,
            signatureSMate,
            0.002 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        mock.unstake(10, 1002, address(mock));

        mock.getBackMate(COMMON_USER_NO_STAKER_1.Address);

        skip(sMate.getSecondsToUnlockStaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            address(mock),
            true,
            10,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            1003
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1003,
            10,
            signatureSMate,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        SMateMock.HistoryMetadata[]
            memory history = new SMateMock.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(address(mock))
            );

        history = sMate.getAddressHistory(address(mock));

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(2) + totalOfPriorityFee
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