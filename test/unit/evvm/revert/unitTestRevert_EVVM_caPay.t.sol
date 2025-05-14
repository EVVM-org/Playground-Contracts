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
import {EvvmMockStructs} from "@EVVM/playground/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/EvvmMockStorage.sol";

contract unitTestRevert_EVVM_caPay is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());

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
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.001 ether
        );
    }

    function test__unit_revert__caPay__addressHasLessThanAmount() external {
        addBalance(address(this), ETHER_ADDRESS, 0.001 ether);

        vm.expectRevert();
        evvm.caPay(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS, 0.1 ether);

        assertEq(evvm.seeBalance(address(this), ETHER_ADDRESS), 0.001 ether);
    }
}
