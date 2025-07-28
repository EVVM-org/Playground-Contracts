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

contract unitTestRevert_NameService_makeOffer is Test, Constants {
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

    function makeMakeOfferSignatures(
        AccountData memory user,
        string memory usernameToMakeOffer,
        uint256 expireDate,
        uint256 amountToOffer,
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

    function test__unit_revert__makeOffer__bPaySigAt() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
             totalOfferAmount +  priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }


    ////////////////////////////////////////////////////
    function test__unit_revert__makeOffer__bPaySigAt() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureNameService,
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

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();
        
        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
             totalOfferAmount +  priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    */

    function test__unit_revert__makeOffer__bSigAtSigner() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtUsername() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "user",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtExpirationDate() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 1 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtOfferAmount() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                0.0000001 ether,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bSigAtNonceNameService() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                777
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtSigner() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtToAddress() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtToIdentity() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "nameservice",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtTokenAddress() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                ETHER_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtAmount() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                priorityFeeAmount,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtPriorityFeeAmount()
        external
    {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                1 ether,
                101,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtNonceEVVM() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                777,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtPriorityFlag() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                false,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__bPaySigAtExecutor() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfferAmount,
                priorityFeeAmount,
                101,
                true,
                address(evvm)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__NonceMnsAlreadyUsed() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                "test",
                block.timestamp + 30 days,
                totalOfferAmount,
                10101,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__identityDoesNotExist() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "fake",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "fake",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__identityIsNotAUsername() external {
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
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test@mail.com",
                block.timestamp + 30 days,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test@mail.com",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test@mail.com", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__amountToOfferIsZero() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0 ether,
            0.000001 ether
        );
        (
            bytes memory signatureNameService,
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

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp + 30 days,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__makeOffer__expireDateLessThanNow() external {
        (uint256 totalOfferAmount, uint256 priorityFeeAmount) = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether,
            0.000001 ether
        );
        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeMakeOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                "test",
                block.timestamp - 1,
                totalOfferAmount,
                10001,
                priorityFeeAmount,
                101,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.makeOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10001,
            "test",
            totalOfferAmount,
            block.timestamp - 1,
            priorityFeeAmount,
            signatureNameService,
            101,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkData = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkData.offerer, address(0));
        assertEq(checkData.amount, 0);
        assertEq(checkData.expireDate, 0);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfferAmount + priorityFeeAmount
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
