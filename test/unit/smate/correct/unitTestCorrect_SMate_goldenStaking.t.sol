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
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestCorrect_SMate_goldenStaking is Test, Constants {
    SMate sMate;
    Evvm evvm;
    Estimator estimator;
    Mns mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMate(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new Mns(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mns));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function giveMateToExecute(
        address user,
        uint256 sMateAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (sMate.priceOfSMate() * sMateAmount) + priorityFee
        );

        totalOfMate = (sMate.priceOfSMate() * sMateAmount) + priorityFee;
    }

    function calculateRewardPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
    }

    function test__unit_correct__unit_correct__goldenStaking__staking() external {
        uint256 totalOfMate = giveMateToExecute(GOLDEN_STAKER.Address, 10, 0);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 10, signatureEVVM);

        vm.stopPrank();

        assert(evvm.isMateStaker(GOLDEN_STAKER.Address));

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(GOLDEN_STAKER.Address)
            );
        history = sMate.getAddressHistory(GOLDEN_STAKER.Address);

        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            calculateRewardPerExecution(1)
        );
        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);
    }

    function test__unit_correct__goldenStaking__unstaking() external {
        uint256 totalOfMate = giveMateToExecute(GOLDEN_STAKER.Address, 2, 0);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 2, signatureEVVM);
        sMate.goldenStaking(false, 1, "");

        vm.stopPrank();

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(GOLDEN_STAKER.Address)
            );
        history = sMate.getAddressHistory(GOLDEN_STAKER.Address);

        assert(evvm.isMateStaker(GOLDEN_STAKER.Address));

        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            calculateRewardPerExecution(2) + sMate.priceOfSMate()
        );

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 2);
        assertEq(history[0].totalStaked, 2);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 1);
        assertEq(history[1].totalStaked, 1);
    }

    function test__unit_correct__goldenStaking__fullUnstaking() external {
        uint256 totalOfMate = giveMateToExecute(GOLDEN_STAKER.Address, 2, 0);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 2, signatureEVVM);

        vm.warp(
            sMate.getTimeToUserUnlockFullUnstakingTime(GOLDEN_STAKER.Address)
        );

        console2.log(
            evvm.seeBalance(address(sMate), MATE_TOKEN_ADDRESS)
        );

        sMate.goldenStaking(false, 2, "");

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            (calculateRewardPerExecution(1)) + (sMate.priceOfSMate() * 2)
        );

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));

        SMate.HistoryMetadata[]
            memory history = new SMate.HistoryMetadata[](
                sMate.getSizeOfAddressHistory(GOLDEN_STAKER.Address)
            );

        history = sMate.getAddressHistory(GOLDEN_STAKER.Address);

        assertEq(history[0].timestamp, 1);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 2);
        assertEq(history[0].totalStaked, 2);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 2);
        assertEq(history[1].totalStaked, 0);
    }
}
