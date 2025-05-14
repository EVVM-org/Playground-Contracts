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

import {SMateMock} from "@EVVM/Playground/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/Playground/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/Playground/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/Playground/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/Playground/EvvmMockStorage.sol";

contract fuzzTest_EVVM_caPay is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

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

    struct caPayFuzzTestInput {
        bytes32 salt;
        uint32 amount;
        address token;
        bool isCaStaker;
    }

    function test__fuzz__caPay(
        caPayFuzzTestInput memory input
    ) external {
        vm.assume(input.amount > 0);
        HelperCa c = new HelperCa{salt: input.salt}(address(evvm));
        if (input.isCaStaker) {
            evvm._setPointStaker(address(c), 0x01);
        }

        addBalance(address(c), input.token, input.amount);

        c.makeCaPay(COMMON_USER_NO_STAKER_1.Address, input.token, input.amount);
    
        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            input.amount
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

    function makeCaPay(address user, address token, uint256 amount) public {
        evvm.caPay(user, token, amount);
    }
}
