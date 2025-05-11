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
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract unitTestRevert_EVVM_payNoMateStaking_sync is Test, Constants {
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
     * For the signature tes we going to assume the executor is a bad actor,
     * but in the executor test an fisher try to execute the payment who obivously
     * is not the executor.
     * Function to test:
     * bSigAt[section]: incorrect signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unit_revert__payNoMateStaking_sync__bSigAtFrom() external {
        addBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS, 0.11 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_3.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_2.Address,
            COMMON_USER_NO_STAKER_3.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtToAddress()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_3.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtToIdentity()
        external
    {
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
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "fake",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtToken() external {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            0.11 ether
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            MATE_TOKEN_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtAmount() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 1.11 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            1.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtPriorityFee()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 1.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            1 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            1.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtNonceNumber()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                111,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtPriorityFlag()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                true,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__bSigAtToExecutor()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_2.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync_wValAtExecutor()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__userFromHasLessThanAmountPlusFee()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.8 ether,
                0.04 ether,
                0,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.8 ether,
            0.04 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payNoMateStaking_sync__wValAtNonce()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                156,
                false,
                COMMON_USER_NO_STAKER_3.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        vm.expectRevert();
        evvm.payNoMateStaking_sync(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            COMMON_USER_NO_STAKER_3.Address,
            signatureEVVM
        );

        vm.stopPrank();
    }
}
