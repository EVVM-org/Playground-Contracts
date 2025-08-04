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
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";

contract unitTestCorrect_Staking_publicStaking_AsyncExecutionOnPay is
    Test,
    Constants
{
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

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

        vm.startPrank(ADMIN.Address);

        staking.prepareChangeAllowPublicStaking();
        skip(1 days);
        staking.confirmChangeAllowPublicStaking();

        vm.stopPrank();
    }

    function giveMateToExecute(
        address user,
        uint256 stakingAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (staking.priceOfStaking() * stakingAmount) + priorityFee
        );

        totalOfMate = (staking.priceOfStaking() * stakingAmount);
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
        returns (bytes memory signatureEVVM, bytes memory signatureStaking)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(staking),
                    "",
                    MATE_TOKEN_ADDRESS,
                    staking.priceOfStaking() * amountOfSmate,
                    priorityFee,
                    nonceEVVM,
                    priorityEVVM,
                    address(staking)
                )
            );
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(staking),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFee,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
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

    function test__unit_correct__publicStaking__stake_nS_nPF() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            5,
            totalOfPriorityFee,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            5,
            1002,
            signatureStaking,
            totalOfPriorityFee,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            totalOfPriorityFee,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(!evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp - staking.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_nS_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            totalOfPriorityFee,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockStaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1003,
            true,
            1003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1003,
            signatureStaking,
            totalOfPriorityFee,
            1003,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (staking.getSecondsToUnlockFullUnstaking() +
                    staking.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - staking.getSecondsToUnlockStaking()
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            5,
            0.001 ether,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            5,
            1002,
            signatureStaking,
            0.001 ether,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            0.001 ether,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            0.001 ether,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(!evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp - staking.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_nS_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.003 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            0.001 ether,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            0.001 ether,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockStaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1003,
            true,
            1003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1003,
            signatureStaking,
            0.001 ether,
            1003,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (staking.getSecondsToUnlockFullUnstaking() +
                    staking.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - staking.getSecondsToUnlockStaking()
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            5,
            totalOfPriorityFee,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            5,
            1002,
            signatureStaking,
            totalOfPriorityFee,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            totalOfPriorityFee,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - staking.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_S_nPF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            totalOfPriorityFee,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            totalOfPriorityFee,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockStaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1003,
            true,
            1003
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1003,
            signatureStaking,
            totalOfPriorityFee,
            1003,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (staking.getSecondsToUnlockFullUnstaking() +
                    staking.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - staking.getSecondsToUnlockStaking()
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            totalOfPriorityFee,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            5,
            0.001 ether,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            5,
            1002,
            signatureStaking,
            0.001 ether,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            0.001 ether,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            0.001 ether,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(!evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp - staking.getSecondsToUnlockFullUnstaking()
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 10);
        assertEq(history[1].totalStaked, 0);
    }

    function test__unit_correct__publicStaking__stakeAfterFullUnstake_S_PF()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            10,
            0.003 ether
        );

        bytes memory signatureEVVM;
        bytes memory signatureStaking;

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1001,
            signatureStaking,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            false,
            10,
            0.001 ether,
            1002,
            true,
            1002
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            false,
            10,
            1002,
            signatureStaking,
            0.001 ether,
            1002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(staking.getSecondsToUnlockStaking());

        (signatureEVVM, signatureStaking) = makeSignature(
            true,
            10,
            0.001 ether,
            1003,
            true,
            1003
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        staking.publicStaking(
            COMMON_USER_NO_STAKER_1.Address,
            true,
            10,
            1003,
            signatureStaking,
            0.001 ether,
            1003,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(COMMON_USER_NO_STAKER_1.Address)
            );

        history = staking.getAddressHistory(COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(history.length) + totalOfPriorityFee
        );

        assertEq(
            history[0].timestamp,
            block.timestamp -
                (staking.getSecondsToUnlockFullUnstaking() +
                    staking.getSecondsToUnlockStaking())
        );
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(
            history[1].timestamp,
            block.timestamp - staking.getSecondsToUnlockStaking()
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
