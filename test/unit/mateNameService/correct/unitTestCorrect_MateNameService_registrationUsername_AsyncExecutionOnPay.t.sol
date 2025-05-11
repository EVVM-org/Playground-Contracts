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

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";
import {AdvancedStrings} from "@RollAMate/libraries/AdvancedStrings.sol";

contract unitTestCorrect_MateNameService_registrationUsername_AsyncExecutionOnPay is
    Test,
    Constants
{
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    /**
     * Function to test: 
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    function addBalance(
        address user,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 registrationPrice, uint256 totalPriorityFeeAmount)
    {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            mns.getPricePerRegistration() + priorityFeeAmount
        );

        registrationPrice = mns.getPricePerRegistration();
        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makePreRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNS
    ) private {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceMNS
            )
        );

        mns.preRegistrationUsername(
            user.Address,
            nonceMNS,
            keccak256(abi.encodePacked(username, uint256(clowNumber))),
            0,
            Erc191TestBuilder.buildERC191Signature(v, r, s),
            0,
            false,
            hex""
        );
    }

    function makeRegistrationUsernameSignatures(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNS,
        uint256 priorityFeeAmountEVVM,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    )
        private
        view
        returns (bytes memory signatureMNS, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                username,
                clowNumber,
                nonceMNS
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                mns.getPricePerRegistration(),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function test__unit_correct__registrationUsername__nS_nPF() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, 0);
        makePreRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        mns.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            20202,
            "test",
            777,
            signatureMNS,
            0,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__unit_correct__registrationUsername__nS_PF() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);
        makePreRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0.001 ether,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        mns.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            20202,
            "test",
            777,
            signatureMNS,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__unit_correct__registrationUsername__S_nPF() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, 0);
        makePreRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        mns.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            20202,
            "test",
            777,
            signatureMNS,
            0,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() * 50
        );
    }

    function test__unit_correct__registrationUsername__S_PF() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);
        makePreRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101
        );

        skip(30 minutes);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0.001 ether,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        mns.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            20202,
            "test",
            777,
            signatureMNS,
            0.001 ether,
            1001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            ),
            (evvm.seeMateReward() * 50) + 0.001 ether
        );
    }
}
