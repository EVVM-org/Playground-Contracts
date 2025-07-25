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
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestCorrect_NameService_registrationUsername_AsyncExecutionOnPay is
    Test,
    Constants
{
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
            nameService.getPricePerRegistration() + priorityFeeAmount
        );

        registrationPrice = nameService.getPricePerRegistration();
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

        nameService.preRegistrationUsername(
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
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
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
        nameService.registrationUsername(
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

        (address user, uint256 expirationDate) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
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
        nameService.registrationUsername(
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

        (address user, uint256 expirationDate) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
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
        nameService.registrationUsername(
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

        (address user, uint256 expirationDate) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() * 50
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
        nameService.registrationUsername(
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

        (address user, uint256 expirationDate) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            ),
            (evvm.getRewardAmount() * 50) + 0.001 ether
        );
    }
}
