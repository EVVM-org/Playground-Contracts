// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function revert behavior
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
import {Erc191TestBuilder} from "@EVVM/playground/library/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract unitTestRevert_EVVM_adminFunctions is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

    AccountData COMMON_USER = WILDCARD_USER;

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
        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasury)
        );

        evvm.setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function addBalance(address user, address token, uint256 amount) private {
        evvm.addBalance(user, token, amount);
    }

    /**
     * Function to test:
     * nAdm: No admin execute the function
     * nNewAdm: No new admin execute the function
     * notInTime: Not in time to execute the function
     *
     */

    function test__unit_revert__proposeOwner__nAdm() external {
        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.proposeAdmin(COMMON_USER.Address);

        vm.stopPrank();
    }

    function test__unit_revert__proposeOwner__adminProposeHimself() external {
        vm.startPrank(ADMIN.Address);

        vm.expectRevert();
        evvm.proposeAdmin(ADMIN.Address);

        vm.stopPrank();
    }

    function test__unit_revert__acceptOwner__notInTime() external {
        vm.startPrank(ADMIN.Address);

        evvm.proposeAdmin(COMMON_USER.Address);

        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.acceptAdmin();

        vm.stopPrank();
    }

    function test__unit_revert__acceptOwner__nNewAdm() external {
        vm.startPrank(ADMIN.Address);

        evvm.proposeAdmin(COMMON_USER.Address);

        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(ADMIN.Address);

        vm.expectRevert();
        evvm.acceptAdmin();

        vm.stopPrank();
    }

    function test__unit_revert__rejectProposalOwner__nAdm() external {
        vm.startPrank(ADMIN.Address);

        evvm.proposeAdmin(COMMON_USER.Address);

        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.rejectProposalAdmin();

        vm.stopPrank();
    }

    function test__unit_revert__setEvvmID__nAdm() external {
        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.setEvvmID(888);

        vm.stopPrank();
    }

    function test__unit_revert__setEvvmID__WindowToChangeEvvmIDExpired() external {
        vm.startPrank(ADMIN.Address);

        evvm.setEvvmID(888);

        skip(24 hours + 1 seconds);
        vm.expectRevert();
        evvm.setEvvmID(777);

        vm.stopPrank();
    }
}
