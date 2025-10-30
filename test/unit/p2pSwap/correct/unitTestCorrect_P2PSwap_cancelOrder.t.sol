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
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";
import {P2PSwap} from "@EVVM/playground/contracts/p2pSwap/P2PSwap.sol";

contract unitTestCorrect_P2PSwap_cancelOrder is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;
    P2PSwap p2pSwap;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: 777,
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

        treasury = new Treasury(address(evvm));

        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasury)
        );

        p2pSwap = new P2PSwap(address(evvm), ADMIN.Address);

        evvm.setPointStaker(COMMON_USER_STAKER.Address, 0x01);
        evvm.setPointStaker(address(p2pSwap), 0x01);
    }

    function addBalance(address user, address token, uint256 amount) private {
        evvm.addBalance(user, token, amount);
    }

    /// @notice Creates an order for testing purposes
    function createOrder(
        AccountData memory executor,
        AccountData memory user,
        uint256 nonceP2PSwap,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 priorityFee,
        uint256 nonceEVVM,
        bool priorityFlag
    ) private returns (uint256 market, uint256 orderId) {
        P2PSwap.MetadataMakeOrder memory orderData = P2PSwap.MetadataMakeOrder({
            nonce: nonceP2PSwap,
            tokenA: tokenA,
            tokenB: tokenB,
            amountA: amountA,
            amountB: amountB
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenB,
                amountA,
                amountB
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenA,
                amountA,
                priorityFee,
                nonceEVVM,
                priorityFlag,
                address(p2pSwap)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(executor.Address);
        (market, orderId) = p2pSwap.makeOrder(
            user.Address,
            orderData,
            signatureP2P,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM
        );
        vm.stopPrank();

        return (market, orderId);
    }

    function test__unit_correct__cancelOrder_paySync_noPriorityFee() external {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        addBalance(COMMON_USER_NO_STAKER_1.Address, tokenA, amountA);

        // 2. create an order
        (uint256 market, uint256 orderId) = createOrder(
            COMMON_USER_STAKER,
            COMMON_USER_NO_STAKER_1,
            nonceP2PSwap,
            tokenA,
            tokenB,
            amountA,
            amountB,
            priorityFee,
            nonceEVVM,
            priorityFlag
        );
        nonceP2PSwap = 56565;
        nonceEVVM++;

        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);

        // 3. cancel that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForCancelOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenB,
                orderId
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );
        // 3.2 crete evvm signature
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenA,
                amountA,
                priorityFee,
                nonceEVVM,
                priorityFlag,
                address(p2pSwap)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        P2PSwap.MetadataCancelOrder memory metadata = P2PSwap
            .MetadataCancelOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                signature: signatureP2P
            });

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // Cancel the order
        vm.startPrank(COMMON_USER_STAKER.Address);
        p2pSwap.cancelOrder(
            COMMON_USER_NO_STAKER_1.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        // order should not be present anymore
        assertEq(order.seller, address(0));
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA),
            amountA
        );
    }

    function test__unit_correct__cancelOrder_paySync_priorityFee() external {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0.0001 ether;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            tokenA,
            amountA + priorityFee * 2
        );
        addBalance(address(p2pSwap), MATE_TOKEN_ADDRESS, 50000000000000000000);

        // 2. create an order
        (uint256 market, uint256 orderId) = createOrder(
            COMMON_USER_STAKER,
            COMMON_USER_NO_STAKER_1,
            nonceP2PSwap,
            tokenA,
            tokenB,
            amountA,
            amountB,
            priorityFee,
            nonceEVVM,
            priorityFlag
        );
        nonceP2PSwap = 56565;
        nonceEVVM++;

        // there should only remain one priorityFee
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA),
            priorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, tokenA),
            priorityFee
        );

        // 3. cancel that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForCancelOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenB,
                orderId
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        // 3.2 crete evvm signature
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenA,
                0,
                priorityFee,
                nonceEVVM,
                priorityFlag,
                address(p2pSwap)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        P2PSwap.MetadataCancelOrder memory metadata = P2PSwap
            .MetadataCancelOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                signature: signatureP2P
            });

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        // assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // Cancel the order
        vm.startPrank(COMMON_USER_STAKER.Address);
        p2pSwap.cancelOrder(
            COMMON_USER_NO_STAKER_1.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        // order should not be present anymore
        assertEq(order.seller, address(0));
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA),
            amountA
        );
    }

    function test__unit_correct__cancelOrder_payAsync_noPriorityFee() external {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 4242;
        bool priorityFlag = true;

        addBalance(COMMON_USER_NO_STAKER_1.Address, tokenA, amountA);

        // 2. create an order
        (uint256 market, uint256 orderId) = createOrder(
            COMMON_USER_STAKER,
            COMMON_USER_NO_STAKER_1,
            nonceP2PSwap,
            tokenA,
            tokenB,
            amountA,
            amountB,
            priorityFee,
            nonceEVVM,
            priorityFlag
        );
        nonceP2PSwap = 56565;
        nonceEVVM = 6565;

        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);

        // 3. cancel that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForCancelOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenB,
                orderId
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );
        // 3.2 crete evvm signature
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenA,
                amountA,
                priorityFee,
                nonceEVVM,
                priorityFlag,
                address(p2pSwap)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        P2PSwap.MetadataCancelOrder memory metadata = P2PSwap
            .MetadataCancelOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                signature: signatureP2P
            });

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // Cancel the order
        vm.startPrank(COMMON_USER_STAKER.Address);
        p2pSwap.cancelOrder(
            COMMON_USER_NO_STAKER_1.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        // order should not be present anymore
        assertEq(order.seller, address(0));
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA),
            amountA
        );
    }

    function test__unit_correct__cancelOrder_payAsync_priorityFee() external {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0.0001 ether;
        uint256 nonceEVVM = 4333411;
        bool priorityFlag = true;

        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            tokenA,
            amountA + priorityFee * 2
        );
        addBalance(address(p2pSwap), MATE_TOKEN_ADDRESS, 50000000000000000000);

        // 2. create an order
        (uint256 market, uint256 orderId) = createOrder(
            COMMON_USER_STAKER,
            COMMON_USER_NO_STAKER_1,
            nonceP2PSwap,
            tokenA,
            tokenB,
            amountA,
            amountB,
            priorityFee,
            nonceEVVM,
            priorityFlag
        );
        nonceP2PSwap = 56565;
        nonceEVVM = 699855;

        // there should only remain one priorityFee
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA),
            priorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, tokenA),
            priorityFee
        );

        // 3. cancel that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForCancelOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenB,
                orderId
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        // 3.2 crete evvm signature
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenA,
                0,
                priorityFee,
                nonceEVVM,
                priorityFlag,
                address(p2pSwap)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        P2PSwap.MetadataCancelOrder memory metadata = P2PSwap
            .MetadataCancelOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                signature: signatureP2P
            });

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        // assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // Cancel the order
        vm.startPrank(COMMON_USER_STAKER.Address);
        p2pSwap.cancelOrder(
            COMMON_USER_NO_STAKER_1.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        // order should not be present anymore
        assertEq(order.seller, address(0));
        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA),
            amountA
        );
    }
}
