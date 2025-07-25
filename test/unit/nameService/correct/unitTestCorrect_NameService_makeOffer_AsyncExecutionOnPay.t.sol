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

contract unitTestCorrect_NameService_makeOffer_AsyncExecutionOnPay is
    Test,
    Constants
{
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

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
        AccountData memory user,
        uint256 offerAmount,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 totalOfferAmount, uint256 totalPriorityFeeAmount)
    {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            offerAmount + priorityFeeAmount
        );

        totalOfferAmount = offerAmount;
        totalPriorityFeeAmount = priorityFeeAmount;

        makeRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101,
            20202
        );
    }

    function makeRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNSPre,
        uint256 nonceMNS
    ) private {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPricePerRegistration()
        );

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceMNSPre
            )
        );

        nameService.preRegistrationUsername(
            user.Address,
            nonceMNSPre,
            keccak256(abi.encodePacked(username, uint256(clowNumber))),
            0,
            Erc191TestBuilder.buildERC191Signature(v, r, s),
            0,
            false,
            hex""
        );

        skip(30 minutes);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                username,
                clowNumber,
                nonceMNS
            )
        );
        bytes memory signatureMNS = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                address(nameService)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        nameService.registrationUsername(
            user.Address,
            nonceMNS,
            username,
            clowNumber,
            signatureMNS,
            0,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );
    }

    function makeMakeOfferSignatures(
        AccountData memory user,
        string memory usernameToMakeOffer,
        uint256 expireDate,
        uint256 amountToOffer,
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
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                usernameToMakeOffer,
                expireDate,
                amountToOffer,
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
                amountToOffer,
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function test__unit_correct__makeOffer__nS_nPF() external {
        (uint256 totalOfferAmount, ) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                0,
                101,
                true
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            0,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, COMMON_USER_NO_STAKER_2.Address);
        assertEq(checkData.amount, ((totalOfferAmount * 995) / 1000));
        assertEq(checkData.expireDate, block.timestamp + 30 days);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            evvm.getRewardAmount() + (totalOfferAmount * 125) / 100_000
        );
    }

    function test__unit_correct__makeOffer__nS_PF() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);

        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, COMMON_USER_NO_STAKER_2.Address);
        assertEq(checkData.amount, ((totalOfferAmount * 995) / 1000));
        assertEq(checkData.expireDate, block.timestamp + 30 days);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            evvm.getRewardAmount() +
                ((totalOfferAmount * 125) / 100_000) +
                priorityFeeAmount
        );
    }

    function test__unit_correct__makeOffer__S_nPF() external {
        (uint256 totalOfferAmount, ) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                0,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            0,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, COMMON_USER_NO_STAKER_2.Address);
        assertEq(checkData.amount, ((totalOfferAmount * 995) / 1000));
        assertEq(checkData.expireDate, block.timestamp + 30 days);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() + (totalOfferAmount * 125) / 100_000
        );
    }

    function test__unit_correct__makeOffer__S_PF() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, COMMON_USER_NO_STAKER_2.Address);
        assertEq(checkData.amount, ((totalOfferAmount * 995) / 1000));
        assertEq(checkData.expireDate, block.timestamp + 30 days);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.getRewardAmount() +
                ((totalOfferAmount * 125) / 100_000) +
                priorityFeeAmount
        );
    }
}
