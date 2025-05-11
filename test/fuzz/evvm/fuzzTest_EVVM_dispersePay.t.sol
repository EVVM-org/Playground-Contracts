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
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract fuzzTest_EVVM_dispersePay is Test, Constants, EvvmMockStructs {
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
    }

    function addBalance(
        address user,
        address token,
        uint256 amount,
        uint256 priorityFee
    ) private {
        evvm._addBalance(user, token, amount + priorityFee);
    }

    function makeDispersePaySignature(
        AccountData memory user,
        EvvmMockStructs.DispersePayMetadata[] memory toData,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        address executor
    ) private pure returns (bytes memory signatureEVVM) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForDispersePay(
                sha256(abi.encode(toData)),
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
     * Function to test: dispersePay

     * PF: Includes priority fee
     * nPF: No priority fee

     */

    struct DispersePayFuzzTestInput_nPF {
        bool useToAddress;
        bool useExecutor;
        bool useStaker;
        address token;
        uint16 amountA;
        uint16 amountB;
        uint176 nonce;
        bool priorityFlag;
    }

    struct DispersePayFuzzTestInput_PF {
        bool useToAddress;
        bool useExecutor;
        bool useStaker;
        address token;
        uint16 amountA;
        uint16 amountB;
        uint16 priorityFee;
        uint176 nonce;
        bool priorityFlag;
    }

    function test__fuzz__dispersePay__nPF(
        DispersePayFuzzTestInput_nPF memory input
    ) external {
        vm.assume(
            input.amountA > 0 &&
                input.amountB > 0 &&
                input.token != MATE_TOKEN_ADDRESS
        );

        uint256 totalAmount = uint256(input.amountA) + uint256(input.amountB);

        AccountData memory selectedExecuter = input.useStaker
            ? COMMON_USER_STAKER
            : COMMON_USER_NO_STAKER_3;

        uint256 nonce = input.priorityFlag
            ? input.nonce
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            input.token,
            totalAmount,
            0
        );

        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: input.amountA,
            to_address: COMMON_USER_NO_STAKER_3.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: input.amountB,
            to_address: address(0),
            to_identity: "dummy"
        });

        bytes memory signatureEVVM = makeDispersePaySignature(
            COMMON_USER_NO_STAKER_1,
            toData,
            input.token,
            totalAmount,
            0,
            nonce,
            input.priorityFlag,
            input.useExecutor ? selectedExecuter.Address : address(0)
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            input.token,
            totalAmount,
            0,
            nonce,
            input.priorityFlag,
            input.useExecutor ? selectedExecuter.Address : address(0),
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            0
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            input.amountB
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_3.Address, input.token),
            input.amountA
        );

        if (selectedExecuter.Address == COMMON_USER_STAKER.Address) {
            assertEq(
                evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward()
            );
        }
    }

    function test__fuzz__dispersePay__PF(
        DispersePayFuzzTestInput_PF memory input
    ) external {
        vm.assume(
            input.amountA > 0 &&
                input.amountB > 0 &&
                input.priorityFee > 0 &&
                input.token != MATE_TOKEN_ADDRESS
        );

        uint256 totalAmount = uint256(input.amountA) + uint256(input.amountB);

        AccountData memory selectedExecuter = input.useStaker
            ? COMMON_USER_STAKER
            : COMMON_USER_NO_STAKER_3;

        uint256 nonce = input.priorityFlag
            ? input.nonce
            : evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address);

        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            input.token,
            totalAmount,
            input.priorityFee
        );

        EvvmMockStructs.DispersePayMetadata[]
            memory toData = new EvvmMockStructs.DispersePayMetadata[](2);

        toData[0] = EvvmMockStructs.DispersePayMetadata({
            amount: input.amountA,
            to_address: COMMON_USER_NO_STAKER_3.Address,
            to_identity: ""
        });

        toData[1] = EvvmMockStructs.DispersePayMetadata({
            amount: input.amountB,
            to_address: address(0),
            to_identity: "dummy"
        });

        bytes memory signatureEVVM = makeDispersePaySignature(
            COMMON_USER_NO_STAKER_1,
            toData,
            input.token,
            totalAmount,
            input.priorityFee,
            nonce,
            input.priorityFlag,
            input.useExecutor ? selectedExecuter.Address : address(0)
        );

        vm.startPrank(selectedExecuter.Address);

        evvm.dispersePay(
            COMMON_USER_NO_STAKER_1.Address,
            toData,
            input.token,
            totalAmount,
            input.priorityFee,
            nonce,
            input.priorityFlag,
            input.useExecutor ? selectedExecuter.Address : address(0),
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_1.Address, input.token),
            (input.useStaker ? 0 : input.priorityFee)
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_3.Address, input.token),
            input.amountA
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_NO_STAKER_2.Address, input.token),
            input.amountB
        );

        if (selectedExecuter.Address == COMMON_USER_STAKER.Address) {
            assertEq(
                evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
                evvm.seeMateReward()
            );

            assertEq(
                evvm.seeBalance(COMMON_USER_STAKER.Address, input.token),
                input.priorityFee
            );
        }
    }
}
