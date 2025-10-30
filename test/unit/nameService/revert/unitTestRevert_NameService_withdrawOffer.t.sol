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
import {Erc191TestBuilder} from "@EVVM/playground/library/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {AdvancedStrings} from "@EVVM/playground/library/AdvancedStrings.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract unitTestRevert_NameService_withdrawOffer is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

    AccountData COMMON_USER_NO_STAKER_3 = WILDCARD_USER;

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

        makeRegistrationUsername(
            COMMON_USER_NO_STAKER_1,
            "test",
            777,
            10101,
            20202
        );
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 30 days,
            0.001 ether,
            10001,
            101,
            true
        );
    }

    function addBalance(
        AccountData memory user,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm.addBalance(user.Address, MATE_TOKEN_ADDRESS, priorityFeeAmount);

        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makeRegistrationUsername(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceNameServicePre,
        uint256 nonceNameService
    ) private {
        evvm.addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceOfRegistration(username)
        );

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                evvm.getEvvmID(),
                keccak256(abi.encodePacked(username, uint256(clowNumber))),
                nonceNameServicePre
            )
        );

        nameService.preRegistrationUsername(
            user.Address,
            keccak256(abi.encodePacked(username, uint256(clowNumber))),
            nonceNameServicePre,
            Erc191TestBuilder.buildERC191Signature(v, r, s),
            0,
            0,
            false,
            hex""
        );

        skip(30 minutes);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForRegistrationUsername(
                evvm.getEvvmID(),
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
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                nameService.getPriceOfRegistration(username),
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
            username,
            clowNumber,
            nonceNameService,
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

        evvm.addBalance(user.Address, MATE_TOKEN_ADDRESS, amountToOffer);

        (v, r, s) = vm.sign(
            user.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForMakeOffer(
                evvm.getEvvmID(),
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
                evvm.getEvvmID(),
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
            usernameToMakeOffer,
            expireDate,
            amountToOffer,
            nonceNameService,
            signatureNameService,
            0,
            nonceEVVM,
            priorityFlagEVVM,
            signatureEVVM
        );
    }

    function makeWithdrawOfferSignatures(
        AccountData memory user,
        bool givePriorityFee,
        string memory usernameToFindOffer,
        uint256 index,
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

        if (givePriorityFee) {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                    usernameToFindOffer,
                    index,
                    nonceNameService
                )
            );
            signatureNameService = Erc191TestBuilder.buildERC191Signature(
                v,
                r,
                s
            );

            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                    address(nameService),
                    "",
                    MATE_TOKEN_ADDRESS,
                    0,
                    priorityFeeAmountEVVM,
                    nonceEVVM,
                    priorityFlagEVVM,
                    address(nameService)
                )
            );
            signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
        } else {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                    usernameToFindOffer,
                    index,
                    nonceNameService
                )
            );
            signatureNameService = Erc191TestBuilder.buildERC191Signature(
                v,
                r,
                s
            );
            signatureEVVM = "";
        }
    }

    /**
     * Function to test:
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    /*

    function test__unit_revert__withdrawOffer__bPaySigAt() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////

    function test__unit_revert__withdrawOffer__() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeWithdrawOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                0,
                100010001,
                totalPriorityFee,
                10000001,
                true
            );

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

    function test__unit_revert__withdrawOffer__bSigAtSigner() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bSigAtUsername() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "user",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bSigAtOfferID() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                777,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bSigAtNonceNameService()
        external
    {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),"test", 0, 777)
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtSigner() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtToAddress() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtToIdentity() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(0),
                "nameservice",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtTokenAddress()
        external
    {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                ETHER_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtAmount() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                0,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtPriorityFee() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                777,
                10000001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtNonceEVVM() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                777,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtPriorityFlag()
        external
    {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                false,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__bPaySigAtExecutor() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForWithdrawOffer(
                evvm.getEvvmID(),
                "test",
                0,
                100010001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFee,
                0,
                10000001,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__addressIsNotOfferer() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_3,
            0.0001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeWithdrawOfferSignatures(
                COMMON_USER_NO_STAKER_3,
                true,
                "test",
                0,
                100010001,
                totalPriorityFee,
                10000001,
                true
            );

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_3.Address,
            "test",
            0,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__NonceAlreadyUsed() external {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeWithdrawOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                0,
                10001,
                totalPriorityFee,
                10000001,
                true
            );

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            0,
            10001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__withdrawOffer__userTriesToCallOutOfBounds()
        external
    {
        uint256 totalPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.0001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeWithdrawOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                5,
                100010001,
                totalPriorityFee,
                10000001,
                true
            );

        NameService.OfferMetadata memory checkDataBefore = nameService
            .getSingleOfferOfUsername("test", 0);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        nameService.withdrawOffer(
            COMMON_USER_NO_STAKER_2.Address,
            "test",
            5,
            100010001,
            signatureNameService,
            totalPriorityFee,
            10000001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        NameService.OfferMetadata memory checkDataAfter = nameService
            .getSingleOfferOfUsername("test", 0);

        assertEq(checkDataAfter.offerer, checkDataBefore.offerer);
        assertEq(checkDataAfter.amount, checkDataBefore.amount);
        assertEq(checkDataAfter.expireDate, checkDataBefore.expireDate);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
