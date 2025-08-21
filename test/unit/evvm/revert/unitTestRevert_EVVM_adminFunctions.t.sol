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
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
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
        evvm._setupNameServiceAndTreasuryAddress(address(nameService), address(treasury));

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function addBalance(address user, address token, uint256 amount) private {
        evvm._addBalance(user, token, amount);
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

    function test__unit_revert__prepareTokenToBeWhitelisted__nAdm() external {
        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.stopPrank();
    }

    function test__unit_revert__addTokenToWhitelist__nAdm() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.addTokenToWhitelist();

        vm.stopPrank();
    }

    function test__unit_revert__addTokenToWhitelist__notInTime() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.warp(block.timestamp + 10 hours);

        vm.expectRevert();
        evvm.addTokenToWhitelist();

        vm.stopPrank();
    }

    function test__unit_revert__cancelPrepareTokenToBeWhitelisted__nAdm()
        external
    {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.cancelPrepareTokenToBeWhitelisted();

        vm.stopPrank();
    }

    function test__unit_revert__changePool__nAdm() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            address(0)
        );

        vm.warp(block.timestamp + 1 days);

        evvm.addTokenToWhitelist();

        vm.stopPrank();

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.changePool(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.stopPrank();
    }

    modifier setTestAddress() {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.warp(block.timestamp + 1 days);

        evvm.addTokenToWhitelist();

        vm.stopPrank();
        _;
    }

    function test__unit_revert__removeTokenWhitelist__nAdm()
        external
        setTestAddress
    {
        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.removeTokenWhitelist(0xdAC17F958D2ee523a2206206994597C13D831ec7);

        vm.stopPrank();
    }

    function test__unit_revert__prepareMaxAmountToWithdraw__nAdm() external {
        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.prepareMaxAmountToWithdraw(1 ether);

        vm.stopPrank();
    }

    function test__unit_revert__cancelPrepareMaxAmountToWithdraw__nAdm()
        external
    {
        vm.startPrank(ADMIN.Address);

        evvm.prepareMaxAmountToWithdraw(1 ether);

        vm.stopPrank();

        vm.warp(block.timestamp + 10 hours);

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.cancelPrepareMaxAmountToWithdraw();

        vm.stopPrank();
    }

    function test__unit_revert__getMaxAmountToWithdraw__nAdm() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareMaxAmountToWithdraw(1 ether);

        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(COMMON_USER.Address);

        vm.expectRevert();
        evvm.setMaxAmountToWithdraw();

        vm.stopPrank();
    }

    function test__unit_revert__getMaxAmountToWithdraw__notInTime() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareMaxAmountToWithdraw(1 ether);

        vm.warp(block.timestamp + 10 hours);

        vm.expectRevert();
        evvm.setMaxAmountToWithdraw();

        vm.stopPrank();
    }
}
