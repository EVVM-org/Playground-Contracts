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
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

import {SMate} from "@EVVM/playground/staking/SMate.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestCorrect_SMate_presaleStaking_AsyncExecutionOnPay is
    Test,
    Constants
{
    SMate sMate;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    function setUp() public {
        sMate = new SMate(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        nameService = new NameService(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupNameServiceAddress(address(nameService));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPresaleStaking();
        skip(1 days);
        sMate.confirmChangeAllowPresaleStaking();

        sMate.addPresaleStaker(COMMON_USER_NO_STAKER_1.Address);
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
                    sMate.priceOfSMate() * 1,
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
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                isStaking,
                1,
                nonceSmate
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.getRewardAmount() * 2) * numberOfTx;
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * nPF: No priority fee
     * PF: Includes priority fee
     */

    function test__unit_correct__presaleStaking_AsyncExecution__stake_nS_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1000001000001,
                true,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1000001000001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            signatureSMate,
            0,
            1000001000001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__stake_nS_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0.000001 ether
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1000001000001,
                true,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1000001000001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            signatureSMate,
            totalOfPriorityFee,
            1000001000001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__unstake_nS_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(history[0].timestamp, block.timestamp);
        assertEq(history[0].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);

        assertEq(history[1].timestamp, block.timestamp);
        assertEq(history[1].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 2);

        console2.log("history ts", history[2].timestamp);

        assertEq(history[2].timestamp, block.timestamp);
        assertEq(history[2].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 1);
        assertEq(history[2].totalStaked, 1);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__fullUnstake_nS_nPF()
        external
    {
        giveMateToExecute(COMMON_USER_NO_STAKER_1.Address, 2, 0);

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            103,
            true,
            103
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            103,
            signatureSMate,
            0,
            103,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[0].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[1].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 2);

        console2.log("history ts", history[2].timestamp);

        assertEq(
            history[2].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[2].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 1);
        assertEq(history[2].totalStaked, 1);

        assertEq(history[3].timestamp, block.timestamp);
        assertEq(history[3].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[3].amount, 1);
        assertEq(history[3].totalStaked, 0);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__fullUnstake_nS_PF()
        external
    {
        giveMateToExecute(COMMON_USER_NO_STAKER_1.Address, 2, 0.004 ether);

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0.001 ether,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0.001 ether,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 1");

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0.001 ether,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0.001 ether,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 2");

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0.001 ether,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0.001 ether,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 3");

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0.001 ether,
            103,
            true,
            103
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            103,
            signatureSMate,
            0.001 ether,
            103,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 4");

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[0].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[1].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 2);

        console2.log("history ts", history[2].timestamp);

        assertEq(
            history[2].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[2].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 1);
        assertEq(history[2].totalStaked, 1);

        assertEq(history[3].timestamp, block.timestamp);
        assertEq(history[3].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[3].amount, 1);
        assertEq(history[3].totalStaked, 0);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__stake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1000001000001,
                true,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1000001000001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            signatureSMate,
            0,
            1000001000001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__stake_S_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0.000001 ether
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1000001000001,
                true,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1000001000001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            signatureSMate,
            totalOfPriorityFee,
            1000001000001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__unstake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(3) + totalOfPriorityFee
        );

        assertEq(history[0].timestamp, block.timestamp);
        assertEq(history[0].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);

        assertEq(history[1].timestamp, block.timestamp);
        assertEq(history[1].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 2);

        console2.log("history ts", history[2].timestamp);

        assertEq(history[2].timestamp, block.timestamp);
        assertEq(history[2].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 1);
        assertEq(history[2].totalStaked, 1);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__fullUnstake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            103,
            true,
            103
        );

        //!!! como en este no hay un pf solo se ejecuta un unico stake

        console.log(evvm.getBalance(address(sMate), MATE_TOKEN_ADDRESS));

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            103,
            signatureSMate,
            0,
            103,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(4) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[0].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[1].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 2);

        console2.log("history ts", history[2].timestamp);

        assertEq(history[2].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 1);
        assertEq(history[2].totalStaked, 1);

        assertEq(history[3].timestamp, block.timestamp);
        assertEq(history[3].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[3].amount, 1);
        assertEq(history[3].totalStaked, 0);
    }

    function test__unit_correct__presaleStaking_AsyncExecution__fullUnstake_S_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0.004 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0.001 ether,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0.001 ether,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 1");

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0.001 ether,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0.001 ether,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 2");

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0.001 ether,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0.001 ether,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 3");

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0.001 ether,
            103,
            true,
            103
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            103,
            signatureSMate,
            0.001 ether,
            103,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        console2.log("pass 4");

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );
        history = sMate.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));

        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(4) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[0].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 1);
        assertEq(history[0].totalStaked, 1);

        assertEq(
            history[1].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[1].transactionType, DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 2);

        assertEq(
            history[2].timestamp,
            block.timestamp - sMate.getSecondsToUnlockFullUnstaking()
        );
        assertEq(history[2].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[2].amount, 1);
        assertEq(history[2].totalStaked, 1);

        assertEq(history[3].timestamp, block.timestamp);
        assertEq(history[3].transactionType, WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[3].amount, 1);
        assertEq(history[3].totalStaked, 0);
    }
}
