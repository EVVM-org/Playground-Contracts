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
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

contract unitTestRevert_NameService_renewUsername is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(
            ADMIN.Address,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
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
        evvm._setupNameServiceAddress(address(nameService));

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
            nameService.seePriceToRenew(username) + priorityFeeAmount
        );

        totalRenewalAmount = nameService.seePriceToRenew(username);
        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makeRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceNameServicePre,
        uint256 nonceNameService
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
                nonceNameServicePre
            )
        );

        nameService.preRegistrationUsername(
            user.Address,
            nonceNameServicePre,
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
                nonceNameService
            )
        );
        bytes memory signatureNameService = Erc191TestBuilder
            .buildERC191Signature(v, r, s);

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
            nonceNameService,
            username,
            clowNumber,
            signatureNameService,
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
        uint256 nonceNameService,
        uint256 nonceEVVM,
        bool priorityFlagEVVM
    ) private {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureNameService;
        bytes memory signatureEVVM;

        evvm._addBalance(user.Address, MATE_TOKEN_ADDRESS, amountToOffer);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                usernameToMakeOffer,
                expireDate,
                amountToOffer,
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
                amountToOffer,
                0,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        nameService.makeOffer(
            user.Address,
            nonceNameService,
            usernameToMakeOffer,
            amountToOffer,
            expireDate,
            0,
            signatureNameService,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeRenewUsernameSignatures(
        AccountData memory user,
        string memory usernameToRenew,
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
            Erc191TestBuilder.buildMessageSignedForRenewUsername(
                usernameToRenew,
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
                nameService.seePriceToRenew(usernameToRenew),
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

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = nameService.getIdentityBasicMetadata(
            "test"
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_revert__renewUsername__bSigAtSigner() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bSigAtUsername() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bSigAtNonceNameService()
        external
    {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRenewUsername("test", 777)
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtSigner() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtToAddress() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

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
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtToIdentity() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "nameservice",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                ETHER_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtAmount() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                1,
                totalPriorityFeeAmount,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtPriorityFee() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                1 ether,
                11111111,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtNonceEVVM() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                777,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
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

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalRenewalAmount,
                totalPriorityFeeAmount,
                11111111,
                false,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__bPaySigAtExecutor() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        bytes memory signatureNameService;
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
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
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

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__userIsNotTheOwner() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_2, "test", 0.001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_2.Address,
            1000001000001,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__nonceAlreadyUsed() external {
        (
            uint256 totalRenewalAmount,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1, "test", 0.001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                10101,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__notAUsername() external {
        nameService._setIdentityBaseMetadata(
            "test@mail.com",
            NameService.IdentityBaseMetadata(
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test@mail.com",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test@mail.com");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "test@mail.com",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("test@mail.com");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__renewUsername__expirationDateMoreThan100Years()
        external
    {
        nameService._setIdentityBaseMetadata(
            "user",
            NameService.IdentityBaseMetadata(
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
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRenewUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                1000001000001,
                totalPriorityFeeAmount,
                11111111,
                true
            );

        (, uint256 beforeUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("user");

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.renewUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1000001000001,
            "user",
            totalPriorityFeeAmount,
            signatureNameService,
            11111111,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (, uint256 afterUsernameExpirationTime) = nameService
            .getIdentityBasicMetadata("user");

        assertEq(afterUsernameExpirationTime, beforeUsernameExpirationTime);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalRenewalAmount + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
