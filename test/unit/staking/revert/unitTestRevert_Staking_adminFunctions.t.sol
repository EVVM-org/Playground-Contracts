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
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract unitTestRevert_Staking_adminFunctions is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: 777,
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
        treasury = new Treasury(address(evvm));
        evvm._setupNameServiceAndTreasuryAddress(address(nameService), address(treasury));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function test__unitRevert__addPresaleStaker__nonOwner() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.addPresaleStaker(COMMON_USER_NO_STAKER_1.Address);
        vm.stopPrank();
    }

    function test__unitRevert__addPresaleStakers__nonOwner() external {
        address[] memory stakers = new address[](2);
        stakers[0] = makeAddr("alice");
        stakers[1] = makeAddr("bob");

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.addPresaleStakers(stakers);
        vm.stopPrank();
    }

    function test__unitRevert__proposeAdmin__nonOwner() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unitRevert__rejectProposalAdmin__nonOwner() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.rejectProposalAdmin();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewAdmin__nonNewOwner() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(ADMIN.Address);
        vm.expectRevert();
        staking.acceptNewAdmin();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewAdmin__notInTime() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeAdmin(WILDCARD_USER.Address);
        vm.stopPrank();
        vm.warp(block.timestamp + 10 hours);
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.acceptNewAdmin();
        vm.stopPrank();
    }

    function test__unitRevert__proposeGoldenFisher__nonOwner() external {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.stopPrank();
    }

    function test__unitRevert__rejectProposalGoldenFisher__nonOwner() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 2 hours);
        vm.stopPrank();
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.rejectProposalGoldenFisher();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewGoldenFisher__nonOwner() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.acceptNewGoldenFisher();
        vm.stopPrank();
    }

    function test__unitRevert__acceptNewGoldenFisher__notInTime() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeGoldenFisher(WILDCARD_USER.Address);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        staking.acceptNewGoldenFisher();
        vm.stopPrank();
    }

    function test__unitRevert__proposeSetSecondsToUnlockStaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();
    }

    function test__unitRevert__rejectProposalSetSecondsToUnlockStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.rejectProposalSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unitRevert__acceptSetSecondsToUnlockStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.proposeSetSecondsToUnlockStaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unitRevert__acceptSetSecondsToUnlockStaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.proposeSetSecondsToUnlockStaking(2 days);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        staking.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();
    }

    function test__unitRevert__prepareSetSecondsToUnllockFullUnstaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();
    }

    function test__unitRevert__cancelSetSecondsToUnllockFullUnstaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.cancelSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmSetSecondsToUnllockFullUnstaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.confirmSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmSetSecondsToUnllockFullUnstaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareSetSecondsToUnllockFullUnstaking(2 days);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        staking.confirmSetSecondsToUnllockFullUnstaking();
        vm.stopPrank();
    }

    function test__unitRevert__prepareChangeAllowPublicStaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.prepareChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__cancelChangeAllowPublicStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareChangeAllowPublicStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.cancelChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPublicStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareChangeAllowPublicStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.confirmChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPublicStaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareChangeAllowPublicStaking();
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        staking.confirmChangeAllowPublicStaking();
        vm.stopPrank();
    }

    function test__unitRevert__prepareChangeAllowPresaleStaking__nonOwner()
        external
    {
        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.prepareChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unitRevert__cancelChangeAllowPresaleStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareChangeAllowPresaleStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.cancelChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPresaleStaking__nonOwner()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareChangeAllowPresaleStaking();
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert();
        staking.confirmChangeAllowPresaleStaking();
        vm.stopPrank();
    }

    function test__unitRevert__confirmChangeAllowPresaleStaking__notInTime()
        external
    {
        vm.startPrank(ADMIN.Address);
        staking.prepareChangeAllowPresaleStaking();
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert();
        staking.confirmChangeAllowPresaleStaking();
        vm.stopPrank();
    }
}
