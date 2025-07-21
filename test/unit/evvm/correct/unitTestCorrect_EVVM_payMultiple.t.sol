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

import {EvvmMockStructs} from "@EVVM/playground/evvm/lib/EvvmMockStructs.sol";
import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/evvm/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/evvm/lib/EvvmMockStorage.sol";

contract unitTestCorrect_EVVM_payMultiple is Test, Constants, EvvmMockStructs {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new EvvmMock(ADMIN.Address, address(sMate));
        estimator = new EstimatorMock(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new MateNameServiceMock(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mns));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function addBalance(
        address user,
        address token,
        uint256 amount,
        uint256 priorityFee
    ) private {
        evvm._addBalance(user, token, amount + priorityFee);
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

    struct PaymultipleSignatureMetadata {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes signatureEVVM;
    }

    function test__unit_correct__payMultiple__nonStaker() external {
        mns._setIdentityBaseMetadata(
            "dummy",
            MateNameServiceMock.IdentityBaseMetadata({
                owner: COMMON_USER_NO_STAKER_2.Address,
                expireDate: block.timestamp + 366 days,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x00
            })
        );

        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.01 ether,
            0.00000004 ether
        );

        PaymultipleSignatureMetadata[]
            memory payDataSignature = new PaymultipleSignatureMetadata[](8);
        EvvmMockStructs.PayData[]
            memory payData = new EvvmMockStructs.PayData[](8);

        (
            payDataSignature[0].v,
            payDataSignature[0].r,
            payDataSignature[0].s
        ) = vm.sign(
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
        payDataSignature[0].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[0].v,
                payDataSignature[0].r,
                payDataSignature[0].s
            );

        payData[0] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 1001001,
            priority: true,
            executor: address(0),
            signature: payDataSignature[0].signatureEVVM
        });

        (
            payDataSignature[1].v,
            payDataSignature[1].r,
            payDataSignature[1].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                2002002,
                true,
                address(0)
            )
        );
        payDataSignature[1].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[1].v,
                payDataSignature[1].r,
                payDataSignature[1].s
            );

        payData[1] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 2002002,
            priority: true,
            executor: address(0),
            signature: payDataSignature[1].signatureEVVM
        });

        (
            payDataSignature[2].v,
            payDataSignature[2].r,
            payDataSignature[2].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                3003003,
                true,
                address(0)
            )
        );
        payDataSignature[2].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[2].v,
                payDataSignature[2].r,
                payDataSignature[2].s
            );

        payData[2] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 3003003,
            priority: true,
            executor: address(0),
            signature: payDataSignature[2].signatureEVVM
        });

        (
            payDataSignature[3].v,
            payDataSignature[3].r,
            payDataSignature[3].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                4004004,
                true,
                address(0)
            )
        );
        payDataSignature[3].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[3].v,
                payDataSignature[3].r,
                payDataSignature[3].s
            );

        payData[3] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 4004004,
            priority: true,
            executor: address(0),
            signature: payDataSignature[3].signatureEVVM
        });

        (
            payDataSignature[4].v,
            payDataSignature[4].r,
            payDataSignature[4].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                5005005,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        payDataSignature[4].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[4].v,
                payDataSignature[4].r,
                payDataSignature[4].s
            );

        payData[4] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 5005005,
            priority: true,
            executor: COMMON_USER_NO_STAKER_2.Address,
            signature: payDataSignature[4].signatureEVVM
        });

        (
            payDataSignature[5].v,
            payDataSignature[5].r,
            payDataSignature[5].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                6006006,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        payDataSignature[5].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[5].v,
                payDataSignature[5].r,
                payDataSignature[5].s
            );

        payData[5] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 6006006,
            priority: true,
            executor: COMMON_USER_NO_STAKER_2.Address,
            signature: payDataSignature[5].signatureEVVM
        });

        (
            payDataSignature[6].v,
            payDataSignature[6].r,
            payDataSignature[6].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                7007007,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        payDataSignature[6].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[6].v,
                payDataSignature[6].r,
                payDataSignature[6].s
            );

        payData[6] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 7007007,
            priority: true,
            executor: COMMON_USER_NO_STAKER_2.Address,
            signature: payDataSignature[6].signatureEVVM
        });

        (
            payDataSignature[7].v,
            payDataSignature[7].r,
            payDataSignature[7].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                8008008,
                true,
                COMMON_USER_NO_STAKER_2.Address
            )
        );
        payDataSignature[7].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[7].v,
                payDataSignature[7].r,
                payDataSignature[7].s
            );

        payData[7] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 8008008,
            priority: true,
            executor: COMMON_USER_NO_STAKER_2.Address,
            signature: payDataSignature[7].signatureEVVM
        });

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        (
            uint256 successfulTransactions,
            uint256 failedTransactions,
            bool[] memory status
        ) = evvm.payMultiple(payData);
        vm.stopPrank();

        for (uint256 i = 0; i < status.length; i++) {
            if (status[i]) {
                console2.log("Transaction ", i, " was successful");
            } else {
                console2.log("Transaction ", i, " failed");
            }
        }


        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.00200004 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.008 ether
        );

    }

    
    function test_payMultiple_staker() external {
        mns._setIdentityBaseMetadata(
            "dummy",
            MateNameServiceMock.IdentityBaseMetadata({
                owner: COMMON_USER_NO_STAKER_2.Address,
                expireDate: block.timestamp + 366 days,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x00
            })
        );

        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.01 ether,
            0.00000004 ether
        );
        PaymultipleSignatureMetadata[]
            memory payDataSignature = new PaymultipleSignatureMetadata[](8);
        EvvmMockStructs.PayData[]
            memory payData = new EvvmMockStructs.PayData[](8);

        (
            payDataSignature[0].v,
            payDataSignature[0].r,
            payDataSignature[0].s
        ) = vm.sign(
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
        payDataSignature[0].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[0].v,
                payDataSignature[0].r,
                payDataSignature[0].s
            );

        payData[0] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 1001001,
            priority: true,
            executor: address(0),
            signature: payDataSignature[0].signatureEVVM
        });

        (
            payDataSignature[1].v,
            payDataSignature[1].r,
            payDataSignature[1].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                2002002,
                true,
                address(0)
            )
        );
        payDataSignature[1].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[1].v,
                payDataSignature[1].r,
                payDataSignature[1].s
            );

        payData[1] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 2002002,
            priority: true,
            executor: address(0),
            signature: payDataSignature[1].signatureEVVM
        });

        (
            payDataSignature[2].v,
            payDataSignature[2].r,
            payDataSignature[2].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                3003003,
                true,
                address(0)
            )
        );
        payDataSignature[2].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[2].v,
                payDataSignature[2].r,
                payDataSignature[2].s
            );

        payData[2] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 3003003,
            priority: true,
            executor: address(0),
            signature: payDataSignature[2].signatureEVVM
        });

        (
            payDataSignature[3].v,
            payDataSignature[3].r,
            payDataSignature[3].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                4004004,
                true,
                address(0)
            )
        );
        payDataSignature[3].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[3].v,
                payDataSignature[3].r,
                payDataSignature[3].s
            );

        payData[3] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 4004004,
            priority: true,
            executor: address(0),
            signature: payDataSignature[3].signatureEVVM
        });

        (
            payDataSignature[4].v,
            payDataSignature[4].r,
            payDataSignature[4].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                5005005,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        payDataSignature[4].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[4].v,
                payDataSignature[4].r,
                payDataSignature[4].s
            );

        payData[4] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 5005005,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: payDataSignature[4].signatureEVVM
        });

        (
            payDataSignature[5].v,
            payDataSignature[5].r,
            payDataSignature[5].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                6006006,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        payDataSignature[5].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[5].v,
                payDataSignature[5].r,
                payDataSignature[5].s
            );

        payData[5] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 6006006,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: payDataSignature[5].signatureEVVM
        });

        (
            payDataSignature[6].v,
            payDataSignature[6].r,
            payDataSignature[6].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                7007007,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        payDataSignature[6].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[6].v,
                payDataSignature[6].r,
                payDataSignature[6].s
            );

        payData[6] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0,
            nonce: 7007007,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: payDataSignature[6].signatureEVVM
        });

        (
            payDataSignature[7].v,
            payDataSignature[7].r,
            payDataSignature[7].s
        ) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                8008008,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        payDataSignature[7].signatureEVVM = Erc191TestBuilder
            .buildERC191Signature(
                payDataSignature[7].v,
                payDataSignature[7].r,
                payDataSignature[7].s
            );

        payData[7] = EvvmMockStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "dummy",
            token: ETHER_ADDRESS,
            amount: 0.001 ether,
            priorityFee: 0.00000001 ether,
            nonce: 8008008,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: payDataSignature[7].signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);
        (
            uint256 successfulTransactions,
            uint256 failedTransactions,
            bool[] memory status
        ) = evvm.payMultiple(payData);
        vm.stopPrank();

        for (uint256 i = 0; i < status.length; i++) {
            if (status[i]) {
                console2.log("Transaction ", i, " was successful");
            } else {
                console2.log("Transaction ", i, " failed");
            }
        }

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.008 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() * 8
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, ETHER_ADDRESS),
            0.00000004 ether
        );
    }
    
}
