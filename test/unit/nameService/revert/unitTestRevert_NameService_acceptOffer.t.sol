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
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

contract unitTestRevert_NameService_acceptOffer is Test, Constants {
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
        evvm._addBalance(user.Address, MATE_TOKEN_ADDRESS, priorityFeeAmount);

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
        bytes memory signatureNameService = Erc191TestBuilder.buildERC191Signature(
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

    function makeAcceptOfferSignatures(
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
                Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                    usernameToFindOffer,
                    index,
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
                    priorityFeeAmountEVVM,
                    0,
                    nonceEVVM,
                    priorityFlagEVVM,
                    address(nameService)
                )
            );
            signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
        } else {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                    usernameToFindOffer,
                    index,
                    nonceNameService
                )
            );
            signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);
            signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);
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
    function test__unit_revert__acceptOffer__bPaySigAt() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    /////////////////////////////////////////////////////////////////////////////

    function test__unit_revert__acceptOffer__() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                0,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
    */

   function test__unit_revert__acceptOffer__bSigAtSigner() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bSigAtUsername() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "user",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bSigAtOfferID() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                1,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bSigAtNonceNameService() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                777
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtSigner() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtToAddress() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtToIdentity() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "nameservice",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtTokenAddress() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                ETHER_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtAmount() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                0,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtPriorityFee() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                1,
                1001,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtNonceEVVM() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                777,
                true,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtPriorityFlag() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                false,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__bPaySigAtExecutor() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        bytes memory signatureNameService;
        bytes memory signatureEVVM;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForAcceptOffer(
                "test",
                0,
                10000000001
            )
        );
        signatureNameService = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(nameService),
                "",
                MATE_TOKEN_ADDRESS,
                amountPriorityFee,
                0,
                1001,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__userIsNotOwner() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_2,
            0.001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_2,
                true,
                "test",
                0,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_2.Address,
            10000000001,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__nonceMnsAlreadyUsed() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                0,
                10101,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10101,
            "test",
            0,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__offerExpired() external {
        makeOffer(
            COMMON_USER_NO_STAKER_2,
            "test",
            block.timestamp + 5 days,
            0.001 ether,
            777,
            777,
            true
        );

        skip(10 days);

        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                1,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            1,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__acceptOffer__offerOutOfBounds() external {
        uint256 amountPriorityFee = addBalance(
            COMMON_USER_NO_STAKER_1,
            0.001 ether
        );

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeAcceptOfferSignatures(
                COMMON_USER_NO_STAKER_1,
                true,
                "test",
                1,
                10000000001,
                amountPriorityFee,
                1001,
                true
            );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();

        nameService.acceptOffer(
            COMMON_USER_NO_STAKER_1.Address,
            10000000001,
            "test",
            1,
            amountPriorityFee,
            signatureNameService,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (address user, ) = nameService.getIdentityBasicMetadata("test");

        assertEq(user, COMMON_USER_NO_STAKER_1.Address);

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            amountPriorityFee
        );
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }
}
