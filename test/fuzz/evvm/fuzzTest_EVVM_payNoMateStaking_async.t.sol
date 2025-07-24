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

import {SMate} from "@EVVM/playground/staking/SMate.sol";
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract fuzzTest_EVVM_payNoMateStaking_async is Test, Constants {
    SMate sMate;
    Evvm evvm;
    Estimator estimator;
    Mns mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMate(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new Mns(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mns));
        
        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
        mns._setIdentityBaseMetadata(
            "dummy",
            Mns.IdentityBaseMetadata({
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
     * ID: Uses a MNS identity
     * AD: Uses an address
     */

    struct PayNoMateStakingAsyncFuzzTestInput_nPF {
        bool useToAddress;
        bool useExecutor;
        bool useNoStaker3;
        address token;
        uint16 amount;
        uint176 nonce;
    }

    struct PayNoMateStakingAsyncFuzzTestInput_PF {
        bool useToAddress;
        bool useExecutor;
        bool useNoStaker3;
        address token;
        uint16 amount;
        uint16 priorityFee;
        uint176 nonce;
    }

    function test__fuzz__payNoMateStaking_async__nPF(
        PayNoMateStakingAsyncFuzzTestInput_nPF memory input
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
                input.nonce,
                true,
                input.useExecutor ? selectedExecuter.Address : address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            input.useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            input.useToAddress ? "" : "dummy",
            input.token,
            totalAmount,
            totalPriorityFee,
            input.nonce,
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

    function test__fuzz__payNoMateStaking_async__PF(
        PayNoMateStakingAsyncFuzzTestInput_PF memory input
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
                input.nonce,
                true,
                input.useExecutor ? selectedExecuter.Address : address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            input.useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            input.useToAddress ? "" : "dummy",
            input.token,
            totalAmount,
            totalPriorityFee,
            input.nonce,
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
