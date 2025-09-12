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

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract unitTestCorrect_NameService_registrationUsername_SyncExecutionOnPay is
    Test,
    Constants
{
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

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
        evvm._setupNameServiceAndTreasuryAddress(address(nameService), address(treasury));

        evvm.setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function addBalance(
        address user,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 registrationPrice, uint256 totalPriorityFeeAmount)
    {
        evvm.addBalance(
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
        uint256 nonceNameService
    ) private {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceNameService
            )
        );

        nameService.preRegistrationUsername(
            user.Address,
            keccak256(abi.encodePacked(username, uint256(clowNumber))),
            nonceNameService,
            Erc191TestBuilder.buildERC191Signature(v, r, s),
            0,
            0,
            false,
            hex""
        );
    }

    function makeRegistrationUsernameSignatures(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceNameService,
        uint256 priorityFeeAmountEVVM,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    )
        private
        view
        returns (bytes memory signatureNameService, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                username,
                clowNumber,
                nonceNameService
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

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

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            777,
            20202,
            signatureNameService,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0.001 ether,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            777,
            20202,
            signatureNameService,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            777,
            20202,
            signatureNameService,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                20202,
                0.001 ether,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            "test",
            777,
            20202,
            signatureNameService,
            0.001 ether,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

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
            (evvm.getRewardAmount() * 50) + 0.001 ether
        );
    }
}
