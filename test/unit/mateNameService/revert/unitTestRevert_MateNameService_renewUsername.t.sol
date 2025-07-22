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

contract unitTestRevert_MateNameService_renewUsername is Test, Constants {
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
    )
        private
        returns (uint256 totalRenewalAmount, uint256 totalPriorityFeeAmount)
    {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            mns.seePriceToRenew(username) + priorityFeeAmount
        );

        totalRenewalAmount = mns.seePriceToRenew(username);
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
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*
    function test__unit_revert__renewUsername__bPaySigAt() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    ///////////

    function test__unit_revert__renewUsername__() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_revert__renewUsername__bSigAtSigner() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bSigAtUsername() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "user",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bSigAtNonceMNS() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername("test", 777)
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtSigner() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtToAddress() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtToIdentity() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "matenameservice",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtTokenAddress()
        external
    {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                ETHER_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtAmount() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                1,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtPriorityFee() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                1 ether,
                11111111,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtNonceEVVM() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                777,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtPriorityFlag()
        external
    {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                false,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtExecutor() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureMNS;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                "test",
                1000001000001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__userIsNotTheOwner() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_2, "test", 0.001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_2.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__nonceAlreadyUsed() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                10101,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__notAUsername() external {
        mns._setIdentityBaseMetadata(
            "test@mail.com",
            Mns.IdentityBaseMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                block.timestamp + 366 days,
                0,
                0,
                0x01
            )
        );

        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test@mail.com", 0.001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test@mail.com",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test@mail.com"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test@mail.com",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "test@mail.com"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__expirationDateMoreThan100Years() external {
        mns._setIdentityBaseMetadata(
            "user",
            Mns.IdentityBaseMetadata(
                COMMON_USER_NO_STAKER_1.Address,
                block.timestamp + 36500 days,
                0,
                0,
                0x00
            )
        );

        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "user", 0.001 ether);

        (
            bytes memory signatureMNS,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "user"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "user",
            totalPriorityFeeAmount,
            signatureMNS,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = mns.getIdentityBasicMetadata(
            "user"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
