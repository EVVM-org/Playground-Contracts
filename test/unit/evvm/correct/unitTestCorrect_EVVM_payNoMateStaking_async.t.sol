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

import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestCorrect_EVVM_payNoMateStaking_async is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(staking));
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

    /**
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nPF: No priority fee
     * EX: Includes executor execution
     * nEX: Does not include executor execution
     * ID: Uses a MNS identity
     * AD: Uses an address
     */

    function test__unit_correct__payNoMateStaking_async__nPF_nEX_AD() external {
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                1001001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            1001001,
            address(0),
            signatureEVVM
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__PF_nEX_AD() external {
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.00300001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                1001001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            1001001,
            address(0),
            signatureEVVM
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.00200001 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__nPF_EX_AD() external {
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                1001001,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            1001001,
            COMMON_USER_NO_STAKER_2.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__PF_EX_AD() external {
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.00300001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                1001001,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            1001001,
            COMMON_USER_NO_STAKER_2.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.00200001 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__nPF_nEX_ID() external {
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
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                1001001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            1001001,
            address(0),
            signatureEVVM
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__PF_nEX_ID() external {
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
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.00300001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                1001001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            1001001,
            address(0),
            signatureEVVM
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.00200001 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__nPF_EX_ID() external {
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
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                1001001,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            1001001,
            COMMON_USER_NO_STAKER_2.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );
    }

    function test__unit_correct__payNoMateStaking_async__PF_EX_ID() external {
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
        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.00300001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                1001001,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        evvm.payNoMateStaking_async(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            1001001,
            COMMON_USER_NO_STAKER_2.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.00200001 ether
        );
    }
}
