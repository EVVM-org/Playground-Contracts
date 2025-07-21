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

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestCorrect_MateNameService_adminFunctions is Test, Constants {
    SMateMock sMate;
    Evvm evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
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
    }

    function test__unit_correct__proposeAdmin() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelProposeAdmin() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeAdmin(WILDCARD_USER.Address);
        mns.cancelProposeAdmin();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__acceptProposeAdmin() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        mns.acceptProposeAdmin();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, WILDCARD_USER.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__proposeWithdrawMateTokens() external {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        mns.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, removeAmount);
        assertEq(time, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelWithdrawMateTokenss() external {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        mns.proposeWithdrawMateTokens(removeAmount);
        mns.cancelWithdrawMateTokens();
        vm.stopPrank();

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_correct__claimWithdrawMateTokens() external {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        mns.proposeWithdrawMateTokens(removeAmount);
        skip(1 days);
        mns.claimWithdrawMateTokens();
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS),
            (totalInEvvm - removeAmount) + evvm.seeMateReward()
        );

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_correct__proposeChangeEvvmAddress() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEvvmAddressFullDetails();

        assertEq(current, address(evvm));
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelChangeEvvmAddress() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        mns.cancelChangeEvvmAddress();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEvvmAddressFullDetails();

        assertEq(current, address(evvm));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__acceptChangeEvvmAddress() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        skip(1 days);
        mns.acceptChangeEvvmAddress();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEvvmAddressFullDetails();

        assertEq(current, WILDCARD_USER.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__proposeChangePhoneNumberRegistery() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getPhoneNumberRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelChangePhoneNumberRegistery() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        mns.cancelChangePhoneNumberRegistery();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getPhoneNumberRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__changePhoneNumberRegistery() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        skip(1 days);
        mns.changePhoneNumberRegistery();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getPhoneNumberRegisteryFullDetails();

        assertEq(current, WILDCARD_USER.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__prepareChangeEmailRegistery() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEmailRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelChangeEmailRegistery() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        mns.cancelChangeEmailRegistery();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEmailRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__changeEmailRegistery() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        skip(1 days);
        mns.changeEmailRegistery();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEmailRegisteryFullDetails();

        assertEq(current, WILDCARD_USER.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__prepareChangeAutority() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAutorityFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelChangeAutority() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        mns.cancelChangeAutority();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAutorityFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__changeAutority() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        skip(1 days);
        mns.changeAutority();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAutorityFullDetails();

        assertEq(current, WILDCARD_USER.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__proposeSetStopChangeVerificationsAddress()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assert(!flag);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_correct__cancelSetStopChangeVerificationsAddress()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        mns.cancelSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assert(!flag);
        assertEq(timeToAccept, 0);
    }

    function test__unit_correct__setStopChangeVerificationsAddress() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        skip(1 days);
        mns.setStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assert(flag);
        assertEq(timeToAccept, 0);
    }
}
