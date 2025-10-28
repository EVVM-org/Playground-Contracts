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

import {Constants, MockContractToStake} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/library/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";
import {ErrorsLib} from "@EVVM/playground/contracts/staking/lib/ErrorsLib.sol";

contract unitTestRevert_Staking_serviceStaking is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    MockContractToStake mockContract;
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
        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasury)
        );

        evvm.setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        staking.prepareChangeAllowPublicStaking();
        skip(1 days);
        staking.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        mockContract = new MockContractToStake(address(staking));
    }

    function giveMateToExecute(
        address user,
        uint256 stakingAmount
    ) private returns (uint256 totalOfMate) {
        evvm.addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (staking.priceOfStaking() * stakingAmount)
        );

        totalOfMate = (staking.priceOfStaking() * stakingAmount);
    }

    function test__unit_revert__publicServiceStaking__prepareServiceStaking__AddressIsNotAService()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        giveMateToExecute(WILDCARD_USER.Address, 10);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert(ErrorsLib.AddressIsNotAService.selector);
        staking.prepareServiceStaking(10);
        vm.stopPrank();

        assert(!evvm.isAddressStaker(address(WILDCARD_USER.Address)));

        assertEq(
            evvm.getBalance(address(WILDCARD_USER.Address), MATE_TOKEN_ADDRESS),
            staking.priceOfStaking() * 10
        );

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore
        );

        assertEq(staking.getSizeOfAddressHistory(WILDCARD_USER.Address), 0);
    }

    function test__unit_revert__publicServiceStaking__confirmServiceStaking__AddressIsNotAService()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        uint256 amountStaking = giveMateToExecute(WILDCARD_USER.Address, 10);

        vm.startPrank(WILDCARD_USER.Address);
        vm.expectRevert(ErrorsLib.AddressIsNotAService.selector);
        staking.confirmServiceStaking();
        vm.stopPrank();

        assert(!evvm.isAddressStaker(address(WILDCARD_USER.Address)));

        assertEq(
            evvm.getBalance(address(WILDCARD_USER.Address), MATE_TOKEN_ADDRESS),
            amountStaking
        );

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore
        );

        assertEq(staking.getSizeOfAddressHistory(WILDCARD_USER.Address), 0);
    }

    function test__unit_revert__publicServiceStaking__confirmServiceStaking__ServiceDoesNotFulfillCorrectStakingAmount()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        uint256 amountStaking = giveMateToExecute(address(mockContract), 10);

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.ServiceDoesNotFulfillCorrectStakingAmount.selector,
                (5 * staking.priceOfStaking())
            )
        );
        mockContract.stakeWithAmountDiscrepancy(10, 5);

        assert(!evvm.isAddressStaker(address(mockContract)));

        assertEq(
            evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS),
            amountStaking
        );

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore
        );

        assertEq(staking.getSizeOfAddressHistory(address(mockContract)), 0);
    }

    function test__unit_revert__publicServiceStaking__confirmServiceStaking__ServiceDoesNotStakeInSameTx()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        uint256 amountStaking = giveMateToExecute(address(mockContract), 10);

        mockContract.stakeJustInPartTwo(10);

        skip(1);

        vm.expectRevert(ErrorsLib.ServiceDoesNotStakeInSameTx.selector);
        mockContract.stakeJustConfirm();

        assert(!evvm.isAddressStaker(address(mockContract)));

        assertEq(evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS), 0);

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore + amountStaking
        );

        assertEq(staking.getSizeOfAddressHistory(address(mockContract)), 0);
    }

    function test__unit_revert__publicServiceStaking__confirmServiceStaking__AddressMismatch()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        MockContractToStake auxMockContract = new MockContractToStake(
            address(staking)
        );

        uint256 amountStaking = giveMateToExecute(address(mockContract), 10);

        giveMateToExecute(address(auxMockContract), 10);

        mockContract.stakeJustInPartTwo(10);

        vm.expectRevert(ErrorsLib.AddressMismatch.selector);
        auxMockContract.stakeJustConfirm();

        assert(!evvm.isAddressStaker(address(mockContract)));

        assertEq(evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS), 0);

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore + amountStaking
        );

        assertEq(staking.getSizeOfAddressHistory(address(mockContract)), 0);
    }

    /*
    function test__unit_revert__publicServiceStaking__confirmServiceStaking__()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        giveMateToExecute(address(mockContract), 10);

        mockContract.stake(10);

        assert(!evvm.isAddressStaker(address(mockContract)));

        assertEq(
            evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS),
            staking.priceOfStaking() * 5
        );

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore
        );

        assertEq(staking.getSizeOfAddressHistory(address(mockContract)), 0);
    }

    function test__unit_revert__publicServiceStaking__unstake() external {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        giveMateToExecute(address(mockContract), 10);

        mockContract.stake(10);

        assert(evvm.isAddressStaker(address(mockContract)));

        mockContract.unstake(5);

        assert(evvm.isAddressStaker(address(mockContract)));

        assertEq(
            evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS),
            staking.priceOfStaking() * 5
        );

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore +
                (staking.priceOfStaking() * 5) +
                evvm.getRewardAmount()
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(address(mockContract))
            );

        history = staking.getAddressHistory(address(mockContract));

        assertEq(history[0].timestamp, block.timestamp);
        assert(history[0].transactionType == DEPOSIT_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[0].amount, 10);
        assertEq(history[0].totalStaked, 10);

        assertEq(history[1].timestamp, block.timestamp);
        assert(history[1].transactionType == WITHDRAW_HISTORY_SMATE_IDENTIFIER);
        assertEq(history[1].amount, 5);
        assertEq(history[1].totalStaked, 5);
    }

    function test__unit_revert__publicServiceStaking__fullUnstake() external {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        giveMateToExecute(address(mockContract), 10);

        mockContract.stake(10);

        assert(evvm.isAddressStaker(address(mockContract)));

        skip(staking.getSecondsToUnlockFullUnstaking());

        mockContract.unstake(10);

        assert(!evvm.isAddressStaker(address(mockContract)));

        assertEq(
            evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS),
            staking.priceOfStaking() * 10
        );

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore + evvm.getRewardAmount()
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(address(mockContract))
            );

        history = staking.getAddressHistory(address(mockContract));

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

    function test__unit_revert__publicServiceStaking__stakeAfterFullUnstake()
        external
    {
        uint256 amountStakingBefore = evvm.getBalance(
            address(staking),
            MATE_TOKEN_ADDRESS
        );

        giveMateToExecute(address(mockContract), 10);

        mockContract.stake(10);

        assert(evvm.isAddressStaker(address(mockContract)));

        skip(staking.getSecondsToUnlockFullUnstaking());

        mockContract.unstake(10);

        skip(staking.getSecondsToUnlockStaking());

        mockContract.stake(10);

        assert(evvm.isAddressStaker(address(mockContract)));

        assertEq(evvm.getBalance(address(mockContract), MATE_TOKEN_ADDRESS), 0);

        assertEq(
            evvm.getBalance(address(staking), MATE_TOKEN_ADDRESS),
            amountStakingBefore +
                (staking.priceOfStaking() * 10) +
                evvm.getRewardAmount()
        );

        Staking.HistoryMetadata[]
            memory history = new Staking.HistoryMetadata[](
                staking.getSizeOfAddressHistory(address(mockContract))
            );

        history = staking.getAddressHistory(address(mockContract));

        assertEq(
            history[0].timestamp,
            block.timestamp -
                staking.getSecondsToUnlockFullUnstaking() -
                staking.getSecondsToUnlockStaking()
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
    */
}
