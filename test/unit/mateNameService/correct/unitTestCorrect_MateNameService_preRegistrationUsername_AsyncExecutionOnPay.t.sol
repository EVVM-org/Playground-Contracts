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

import {SMate} from "@EVVM/playground/staking/SMate.sol";
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestCorrect_MateNameService_preRegistrationUsername_AsyncExecutionOnPay is
    Test,
    Constants
{
    SMate sMate;
    Evvm evvm;
    Estimator estimator;
    Mns mns;

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
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(user, token, priorityFeeAmount);

        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makePreRegistrationUsernameSignature(
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNS,
        bool givePriorityFee,
        uint256 priorityFeeAmount,
        uint256 nonceEVVM,
        bool priorityEVVM
    )
        private
        view
        returns (bytes memory signatureMNS, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (givePriorityFee) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                    keccak256(abi.encodePacked(username, uint256(clowNumber))),
                    nonceMNS
                )
            );
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(mns),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFeeAmount,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(mns)
                )
            );
            signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                    keccak256(abi.encodePacked(username, uint256(clowNumber))),
                    nonceMNS
                )
            );
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            signatureEVVM = "";
        }
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    function test__unit_correct__preRegistrationUsername__nS_nPF() external {
        (bytes memory signatureMNS, ) = makePreRegistrationUsernameSignature(
            "test",
            10101,
            1001,
            false,
            0,
            0,
            false
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            0,
            signatureMNS,
            0,
            false,
            hex""
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__unit_correct__preRegistrationUsername__nS_PF() external {
        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makePreRegistrationUsernameSignature(
                "test",
                10101,
                1001,
                true,
                totalPriorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__unit_correct__preRegistrationUsername__S_nPF() external {
        (bytes memory signatureMNS, ) = makePreRegistrationUsernameSignature(
            "test",
            10101,
            1001,
            false,
            0,
            0,
            false
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            0,
            signatureMNS,
            0,
            false,
            hex""
        );

        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount()
        );
    }

    function test__unit_correct__preRegistrationUsername__S_PF() external {
        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makePreRegistrationUsernameSignature(
                "test",
                10101,
                1001,
                true,
                totalPriorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() + totalPriorityFeeAmount
        );
    }
}
