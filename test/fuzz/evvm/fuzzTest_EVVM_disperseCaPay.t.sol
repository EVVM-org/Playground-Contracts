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
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

contract fuzzTest_EVVM_disperseCaPay is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
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

        EvvmStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmStructs.DisperseCaPayMetadata({
            amount: input.amountA,
            toAddress: COMMON_USER_NO_STAKER_1.Address
        });

        toData[1] = EvvmStructs.DisperseCaPayMetadata({
            amount: input.amountB,
            toAddress: COMMON_USER_NO_STAKER_2.Address
        });

        c.makeDisperseCaPay(toData, input.token, amountTotal);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            input.amountA
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            input.amountB
        );

        assertEq(
            evvm.getBalance(address(c), MATE_TOKEN_ADDRESS),
            input.isCaStaker ? evvm.getRewardAmount() : 0
        );
    }
}

contract HelperCa {
    Evvm evvm;

    constructor(address _evvm) {
        evvm = Evvm(_evvm);
    }

    function makeDisperseCaPay(
        EvvmStructs.DisperseCaPayMetadata[] memory toData,
        address token,
        uint256 amount
    ) public {
        evvm.disperseCaPay(toData, token, amount);
    }
}
