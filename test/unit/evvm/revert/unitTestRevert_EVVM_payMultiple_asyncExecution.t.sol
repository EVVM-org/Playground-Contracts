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
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

import {SMate} from "@EVVM/playground/staking/SMate.sol";
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestRevert_EVVM_payMultiple_asyncExecution is Test, Constants {
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
     * For the signature tes we going to assume the executor is a bad actor,
     * but in the executor test an fisher try to execute the payment who obivously
     * is not the executor.
     * Function to test:
     * bSigAt[section]: incorrect signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unit_revert__payMultiple_asyncExecution__bSigAtFrom()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_3.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtToAddress()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_3.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtToIdentity()
        public
    {
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
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: address(0),
            to_identity: "fake",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtTokenAddress()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: MATE_TOKEN_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtAmount()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtPriorityFee()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.07 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtNonce()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 777,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtFlagPriority()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: false,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__bSigAtExecutor()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: address(0),
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__diferentExecutor()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: COMMON_USER_STAKER.Address,
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        (, uint256 failTx, ) = evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(failTx, 1);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__amountMoreThanBalance()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                1 ether,
                0.01 ether,
                1001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: address(0),
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        (, uint256 failTx, ) = evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(failTx, 1);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__priorityFeeMoreThanBalance()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.1 ether,
                1001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.1 ether,
            nonce: 1001,
            priority: true,
            executor: address(0),
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        (, uint256 failTx, ) = evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(failTx, 1);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payMultiple_asyncExecution__nonceAlreadyUsed()
        public
    {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            ETHER_ADDRESS,
            0.2 ether,
            0.02 ether
        );

        EvvmStructs.PayData[]
            memory payData = new EvvmStructs.PayData[](2);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        payData[0] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: address(0),
            signature: signatureEVVM
        });

        payData[1] = EvvmStructs.PayData({
            from: COMMON_USER_NO_STAKER_1.Address,
            to_address: COMMON_USER_NO_STAKER_2.Address,
            to_identity: "",
            token: ETHER_ADDRESS,
            amount: 0.1 ether,
            priorityFee: 0.01 ether,
            nonce: 1001,
            priority: true,
            executor: address(0),
            signature: signatureEVVM
        });

        vm.startPrank(COMMON_USER_STAKER.Address);

        (, uint256 failTx, bool[] memory results) = evvm.payMultiple(payData);

        vm.stopPrank();

        assertEq(failTx, 1);

        assertEq(results[1], false);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }
}
