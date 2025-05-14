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
import {EvvmMockStructs} from "@EVVM/playground/core/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";

contract unitTestRevert_EVVM_disperseCaPay is Test, Constants {
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

    function test__unit_revert__disperseCaPay__addressHasZeroOpcode() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.02 ether);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.01 ether,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.01 ether,
            toAddress: COMMON_USER_NO_STAKER_3.Address
        });

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        evvm.disperseCaPay(toData, ETHER_ADDRESS, 0.02 ether);

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.02 ether
        );
    }

    function test__unit_revert__disperseCaPay__addressHasLessThanAmount()
        external
    {
        addBalance(address(this), ETHER_ADDRESS, 0.002 ether);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.01 ether,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.01 ether,
            toAddress: COMMON_USER_NO_STAKER_3.Address
        });

        vm.expectRevert();
        evvm.disperseCaPay(toData, ETHER_ADDRESS, 0.02 ether);

        assertEq(evvm.seeBalance(address(this), ETHER_ADDRESS), 0.002 ether);
    }

    function test__unit_revert__disperseCaPay__AmountDeclaredLessThanMetadataTot()
        external
    {
        addBalance(address(this), ETHER_ADDRESS, 0.02 ether);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.1 ether,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.1 ether,
            toAddress: COMMON_USER_NO_STAKER_3.Address
        });

        vm.expectRevert();
        evvm.disperseCaPay(toData, ETHER_ADDRESS, 0.02 ether);

        assertEq(evvm.seeBalance(address(this), ETHER_ADDRESS), 0.02 ether);
    }

    function test__unit_revert__disperseCaPay__MetadataTotLessThanAmountDeclared()
        external
    {
        addBalance(address(this), ETHER_ADDRESS, 0.02 ether);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.01 ether,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: 0.01 ether,
            toAddress: COMMON_USER_NO_STAKER_3.Address
        });

        vm.expectRevert();
        evvm.disperseCaPay(toData, ETHER_ADDRESS, 0.2 ether);

        assertEq(evvm.seeBalance(address(this), ETHER_ADDRESS), 0.02 ether);
    }
}
