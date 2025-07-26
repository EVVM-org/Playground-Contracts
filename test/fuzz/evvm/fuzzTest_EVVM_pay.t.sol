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
import {EVVM} from "@EVVM/playground/evvm/EVVM.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

contract fuzzTest_EVVM_pay is Test, Constants, EvvmStructs {
    Staking staking;
    EVVM evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new EVVM(ADMIN.Address, address(staking));
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

    function makeSignaturePay(
        AccountData memory user,
        address toAddress,
        string memory toIdentity,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        address executor
    ) private pure returns (bytes memory signatureEVVM) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                toAddress,
                toIdentity,
                tokenAddress,
                amount,
                priorityFee,
                nonce,
                priorityFlag,
                executor
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
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

    function test__unit_correct__pay(
        bool useStaker,
        bool useToAddress,
        bool useExecutor,
        address token,
        uint16 amount,
        uint16 priorityFee,
        uint176 nonce,
        bool priorityFlag
    ) external {
        vm.assume(amount > 0 && token != MATE_TOKEN_ADDRESS);

        AccountData memory FISHER = useStaker
            ? COMMON_USER_STAKER
            : COMMON_USER_NO_STAKER_3;

        bytes memory signature = makeSignaturePay(
            COMMON_USER_NO_STAKER_1,
            useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            useToAddress ? "" : "dummy",
            token,
            amount,
            priorityFee,
            priorityFlag
                ? nonce
                : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            priorityFlag,
            useExecutor ? FISHER.Address : address(0)
        );

        addBalance(COMMON_USER_NO_STAKER_1, token, amount, priorityFee);

        vm.startPrank(FISHER.Address);
        evvm.pay(
            COMMON_USER_NO_STAKER_1.Address,
            useToAddress ? COMMON_USER_NO_STAKER_2.Address : address(0),
            useToAddress ? "" : "dummy",
            token,
            amount,
            priorityFee,
            nonce,
            priorityFlag,
            useExecutor ? FISHER.Address : address(0),
            signature
        );
        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, token),
            amount
        );

        if (FISHER.Address == COMMON_USER_STAKER.Address) {
            assertEq(
                evvm.getBalance(COMMON_USER_STAKER.Address, token),
                priorityFee
            );

            assertEq(
                evvm.getBalance(FISHER.Address, MATE_TOKEN_ADDRESS),
                evvm.getRewardAmount()
            );
        } else {
            assertEq(
                evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, token),
                priorityFee
            );

            assertEq(
                evvm.getBalance(
                    COMMON_USER_NO_STAKER_3.Address,
                    MATE_TOKEN_ADDRESS
                ),
                0
            );
        }

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, token),
            amount
        );
    }
}
