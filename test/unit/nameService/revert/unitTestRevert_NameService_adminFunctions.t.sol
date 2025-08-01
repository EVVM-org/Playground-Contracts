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

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

contract unitTestRevert_NameService_adminFunctions is Test, Constants {
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
    }

    function test__unit_revert__proposeAdmin__userIsNotAdmin() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
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
        nameService.proposeAdmin(address(0));
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__proposeAdmin__AdminProposeAdmin() external {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.proposeAdmin(ADMIN.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelProposeAdmin__userIsNotAdmin() external {
        vm.startPrank(ADMIN.Address);
        nameService.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelProposeAdmin();
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getAdminFullDetails();

        assertEq(current, ADMIN.Address);
        assertEq(proposal, WILDCARD_USER.Address);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_revert__acceptProposeAdmin__userIsNotProposal()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address currentAdminAfter,
            address proposalAfter,
            uint256 timeToAcceptAfter
        ) = nameService.getAdminFullDetails();

        skip(1 days);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.acceptProposeAdmin();
        vm.stopPrank();

        (
            address currentAdminBefore,
            address proposalBefore,
            uint256 timeToAcceptBefore
        ) = nameService.getAdminFullDetails();

        assertEq(currentAdminBefore, currentAdminAfter);
        assertEq(proposalBefore, proposalAfter);
        assertEq(timeToAcceptBefore, timeToAcceptAfter);
    }

    function test__unit_revert__acceptProposeAdmin__proposalTriesToClaimNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address currentAdminAfter,
            address proposalAfter,
            uint256 timeToAcceptAfter
        ) = nameService.getAdminFullDetails();

        skip(10 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.acceptProposeAdmin();
        vm.stopPrank();

        (
            address currentAdminBefore,
            address proposalBefore,
            uint256 timeToAcceptBefore
        ) = nameService.getAdminFullDetails();

        assertEq(currentAdminBefore, currentAdminAfter);
        assertEq(proposalBefore, proposalAfter);
        assertEq(timeToAcceptBefore, timeToAcceptAfter);
    }

    function test__unit_revert__proposeWithdrawMateTokens__userNotAdmin()
        external
    {
        uint256 totalInEvvm = evvm.getBalance(
            address(nameService),
            MATE_TOKEN_ADDRESS
        );
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amount, uint256 time) = nameService
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_revert__proposeWithdrawMateTokens__adminTriesToClaimMoreThanPermitted()
        external
    {
        uint256 total = evvm.getBalance(
            address(nameService),
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.proposeWithdrawMateTokens(total);
        vm.stopPrank();

        (uint256 amount, uint256 time) = nameService
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_revert__proposeWithdrawMateTokens__adminClaimZero()
        external
    {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.proposeWithdrawMateTokens(0);
        vm.stopPrank();

        (uint256 amount, uint256 time) = nameService
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, 0);
        assertEq(time, 0);
    }

    function test__unit_revert__cancelWithdrawMateTokens__userNotAdmin()
        external
    {
        uint256 totalInEvvm = evvm.getBalance(
            address(nameService),
            MATE_TOKEN_ADDRESS
        );
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        nameService.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelWithdrawMateTokens();
        vm.stopPrank();

        (uint256 amount, uint256 time) = nameService
            .getProposedWithdrawAmountFullDetails();

        assertEq(amount, removeAmount);
        assertEq(time, block.timestamp + 1 days);
    }

    function test__unit_revert__claimWithdrawMateTokens__notAdmin() external {
        uint256 totalInEvvm = evvm.getBalance(
            address(nameService),
            MATE_TOKEN_ADDRESS
        );
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        nameService.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amountAfter, uint256 timeAfter) = nameService
            .getProposedWithdrawAmountFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.claimWithdrawMateTokens();
        vm.stopPrank();

        assertEq(
            evvm.getBalance(address(nameService), MATE_TOKEN_ADDRESS),
            totalInEvvm
        );

        (uint256 amountBefore, uint256 timeBefore) = nameService
            .getProposedWithdrawAmountFullDetails();

        assertEq(amountBefore, amountAfter);
        assertEq(timeBefore, timeAfter);
    }

    function test__unit_revert__claimWithdrawMateTokens__adminTriesToClaimNotInTime()
        external
    {
        uint256 totalInEvvm = evvm.getBalance(
            address(nameService),
            MATE_TOKEN_ADDRESS
        );
        uint256 removeAmount = totalInEvvm / 10;

        vm.startPrank(ADMIN.Address);
        nameService.proposeWithdrawMateTokens(removeAmount);
        vm.stopPrank();

        (uint256 amountAfter, uint256 timeAfter) = nameService
            .getProposedWithdrawAmountFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.claimWithdrawMateTokens();
        vm.stopPrank();

        assertEq(
            evvm.getBalance(address(nameService), MATE_TOKEN_ADDRESS),
            totalInEvvm
        );

        (uint256 amountBefore, uint256 timeBefore) = nameService
            .getProposedWithdrawAmountFullDetails();

        assertEq(amountBefore, amountAfter);
        assertEq(timeBefore, timeAfter);
    }

    function test__unit_revert__proposeChangeEvvmAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
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
        nameService.proposeChangeEvvmAddress(address(0));
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getEvvmAddressFullDetails();

        assertEq(current, address(evvm));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangeEvvmAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getEvvmAddressFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelChangeEvvmAddress();
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getEvvmAddressFullDetails();

        assertEq(current_before, current_after);
        assertEq(proposal_before, proposal_after);
        assertEq(timeToAccept_before, timeToAccept_after);
    }

    function test__unit_revert__acceptChangeEvvmAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getEvvmAddressFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.acceptChangeEvvmAddress();
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getEvvmAddressFullDetails();

        assertEq(current_before, current_after);
        assertEq(proposal_before, proposal_after);
        assertEq(timeToAccept_before, timeToAccept_after);
    }

    function test__unit_revert__acceptChangeEvvmAddress__adminTriesToAcceptNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeChangeEvvmAddress(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getEvvmAddressFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.acceptChangeEvvmAddress();
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getEvvmAddressFullDetails();

        assertEq(current_before, current_after);
        assertEq(proposal_before, proposal_after);
        assertEq(timeToAccept_before, timeToAccept_after);
    }

    function test__unit_revert__proposeChangePhoneNumberRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getPhoneNumberRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangePhoneNumberRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getPhoneNumberRegisteryFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelChangePhoneNumberRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getPhoneNumberRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changePhoneNumberRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getPhoneNumberRegisteryFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.changePhoneNumberRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getPhoneNumberRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changePhoneNumberRegistery__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeChangePhoneNumberRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getPhoneNumberRegisteryFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.changePhoneNumberRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getPhoneNumberRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__prepareChangeEmailRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getEmailRegisteryFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangeEmailRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getEmailRegisteryFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelChangeEmailRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getEmailRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeEmailRegistery__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getEmailRegisteryFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.changeEmailRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getEmailRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeEmailRegistery__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.prepareChangeEmailRegistery(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getEmailRegisteryFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.changeEmailRegistery();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getEmailRegisteryFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__prepareChangeAutority__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (address current, address proposal, uint256 timeToAccept) = nameService
            .getAutorityFullDetails();

        assertEq(current, address(0));
        assertEq(proposal, address(0));
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelChangeAutority__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getAutorityFullDetails();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelChangeAutority();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getAutorityFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeAutority__userIsNotAdmin() external {
        vm.startPrank(ADMIN.Address);
        nameService.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getAutorityFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.changeAutority();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getAutorityFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__changeAutority__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.prepareChangeAutority(WILDCARD_USER.Address);
        vm.stopPrank();

        (
            address current_before,
            address proposal_before,
            uint256 timeToAccept_before
        ) = nameService.getAutorityFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.changeAutority();
        vm.stopPrank();

        (
            address current_after,
            address proposal_after,
            uint256 timeToAccept_after
        ) = nameService.getAutorityFullDetails();

        assertEq(current_after, current_before);
        assertEq(proposal_after, proposal_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__proposeSetStopChangeVerificationsAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        assert(!flag);
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__proposeSetStopChangeVerificationsAddress__flagAlreadySet()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeSetStopChangeVerificationsAddress();
        skip(1 days);
        nameService.setStopChangeVerificationsAddress();
        vm.stopPrank();

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        assert(flag);
        assertEq(timeToAccept, 0);
    }

    function test__unit_revert__cancelSetStopChangeVerificationsAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.cancelSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag, uint256 timeToAccept) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        assert(!flag);
        assertEq(timeToAccept, block.timestamp + 1 days);
    }

    function test__unit_revert__setStopChangeVerificationsAddress__userIsNotAdmin()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_before, uint256 timeToAccept_before) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        skip(1 days);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        nameService.setStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_after, uint256 timeToAccept_after) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        assertEq(flag_after, flag_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }

    function test__unit_revert__setStopChangeVerificationsAddress__adminTriesToChangeNotOnTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        nameService.proposeSetStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_before, uint256 timeToAccept_before) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        skip(10 hours);

        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        nameService.setStopChangeVerificationsAddress();
        vm.stopPrank();

        (bool flag_after, uint256 timeToAccept_after) = nameService
            .getStopChangeVerificationsAddressFullDetails();

        assertEq(flag_after, flag_before);
        assertEq(timeToAccept_after, timeToAccept_before);
    }
}
