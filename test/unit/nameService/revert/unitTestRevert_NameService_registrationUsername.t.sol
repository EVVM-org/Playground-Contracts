// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function revert behavior
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

contract unitTestRevert_NameService_registrationUsername is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

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
    }

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
            nonceNameService,
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
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*
    function test__unit_revert__registrationUsername__() external {


        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                10101,
                totalPriorityFeeAmount,
                10001,
                true
            );


        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService.getIdentityBasicMetadata(
            "test"
        );

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_revert__registrationUsername__bSigAtSigner() external {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bSigAtUsername()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "user",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bSigAtClowNumber()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                111,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bSigAtNonceNameService()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                111
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtSigner()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtToAddress()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtToIdentity()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "nameservice",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtTokenAddress()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                ETHER_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtAmount()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                11,
                totalPriorityFeeAmount,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtPriorityFee()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                1,
                10001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtNonceEVVM()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                777,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtPriorityFlag()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                false,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__bPaySigAtExecutor()
        external
    {
        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                "test",
                777,
                10101
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPricePerRegistration(),
                totalPriorityFeeAmount,
                10001,
                true,
                address(evvm)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__userDoesNotHavePreRegistration()
        external
    {
        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                10101,
                totalPriorityFeeAmount,
                10001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__userTriesToRegisterWithoutWait()
        external
    {
        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(10 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                10101,
                totalPriorityFeeAmount,
                10001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__userTriesToRegisterWithNotEnoughBalance()
        external
    {
        makePreRegistrationUsername(COMMON_USER_NO_STAKER_1, "test", 777, 111);

        skip(30 minutes);

        uint256 registrationPrice = nameService.getPricePerRegistration() / 2;

        evvm._addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            registrationPrice
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                10101,
                0,
                10001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            0,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__registrationUsername__userTriesToRegisterAUsernameWithDifferentPreOwner()
        external
    {
        makePreRegistrationUsername(COMMON_USER_NO_STAKER_2, "test", 777, 111);

        skip(30 minutes);

        (
            uint256 registrationPrice,
            uint256 totalPriorityFeeAmount
        ) = addBalance(COMMON_USER_NO_STAKER_1.Address, 0.001 ether);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                777,
                10101,
                totalPriorityFeeAmount,
                10001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        nameService.registrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            777,
            signatureNameService,
            totalPriorityFeeAmount,
            10001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata("test");

        assertEq(user, address(0));
        assertEq(expirationDate, 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            registrationPrice + totalPriorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
