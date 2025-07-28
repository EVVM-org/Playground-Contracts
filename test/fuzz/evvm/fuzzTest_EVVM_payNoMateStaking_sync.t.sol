// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

/**

:::::::::: :::    ::: ::::::::: :::::::::      ::::::::::: :::::::::: :::::::: ::::::::::: 
:+:        :+:    :+:      :+:       :+:           :+:     :+:       :+:    :+:    :+:     
+:+        +:+    +:+     +:+       +:+            +:+     +:+       +:+           +:+     
:#::+::#   +#+    +:+    +#+       +#+             +#+     +#++:++#  +#++:++#++    +#+     
+#+        +#+    +#+   +#+       +#+              +#+     +#+              +#+    +#+     
#+#        #+#    #+#  #+#       #+#               #+#     #+#       #+#    #+#    #+#     
###         ########  ######### #########          ###     ########## ########     ###     

 * @title unit test for EVVM function correct behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";

import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

contract fuzzTest_EVVM_payNoMateStaking_sync is Test, Constants {
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

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
        nameService._setIdentityBaseMetadata(
            "dummy",
            NameService.IdentityBaseMetadata({
                owner: COMMON_USER_NO_STAKER_2.Address,
                expireDate: block.timestamp + 366 days,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x00
            })
        );
    }

    function addBalance(
        AccountData memory user,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee
    ) private returns (uint256 totalAmount, uint256 totalPriorityFee) {
        evvm._addBalance(user.Address, tokenAddress, amount + priorityFee);

        totalAmount = amount;
        totalPriorityFee = priorityFee;
    }

    /**
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nPF: No priority fee
     * EX: Includes executor execution
     * nEX: Does not include executor execution
     * ID: Uses a NameService identity
     * AD: Uses an address
     */

    struct PayNoMateStakingSyncFuzzTestInput_nPF {
        bool useToAddress;
        bool useExecutor;
        bool useNoStaker3;
        address token;
        uint16 amount;
    }

    struct PayNoMateStakingSyncFuzzTestInput_PF {
        bool useToAddress;
        bool useExecutor;
        bool useNoStaker3;
        address token;
        uint16 amount;
        uint16 priorityFee;
    }

    function test__fuzz__payNoMateStaking_sync__nPF(
        PayNoMateStakingSyncFuzzTestInput_nPF memory input
    ) external {
        vm.assume(input.amount > 0);

        AccountData memory selectedExecuter = input.useNoStaker3
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_3;

        (uint256 totalAmount, uint256 totalPriorityFee) = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.token,
            input.amount,
            0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                input.useToAddress
                    ? COMMON_USER_NO_STAKER_2.Address
                    : address(0),
                input.useToAddress ? "" : "dummy",
                input.token,
                totalAmount,
                totalPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                input.useExecutor ? selectedExecuter.Address : address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            input.useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            input.useToAddress ? "" : "dummy",
            input.token,
            totalAmount,
            totalPriorityFee,
            input.useExecutor ? selectedExecuter.Address : address(0),
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            0
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            totalAmount
        );
    }

    function test__fuzz__payNoMateStaking_sync__PF(
        PayNoMateStakingSyncFuzzTestInput_PF memory input
    ) external {
        vm.assume(input.amount > 0);

        AccountData memory selectedExecuter = input.useNoStaker3
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_3;

        (uint256 totalAmount, uint256 totalPriorityFee) = addBalance(
            COMMON_USER_NO_STAKER_1,
            input.token,
            input.amount,
            input.priorityFee
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                input.useToAddress
                    ? COMMON_USER_NO_STAKER_2.Address
                    : address(0),
                input.useToAddress ? "" : "dummy",
                input.token,
                totalAmount,
                totalPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                input.useExecutor ? selectedExecuter.Address : address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            input.useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            input.useToAddress ? "" : "dummy",
            input.token,
            totalAmount,
            totalPriorityFee,
            input.useExecutor ? selectedExecuter.Address : address(0),
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            totalPriorityFee
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            totalAmount
        );
    }
}
