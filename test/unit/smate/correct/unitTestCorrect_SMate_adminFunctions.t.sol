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
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract unitTestCorrect_SMate_adminFunctions is
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

    }

    function test__unit_correct__admin_addPresaleStaker() external {
        vm.startPrank(ADMIN.Address);
        sMate.addPresaleStaker(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unit_correct__admin_addPresaleStakers() external {
        address[] memory stakers = new address[](2);
        stakers[0] = makeAddr("alice");
        stakers[1] = makeAddr("bob");

        vm.startPrank(ADMIN.Address);
        sMate.addPresaleStakers(stakers);
        vm.stopPrank();
    }

    function test__unit_correct__admin_proposeAdmin() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unit_correct__admin_rejectProposalAdmin() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 2 hours);
        sMate.rejectProposalAdmin();
        vm.stopPrank();
    }

    function test__unit_correct__admin_acceptNewAdmin() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(WILDCARD_USER.Address);
        sMate.acceptNewAdmin();
        vm.stopPrank();
    }

    function test__unit_correct__admin_proposeGoldenFisher() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unit_correct__admin_rejectProposalGoldenFisher() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 2 hours);
        sMate.rejectProposalGoldenFisher();
        vm.stopPrank();
    }

    function test__unit_correct__admin_acceptNewGoldenFisher() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 1 days + 1);
        sMate.acceptNewGoldenFisher();
        vm.stopPrank();
    }

    function test__unit_correct__admin_proposeSetSecondsToUnlockStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();
    }

    function test__unit_correct__admin_rejectProposalSetSecondsToUnlockStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.warp(block.timestamp + 2 hours);
        sMate.rejectProposalSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_acceptSetSecondsToUnlockStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.warp(block.timestamp + 1 days + 1);
        sMate.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_prepareSetSecondsToUnllockFullUnstaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();
    }

    function test__unit_correct__admin_cancelSetSecondsToUnllockFullUnstaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.warp(block.timestamp + 2 hours);
        sMate.cancelSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_confirmSetSecondsToUnllockFullUnstaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.warp(block.timestamp + 1 days + 1);
        sMate.confirmSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_prepareChangeAllowPublicStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_cancelChangeAllowPublicStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPublicStaking();
        vm.warp(block.timestamp + 2 hours);
        sMate.cancelChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_confirmChangeAllowPublicStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPublicStaking();
        vm.warp(block.timestamp + 1 days + 1);
        sMate.confirmChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_prepareChangeAllowPresaleStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_cancelChangeAllowPresaleStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPresaleStaking();
        vm.warp(block.timestamp + 2 hours);
        sMate.cancelChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unit_correct__admin_confirmChangeAllowPresaleStaking() external {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPresaleStaking();
        vm.warp(block.timestamp + 1 days + 1);
        sMate.confirmChangeAllowPresaleStaking();
        vm.stopPrank();
    }
}
