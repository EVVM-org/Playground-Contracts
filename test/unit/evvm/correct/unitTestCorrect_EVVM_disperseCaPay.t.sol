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
import {EvvmMockStructs} from "@EVVM/playground/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/EvvmMockStorage.sol";

contract unitTestCorrect_EVVM_disperseCaPay is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());
    }

    function addBalance(address user, address token, uint256 amount) private {
        evvm._addBalance(user, token, amount);
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     */

    ///@dev because this script behaves like a smart contract we can use caPay
    ///     and disperseCaPay without any problem

    function test__unit_correct__disperseCaPay__nS() external {
        addBalance(address(this), ETHER_ADDRESS, 0.001 ether);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.000001 ether,
            toAddress: COMMON_USER_NO_STAKER_1.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.000001 ether,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        evvm.disperseCaPay(toData, ETHER_ADDRESS, 0.000002 ether);

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.000001 ether
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.000001 ether
        );
    }

    function test__unit_correct__disperseCaPay__S() external {
        addBalance(address(this), ETHER_ADDRESS, 0.001 ether);
        evvm._setPointStaker(address(this), 0x01);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.000001 ether,
            toAddress: COMMON_USER_NO_STAKER_1.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.000001 ether,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        evvm.disperseCaPay(toData, ETHER_ADDRESS, 0.000002 ether);

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.000001 ether
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.000001 ether
        );
        assertEq(
            evvm.seeBalance(address(this), MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );
    }
}
