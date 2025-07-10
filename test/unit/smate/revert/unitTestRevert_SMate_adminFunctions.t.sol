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
import {EvvmMockStructs} from "@EVVM/playground/core/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";

contract unitTestRevert_SMate_adminFunctions is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

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

    function test__unitRevert__addPresaleStaker__nonOwner() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.addPresaleStaker(COMMON_USER_NO_STAKER_1.Address);
        vm.stopPrank();
    }

    function test__unitRevert__addPresaleStakers__nonOwner() external {
        address[] memory stakers = new address[](2);
        stakers[0] = makeAddr("alice");
        stakers[1] = makeAddr("bob");

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.addPresaleStakers(stakers);
        vm.stopPrank();
    }

    function test__unitRevert__proposeAdmin__nonOwner() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unitRevert__rejectProposalAdmin__nonOwner() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.rejectProposalAdmin();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewAdmin__nonNewOwner() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        sMate.acceptNewAdmin();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewAdmin__notInTime() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
        vm.warp(block.timestamp + 10 hours);
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.acceptNewAdmin();
        vm.stopPrank();
    }

    function test__unitRevert__proposeGoldenFisher__nonOwner() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unitRevert__rejectProposalGoldenFisher__nonOwner() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 2 hours);
        vm.stopPrank();
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.rejectProposalGoldenFisher();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewGoldenFisher__nonOwner() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.acceptNewGoldenFisher();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewGoldenFisher__notInTime() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        sMate.acceptNewGoldenFisher();
        vm.stopPrank();
    }

    function test__unitRevert__proposeSetSecondsToUnlockStaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();
    }

    function test__unitRevert__rejectProposalSetSecondsToUnlockStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.rejectProposalSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unitRevert__acceptSetSecondsToUnlockStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unitRevert__acceptSetSecondsToUnlockStaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(2 days);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        sMate.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unitRevert__prepareSetSecondsToUnllockFullUnstaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();
    }

    function test__unitRevert__cancelSetSecondsToUnllockFullUnstaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.cancelSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmSetSecondsToUnllockFullUnstaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.confirmSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmSetSecondsToUnllockFullUnstaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        sMate.confirmSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unitRevert__prepareChangeAllowPublicStaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.prepareChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__cancelChangeAllowPublicStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPublicStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.cancelChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPublicStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPublicStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.confirmChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPublicStaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPublicStaking();
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        sMate.confirmChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__prepareChangeAllowPresaleStaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.prepareChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unitRevert__cancelChangeAllowPresaleStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPresaleStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.cancelChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPresaleStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPresaleStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        sMate.confirmChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPresaleStaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.prepareChangeAllowPresaleStaking();
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        sMate.confirmChangeAllowPresaleStaking();
        vm.stopPrank();
    }
}
