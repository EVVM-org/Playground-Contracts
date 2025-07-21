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

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract unitTestCorrect_MateNameService_renewUsername_SyncExecutionOnPay is
    Test,
    Constants
{
    SMateMock sMate;
    Evvm evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
        estimator = new EstimatorMock(
            ACTIVATOR.Address,
            address(evvm),
            address(sMate),
            ADMIN.Address
        );
        mns = new MateNameServiceMock(address(evvm), ADMIN.Address);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mns));
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        makeRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101,
            20202
        );
    }

    function addBalance(
        AccountData memory user,
        string memory username,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            mns.seePriceToRenew(username) + priorityFeeAmount
        );
        totalPriorityFeeAmount = priorityFeeAmount;
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
            mns.getPricePerRegistration()
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

        mns.preRegistrationUsername(
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
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                mns.getPricePerRegistration(),
                0,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                address(mns)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        mns.registrationUsername(
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

    function makeOffer(
        AccountData memory user,
        string memory usernameToMakeOffer,
        uint256 expireDate,
        uint256 amountToOffer,
        uint256 nonceMNS,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    ) private {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        evvm._addBalance(user.Address, MATE_TOKEN_ADDRESS, amountToOffer);

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
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                amountToOffer,
                0,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        mns.makeOffer(
            user.Address,
            nonceMNS,
            usernameToMakeOffer,
            amountToOffer,
            expireDate,
            0,
            signatureMNS,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeRenewUsernameSignatures(
        AccountData memory user,
        string memory usernameToRenew,
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
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                usernameToRenew,
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
                mns.seePriceToRenew(usernameToRenew),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(mns)
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
     * nOf: No offer
     * Of: Offer
     * EDPass: Expiration date passed
     */

    function test__unit_correct__renewUsername__nS_nPF_nOf() external {
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500 * 10 ** 18);

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

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

    function test__unit_correct__renewUsername__nS_nPF_Of() external {
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            0.01 ether,
            10001,
            101,
            true
        );

        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(
            mns.seePriceToRenew("test"),
            ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000) >
                (500000 * evvm.seeMateReward())
                ? (500000 * evvm.seeMateReward())
                : ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000)
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

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

    function test__unit_correct__renewUsername__nS_nPF_EDPass() external {
        skip(370 days);
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500_000 * evvm.seeMateReward());

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((362 days)));

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

    function test__unit_correct__renewUsername__nS_PF_nOf() external {
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500 * 10 ** 18);

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

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

    function test__unit_correct__renewUsername__nS_PF_Of() external {
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            0.01 ether,
            10001,
            101,
            true
        );

        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(
            mns.seePriceToRenew("test"),
            ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000) >
                (500000 * evvm.seeMateReward())
                ? (500000 * evvm.seeMateReward())
                : ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000)
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

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

    function test__unit_correct__renewUsername__nS_PF_EDPass() external {
        skip(370 days);
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500_000 * evvm.seeMateReward());

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((362 days)));

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

    function test__unit_correct__renewUsername__S_nPF_nOf() external {
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500 * 10 ** 18);

        uint256 priceOfRenewBefore = mns.seePriceToRenew("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                ((priceOfRenewBefore * 50) / 100) +
                priorityFeeAmount
        );
    }

    function test__unit_correct__renewUsername__S_nPF_Of() external {
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            0.01 ether,
            10001,
            101,
            true
        );

        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(
            mns.seePriceToRenew("test"),
            ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000) >
                (500000 * evvm.seeMateReward())
                ? (500000 * evvm.seeMateReward())
                : ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000)
        );

        uint256 priceOfRenewBefore = mns.seePriceToRenew("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                ((priceOfRenewBefore * 50) / 100) +
                priorityFeeAmount
        );
    }

    function test__unit_correct__renewUsername__S_nPF_EDPass() external {
        skip(370 days);
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500_000 * evvm.seeMateReward());

        uint256 priceOfRenewBefore = mns.seePriceToRenew("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((362 days)));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                ((priceOfRenewBefore * 50) / 100) +
                priorityFeeAmount
        );
    }

    function test__unit_correct__renewUsername__S_PF_nOf() external {
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500 * 10 ** 18);

        uint256 priceOfRenewBefore = mns.seePriceToRenew("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                ((priceOfRenewBefore * 50) / 100) +
                priorityFeeAmount
        );
    }

    function test__unit_correct__renewUsername__S_PF_Of() external {
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            0.01 ether,
            10001,
            101,
            true
        );

        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(
            mns.seePriceToRenew("test"),
            ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000) >
                (500000 * evvm.seeMateReward())
                ? (500000 * evvm.seeMateReward())
                : ((mns.getSingleOfferOfUsername("test", 0).amount * 5) / 1000)
        );

        uint256 priceOfRenewBefore = mns.seePriceToRenew("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((366 days) * 2));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                ((priceOfRenewBefore * 50) / 100) +
                priorityFeeAmount
        );
    }

    function test__unit_correct__renewUsername__S_PF_EDPass() external {
        skip(370 days);
        uint256 priorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            "test",
            0.001 ether
        );

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                priorityFeeAmount,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false
            );

        assertEq(mns.seePriceToRenew("test"), 500_000 * evvm.seeMateReward());

        uint256 priceOfRenewBefore = mns.seePriceToRenew("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            priorityFeeAmount,
            signatureMNS,
            evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
            false,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 newUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(newUsernameExpirationTime, block.timestamp + ((362 days)));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward() +
                ((priceOfRenewBefore * 50) / 100) +
                priorityFeeAmount
        );
    }
}
