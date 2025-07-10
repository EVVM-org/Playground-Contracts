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

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestRevert_MateNameService_adminFunctions is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

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
    }

    function test__unit_revert__proposeAdmin__userIsNotAdmin() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__proposeAdmin__adminProposeAddressZero()
        external
    {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.proposeAdmin(address(0));
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__proposeAdmin__AdminProposeAdmin() external {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.proposeAdmin(ADMIN.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelProposeAdmin__userIsNotAdmin() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelProposeAdmin();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_revert__acceptProposeAdmin__userIsNotProposal()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address currentAdminAfter,
            address proposalAfter,
            uint256 timeToAcceptAfter
        ) = mns.getAdminFullDetails();

        skip(1 days);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.acceptProposeAdmin();
        vm.stopPrank();

        (
            address currentAdminBefore,
            address proposalBefore,
            uint256 timeToAcceptBefore
        ) = mns.getAdminFullDetails();

        assertEq(currentAdminBefore, currentAdminAfter);
        assertEq(proposalBefore, proposalAfter);
        assertEq(timeToAcceptBefore, timeToAcceptAfter);
    }

    function test__unit_revert__acceptProposeAdmin__proposalTriesToClaimNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address currentAdminAfter,
            address proposalAfter,
            uint256 timeToAcceptAfter
        ) = mns.getAdminFullDetails();

        skip(10 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.acceptProposeAdmin();
        vm.stopPrank();

        (
            address currentAdminBefore,
            address proposalBefore,
            uint256 timeToAcceptBefore
        ) = mns.getAdminFullDetails();

        assertEq(currentAdminBefore, currentAdminAfter);
        assertEq(proposalBefore, proposalAfter);
        assertEq(timeToAcceptBefore, timeToAcceptAfter);
    }

    function test__unit_revert__proposeWithdrawMateTokens__userNotAdmin()
        external
    {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_revert__proposeWithdrawMateTokens__adminTriesToClaimMoreThanPermitted()
        external
    {
        uint256 total = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.proposeWithdrawMateTokens(total);
        vm.stopPrank();

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_revert__proposeWithdrawMateTokens__adminClaimZero()
        external
    {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.proposeWithdrawMateTokens(0);
        vm.stopPrank();

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_revert__cancelWithdrawMateTokens__userNotAdmin()
        external
    {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        mns.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelWithdrawMateTokens();
        vm.stopPrank();

        (uint256 amount, uint256 time) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, removeAmount);
        assertEq(time, block.timestamp + 1 days);
    }

    function test__unit_revert__claimWithdrawMateTokens__notAdmin() external {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        mns.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amountAfter, uint256 timeAfter) = mns
            .getProposedWithdrawAmountFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.claimWithdrawMateTokens();
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS),
            totalInEvvm
        );

        (uint256 amountBefore, uint256 timeBefore) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amountBefore, amountAfter);
        assertEq(timeBefore, timeAfter);
    }

    function test__unit_revert__claimWithdrawMateTokens__adminTriesToClaimNotInTime()
        external
    {
        uint256 totalInEvvm = evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS);
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        mns.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amountAfter, uint256 timeAfter) = mns
            .getProposedWithdrawAmountFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.claimWithdrawMateTokens();
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(address(mns), MATE_TOKEN_ADDRESS),
            totalInEvvm
        );

        (uint256 amountBefore, uint256 timeBefore) = mns
            .getProposedWithdrawAmountFullDetails();

        assertEq(amountBefore, amountAfter);
        assertEq(timeBefore, timeAfter);
    }

    function test__unit_revert__proposeChangeEvvmAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEvvmAddressFullDetails();

        assertEq(current, address(evvm));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__proposeChangeEvvmAddress__adminProposeAddressZero()
        external
    {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.proposeChangeEvvmAddress(address(0));
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEvvmAddressFullDetails();

        assertEq(current, address(evvm));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangeEvvmAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getEvvmAddressFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelChangeEvvmAddress();
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getEvvmAddressFullDetails();

        assertEq(current_before, current_after);
        assertEq(proposal_before, proposal_after);
        assertEq(timeToAccept_before, timeToAccept_after);
    }

    function test__unit_revert__acceptChangeEvvmAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getEvvmAddressFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.acceptChangeEvvmAddress();
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getEvvmAddressFullDetails();

        assertEq(current_before, current_after);
        assertEq(proposal_before, proposal_after);
        assertEq(timeToAccept_before, timeToAccept_after);
    }

    function test__unit_revert__acceptChangeEvvmAddress__adminTriesToAcceptNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getEvvmAddressFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.acceptChangeEvvmAddress();
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getEvvmAddressFullDetails();

        assertEq(current_before, current_after);
        assertEq(proposal_before, proposal_after);
        assertEq(timeToAccept_before, timeToAccept_after);
    }

    function test__unit_revert__proposeChangePhoneNumberRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getPhoneNumberRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangePhoneNumberRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getPhoneNumberRegisteryFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelChangePhoneNumberRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getPhoneNumberRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changePhoneNumberRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getPhoneNumberRegisteryFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.changePhoneNumberRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getPhoneNumberRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changePhoneNumberRegistery__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getPhoneNumberRegisteryFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.changePhoneNumberRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getPhoneNumberRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__prepareChangeEmailRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getEmailRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangeEmailRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getEmailRegisteryFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelChangeEmailRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getEmailRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeEmailRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getEmailRegisteryFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.changeEmailRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getEmailRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeEmailRegistery__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getEmailRegisteryFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.changeEmailRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getEmailRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__prepareChangeAutority__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = mns
            .getAutorityFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangeAutority__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getAutorityFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelChangeAutority();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getAutorityFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeAutority__userIsNotAdmin() external {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getAutorityFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.changeAutority();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getAutorityFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeAutority__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = mns.getAutorityFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.changeAutority();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = mns.getAutorityFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__proposeSetStopChangeVerificationsAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assert(!flag);
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__proposeSetStopChangeVerificationsAddress__flagAlreadySet()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        skip(1 days);
        mns.setStopChangeVerificationsAddress();
        vm.stopPrank();

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assert(flag);
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelSetStopChangeVerificationsAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.cancelSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assert(!flag);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_revert__setStopChangeVerificationsAddress__userIsNotAdmin() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_before, uint256 timeToAccept_before) = mns
            .getStopChangeVerificationsAddressFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        mns.setStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_after, uint256 timeToAccept_after) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assertEq(flag_after, flag_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__setStopChangeVerificationsAddress__adminTriesToChangeNotOnTime() external {
        vm.startPrank(ADMIN.Address);
        mns.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_before, uint256 timeToAccept_before) = mns
            .getStopChangeVerificationsAddressFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        mns.setStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_after, uint256 timeToAccept_after) = mns
            .getStopChangeVerificationsAddressFullDetails();

        assertEq(flag_after, flag_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }
}
