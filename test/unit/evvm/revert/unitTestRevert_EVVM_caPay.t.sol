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

contract unitTestRevert_EVVM_caPay is Test, Constants {
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
        evvm._setupNameServiceAddress(address(nameService));

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function addBalance(address user, address token, uint256 amount) private {
        evvm._addBalance(user, token, amount);
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     */

    function test__unit_revert__caPay__addressHasZeroOpcode() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.001 ether);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        evvm.caPay(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS, 0.001 ether);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.001 ether
        );
    }

    function test__unit_revert__caPay__addressHasLessThanAmount() external {
        addBalance(address(this), ETHER_ADDRESS, 0.001 ether);

        vm.expectRevert();
        evvm.caPay(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS, 0.1 ether);

        assertEq(evvm.getBalance(address(this), ETHER_ADDRESS), 0.001 ether);
    }
}
