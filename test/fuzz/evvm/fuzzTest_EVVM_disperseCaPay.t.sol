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
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract fuzzTest_EVVM_disperseCaPay is Test, Constants {
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

    struct caPayFuzzTestInput {
        bytes32 salt;
        uint32 amountA;
        uint32 amountB;
        address token;
        bool isCaStaker;
    }

    function test__fuzz__disperseCaPay(
        caPayFuzzTestInput memory input
    ) external {
        vm.assume(input.amountA > 0 && input.amountB > 0);
        HelperCa c = new HelperCa{salt: input.salt}(address(evvm));
        if (input.isCaStaker) {
            evvm._setPointStaker(address(c), 0x01);
        }

        uint256 amountTotal = uint256(input.amountA) + uint256(input.amountB);

        addBalance(address(c), input.token, amountTotal);

        EvvmMockStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmMockStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: input.amountA,
            toAddress: COMMON_USER_NO_STAKER_1.Address
        });

        toData[1] = EvvmMockStructs.DisperseCaPayMetadata({
            amount: input.amountB,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        c.makeDisperseCaPay(toData, input.token, amountTotal);

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            input.amountA
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            input.amountB
        );

        assertEq(
            evvm.seeBalance(address(c), MATE_TOKEN_ADDRESS),
            input.isCaStaker ? evvm.seeMateReward() : 0
        );
    }
}

contract HelperCa {
    EvvmMock evvm;

    constructor(address _evvm) {
        evvm = EvvmMock(_evvm);
    }

    function makeDisperseCaPay(
        EvvmMockStructs.DisperseCaPayMetadata[] memory toData,
        address token,
        uint256 amount
    ) public {
        evvm.disperseCaPay(toData, token, amount);
    }
}
