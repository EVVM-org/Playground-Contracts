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
import {Erc191TestBuilder} from "@EVVM/playground/library/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";
import {P2PSwap} from "@EVVM/playground/contracts/p2pSwap/P2PSwap.sol";

contract unitTestRevert_P2PSwap_dispatchOrder_fillFixedFee is Test, Constants {
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

        p2pSwap = new P2PSwap(address(evvm), address(staking), ADMIN.Address);

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

    function test__unit_revert__dispatchOrder_fillFixedFee_invalidSignature()
        external
    {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        uint256 proportionalFee = (amountB * 500) / 10_000;
        uint256 _amountOut = 0.001 ether; // greater than proportionalFee
        uint256 fee;
        uint256 fee10;

        if (proportionalFee > _amountOut) {
            fee = _amountOut;
            fee10 = (fee * 1000) / 10_000;
        } else {
            fee = proportionalFee;
            fee10 = 0;
        }

        addBalance(COMMON_USER_NO_STAKER_1.Address, tokenA, amountA);
        addBalance(COMMON_USER_NO_STAKER_2.Address, tokenB, amountB + fee);

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
        // nonceP2PSwap = 56565;
        // nonceEVVM++;

        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);

        // 3. dispatch that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispatchOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenA, // tokenA repeated, invalid signature here
                orderId
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        // 3.2 crete evvm signature
        P2PSwap.MetadataDispatchOrder memory metadata = P2PSwap
            .MetadataDispatchOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                amountOfTokenBToFill: amountB + fee,
                signature: signatureP2P
            });

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenB,
                metadata.amountOfTokenBToFill,
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

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // dispatch order with amountB
        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        p2pSwap.dispatchOrder_fillFixedFee(
            COMMON_USER_NO_STAKER_2.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM,
            _amountOut
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenB), 0);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, tokenB),
            amountB + fee
        );
    }

    function test__unit_revert__dispatchOrder_fillFixedFee_invalidNonce()
        external
    {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        uint256 proportionalFee = (amountB * 500) / 10_000;
        uint256 _amountOut = 0.001 ether; // greater than proportionalFee
        uint256 fee;
        uint256 fee10;

        if (proportionalFee > _amountOut) {
            fee = _amountOut;
            fee10 = (fee * 1000) / 10_000;
        } else {
            fee = proportionalFee;
            fee10 = 0;
        }

        addBalance(COMMON_USER_NO_STAKER_1.Address, tokenA, amountA);
        addBalance(COMMON_USER_NO_STAKER_2.Address, tokenB, amountB + fee);

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

        // use nonceP2PSwap
        addBalance(COMMON_USER_NO_STAKER_2.Address, tokenB, amountB);
        createOrder(
            COMMON_USER_STAKER,
            COMMON_USER_NO_STAKER_2,
            nonceP2PSwap,
            tokenB,
            tokenA,
            amountB,
            amountA,
            priorityFee,
            nonceEVVM,
            priorityFlag
        );
        // now, nonceP2PSwap has been used, must generate an error when trying to use it again
        nonceEVVM++;

        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);

        // 3. dispatch that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispatchOrder(
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
        P2PSwap.MetadataDispatchOrder memory metadata = P2PSwap
            .MetadataDispatchOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                amountOfTokenBToFill: amountB + fee,
                signature: signatureP2P
            });

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenB,
                metadata.amountOfTokenBToFill,
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

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // dispatch order with amountB
        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        p2pSwap.dispatchOrder_fillFixedFee(
            COMMON_USER_NO_STAKER_2.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM,
            _amountOut
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenB), 0);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, tokenB),
            amountB + fee
        );
    }

    function test__unit_revert__dispatchOrder_fillFixedFee_invalidOrder()
        external
    {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        // uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        uint256 proportionalFee = (amountB * 500) / 10_000;
        uint256 _amountOut = 0.001 ether; // greater than proportionalFee
        uint256 fee;
        uint256 fee10;

        if (proportionalFee > _amountOut) {
            fee = _amountOut;
            fee10 = (fee * 1000) / 10_000;
        } else {
            fee = proportionalFee;
            fee10 = 0;
        }

        // 3. dispatch that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispatchOrder(
                evvm.getEvvmID(),
                nonceP2PSwap,
                tokenA,
                tokenB,
                1 // invalid order
            )
        );

        bytes memory signatureP2P = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        // 3.2 crete evvm signature
        P2PSwap.MetadataDispatchOrder memory metadata = P2PSwap
            .MetadataDispatchOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: 1,
                amountOfTokenBToFill: amountB + fee,
                signature: signatureP2P
            });

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenB,
                metadata.amountOfTokenBToFill,
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

        // dispatch order with amountB
        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        p2pSwap.dispatchOrder_fillFixedFee(
            COMMON_USER_NO_STAKER_2.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM,
            _amountOut
        );
        vm.stopPrank();
    }

    function test__unit_revert__dispatchOrder_fillFixedFee_insufficientAmount()
        external
    {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        uint256 proportionalFee = (amountB * 500) / 10_000;
        uint256 _amountOut = 0.001 ether; // greater than proportionalFee
        uint256 fee;
        uint256 fee10;

        if (proportionalFee > _amountOut) {
            fee = _amountOut;
            fee10 = (fee * 1000) / 10_000;
        } else {
            fee = proportionalFee;
            fee10 = 0;
        }

        addBalance(COMMON_USER_NO_STAKER_1.Address, tokenA, amountA);
        addBalance(COMMON_USER_NO_STAKER_2.Address, tokenB, amountB + fee);

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
        // nonceP2PSwap = 56565;
        // nonceEVVM++;

        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);

        // 3. dispatch that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispatchOrder(
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
        P2PSwap.MetadataDispatchOrder memory metadata = P2PSwap
            .MetadataDispatchOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                amountOfTokenBToFill: amountB, // should be amountB + fee
                signature: signatureP2P
            });

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenB,
                metadata.amountOfTokenBToFill,
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

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // dispatch order with amountB
        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        p2pSwap.dispatchOrder_fillFixedFee(
            COMMON_USER_NO_STAKER_2.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM,
            _amountOut
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenB), 0);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, tokenB),
            amountB + fee
        );
    }

    function test__unit_revert__dispatchOrder_fillFixedFee_invalidPay()
        external
    {
        // 1. define params
        uint256 nonceP2PSwap = 14569;
        address tokenA = ETHER_ADDRESS;
        address tokenB = MATE_TOKEN_ADDRESS;
        uint256 amountA = 0.001 ether;
        uint256 amountB = 0.01 ether;
        uint256 priorityFee = 0;
        uint256 nonceEVVM = 0;
        bool priorityFlag = false;

        uint256 proportionalFee = (amountB * 500) / 10_000;
        uint256 _amountOut = 0.001 ether; // greater than proportionalFee
        uint256 fee;
        uint256 fee10;

        if (proportionalFee > _amountOut) {
            fee = _amountOut;
            fee10 = (fee * 1000) / 10_000;
        } else {
            fee = proportionalFee;
            fee10 = 0;
        }

        addBalance(COMMON_USER_NO_STAKER_1.Address, tokenA, amountA);
        addBalance(COMMON_USER_NO_STAKER_2.Address, tokenB, amountB + fee);

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
        // nonceP2PSwap = 56565;
        // nonceEVVM++;

        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);

        // 3. dispatch that order
        // 3.1 create p2p signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispatchOrder(
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
        P2PSwap.MetadataDispatchOrder memory metadata = P2PSwap
            .MetadataDispatchOrder({
                nonce: nonceP2PSwap,
                tokenA: tokenA,
                tokenB: tokenB,
                orderId: orderId,
                amountOfTokenBToFill: amountB + fee, 
                signature: signatureP2P
            });

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(p2pSwap),
                "",
                tokenB,
                amountB, // should be metadata.amountOfTokenBToFill,
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

        // make sure the order is there
        P2PSwap.Order memory order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);

        // dispatch order with amountB
        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        p2pSwap.dispatchOrder_fillFixedFee(
            COMMON_USER_NO_STAKER_2.Address,
            metadata,
            priorityFee,
            nonceEVVM,
            priorityFlag,
            signatureEVVM,
            _amountOut
        );
        vm.stopPrank();

        // 4. assertions
        order = p2pSwap.getOrder(market, orderId);
        assertEq(order.seller, COMMON_USER_NO_STAKER_1.Address);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenA), 0);
        assertEq(evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, tokenB), 0);

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, tokenB),
            amountB + fee
        );
	}
}
