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

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";

contract unitTestCorrect_EVVM_payMateStaking_sync is Test, Constants {
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

    function test__unit_correct__payMateStaking_sync__nPF_nEX_AD() external {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether,
            0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                0,
                false,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            address(0),
            signatureEVVM
        );
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );
    }

    function test__unit_correct__payMateStaking_sync__PF_nEX_AD() external {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether,
            0.00000001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                0,
                false,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            address(0),
            signatureEVVM
        );
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, ETHER_ADDRESS),
            0.00000001 ether
        );
    }

    function test__unit_correct__payMateStaking_sync__nPF_EX_AD() external {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether,
            0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                0,
                false,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );
    }

    function test__unit_correct__payMateStaking_sync__PF_EX_AD() external {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.003 ether,
            0.00000001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                0,
                false,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, ETHER_ADDRESS),
            0.00000001 ether
        );
    }

    function test__unit_correct__payMateStaking_sync__nPF_nEX_ID() external {
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
            0.003 ether,
            0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                0,
                false,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            address(0),
            signatureEVVM
        );
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );
    }

    function test__unit_correct__payMateStaking_sync__PF_nEX_ID() external {
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
            0.003 ether,
            0.00000001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                0,
                false,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            address(0),
            signatureEVVM
        );
        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, ETHER_ADDRESS),
            0.00000001 ether
        );
    }

    function test__unit_correct__payMateStaking_sync__nPF_EX_ID() external {
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
            0.003 ether,
            0
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0,
                0,
                false,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );
    }

    function test__unit_correct__payMateStaking_sync__PF_EX_ID() external {
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
            0.003 ether,
            0.00000001 ether
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.001 ether,
                0.00000001 ether,
                0,
                false,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        evvm.payMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "dummy",
            ETHER_ADDRESS,
            0.001 ether,
            0.00000001 ether,
            COMMON_USER_STAKER.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.002 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.001 ether
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, ETHER_ADDRESS),
            0.00000001 ether
        );
    }
}
