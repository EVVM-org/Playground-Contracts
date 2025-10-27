// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

/**

:::::::::: :::    ::: ::::::::: :::::::::      ::::::::::: :::::::::: :::::::: ::::::::::: 
:+:        :+:    :+:      :+:       :+:           :+:     :+:       :+:    :+:    :+:     
+:+        +:+    +:+     +:+       +:+            +:+     +:+       +:+           +:+     
:#::+::#   +#+    +:+    +#+       +#+             +#+     +#++:++#  +#++:++#++    +#+     
+#+        +#+    +#+   +#+       +#+              +#+     +#+              +#+    +#+     
#+#        #+#    #+#  #+#       #+#               #+#     #+#       #+#    #+#    #+#     
###         ########  ######### #########          ###     ########## ########     ###     


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

contract fuzzTest_NameService_registrationUsername is Test, Constants {
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
        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasury)
        );

        evvm.setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function addBalance(
        address user,
        string memory username,
        uint256 priorityFeeAmount
    )
        private
        returns (uint256 registrationPrice, uint256 totalPriorityFeeAmount)
    {
        evvm.addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceOfRegistration(username) + priorityFeeAmount
        );

        registrationPrice = nameService.getPriceOfRegistration(username);
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
                evvm.getEvvmID(),
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
                evvm.getEvvmID(),
                username,
                clowNumber,
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
                nameService.getPriceOfRegistration(username),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function makeUsername(
        uint16 seed
    ) private pure returns (string memory username) {
        /// creas un nombre de usuario aleatorio de seed/2 caracteres
        /// este debe ser de la A-Z y a-z
        bytes memory usernameBytes = new bytes(seed / 2);
        for (uint256 i = 0; i < seed / 2; i++) {
            uint256 random = uint256(keccak256(abi.encodePacked(seed, i))) % 52;
            if (random < 26) {
                usernameBytes[i] = bytes1(uint8(random + 65));
            } else {
                usernameBytes[i] = bytes1(uint8(random + 71));
            }
        }
        username = string(usernameBytes);
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
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function makeFlushUsernameSignatures(
        AccountData memory user,
        string memory username,
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
            Erc191TestBuilder.buildMessageSignedForFlushUsername(
                evvm.getEvvmID(),
                username,
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
                nameService.getPriceToFlushUsername(username),
                priorityFeeAmountEVVM,
                nonceEVVM,
                priorityFlagEVVM,
                address(nameService)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function preparePostRegistrationAndFlush(
        AccountData memory selectedUser,
        string memory username) internal {

        addBalance(selectedUser.Address, username, 0);
        makePreRegistrationUsername(selectedUser, username, 777, 1);

        skip(30 minutes);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                777,
                2,
                0,
                2,
                true
            );

        nameService.registrationUsername(
            selectedUser.Address,
            username,
            777,
            2,
            signatureNameService,
            0,
            2,
            true,
            signatureEVVM
        );

        evvm.addBalance(
            COMMON_USER_NO_STAKER_3.Address,
            MATE_TOKEN_ADDRESS,
            1.67 ether
        );

        (signatureNameService, signatureEVVM) = makeMakeOfferSignatures(
            COMMON_USER_NO_STAKER_3,
            username,
            block.timestamp + 30 days,
            1.67 ether,
            3,
            0,
            3,
            true
        );

        nameService.makeOffer(
            COMMON_USER_NO_STAKER_3.Address,
            username,
            block.timestamp + 30 days,
            1.67 ether,
            3,
            signatureNameService,
            0,
            3,
            true,
            signatureEVVM
        );

        evvm.addBalance(
            selectedUser.Address,
            MATE_TOKEN_ADDRESS,
            nameService.getPriceToFlushUsername(username)
        );

        (signatureNameService, signatureEVVM) = makeFlushUsernameSignatures(
            selectedUser,
            username,
            4,
            0,
            4,
            true
        );

        nameService.flushUsername(
            selectedUser.Address,
            username,
            4,
            signatureNameService,
            0,
            4,
            true,
            signatureEVVM
        );
    }

    /**
     * Function to test:
     * nS: No staker
     * S: Staker
     * PF: Includes priority fee
     * nPF: No priority fee
     */

    struct RegistrationUsernameFuzzTestInput_nPF {
        uint8 nonceNameService;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 clowNumber;
        uint16 seed;
        bool makeOfferAndFlush;
    }

    struct RegistrationUsernameFuzzTestInput_PF {
        uint8 nonceNameService;
        uint8 nonceEVVM;
        bool priorityFlagEVVM;
        uint16 priorityFeeAmount;
        uint16 clowNumber;
        uint16 seed;
        bool makeOfferAndFlush;
    }

    function test__fuzz__registrationUsername__nS_nPF(
        RegistrationUsernameFuzzTestInput_nPF memory input
    ) external {
        input.nonceNameService = uint8(bound(input.nonceNameService, 11, 250));
        input.nonceEVVM = uint8(bound(input.nonceEVVM, 11, 250));
        vm.assume((input.seed / 2) >= 4);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        if (input.makeOfferAndFlush) preparePostRegistrationAndFlush(selectedUser,username);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, username, 0);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceNameService,
                0,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);
        nameService.registrationUsername(
            selectedUser.Address,
            username,
            input.clowNumber,
            input.nonceNameService,
            signatureNameService,
            0,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata(username);

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.getBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__registrationUsername__nS_PF(
        RegistrationUsernameFuzzTestInput_PF memory input
    ) external {
        input.nonceNameService = uint8(bound(input.nonceNameService, 11, 250));
        input.nonceEVVM = uint8(bound(input.nonceEVVM, 11, 250));
        vm.assume((input.seed / 2) >= 4);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        if (input.makeOfferAndFlush) preparePostRegistrationAndFlush(selectedUser,username);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, username, input.priorityFeeAmount);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceNameService,
                input.priorityFeeAmount,
                nonce,
                input.priorityFlagEVVM
            );

        vm.startPrank(COMMON_USER_NO_STAKER_3.Address);
        nameService.registrationUsername(
            selectedUser.Address,
            username,
            input.clowNumber,
            input.nonceNameService,
            signatureNameService,
            input.priorityFeeAmount,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata(username);

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.getBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_3.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__fuzz__registrationUsername__S_nPF(
        RegistrationUsernameFuzzTestInput_nPF memory input
    ) external {
        input.nonceNameService = uint8(bound(input.nonceNameService, 11, 250));
        input.nonceEVVM = uint8(bound(input.nonceEVVM, 11, 250));
        vm.assume((input.seed / 2) >= 4);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);

        if (input.makeOfferAndFlush) preparePostRegistrationAndFlush(selectedUser,username);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, username, 0);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceNameService,
                0,
                nonce,
                input.priorityFlagEVVM
            );

        uint256 balanceStakerBefore = evvm.getBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        nameService.registrationUsername(
            selectedUser.Address,
            username,
            input.clowNumber,
            input.nonceNameService,
            signatureNameService,
            0,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata(username);

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.getBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (evvm.getRewardAmount() * 50) + balanceStakerBefore
        );
    }

    function test__fuzz__registrationUsername__S_PF(
        RegistrationUsernameFuzzTestInput_PF memory input
    ) external {
        input.nonceNameService = uint8(bound(input.nonceNameService, 11, 250));
        input.nonceEVVM = uint8(bound(input.nonceEVVM, 11, 250));
        vm.assume((input.seed / 2) >= 4);

        AccountData memory selectedUser = (input.seed % 2 == 0)
            ? COMMON_USER_NO_STAKER_1
            : COMMON_USER_NO_STAKER_2;
        string memory username = makeUsername(input.seed);



        if (input.makeOfferAndFlush) preparePostRegistrationAndFlush(selectedUser,username);

        uint256 nonce = input.priorityFlagEVVM
            ? input.nonceEVVM
            : evvm.getNextCurrentSyncNonce(selectedUser.Address);

        addBalance(selectedUser.Address, username, input.priorityFeeAmount);
        makePreRegistrationUsername(
            selectedUser,
            username,
            input.clowNumber,
            10
        );

        skip(30 minutes);

        (
            bytes memory signatureNameService,
            bytes memory signatureEVVM
        ) = makeRegistrationUsernameSignatures(
                selectedUser,
                username,
                input.clowNumber,
                input.nonceNameService,
                input.priorityFeeAmount,
                nonce,
                input.priorityFlagEVVM
            );

        uint256 balanceStakerBefore = evvm.getBalance(
            COMMON_USER_STAKER.Address,
            MATE_TOKEN_ADDRESS
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        nameService.registrationUsername(
            selectedUser.Address,
            username,
            input.clowNumber,
            input.nonceNameService,
            signatureNameService,
            input.priorityFeeAmount,
            nonce,
            input.priorityFlagEVVM,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, uint256 expirationDate) = nameService
            .getIdentityBasicMetadata(username);

        assertEq(user, selectedUser.Address);
        assertEq(expirationDate, block.timestamp + 366 days);
        assertEq(evvm.getBalance(selectedUser.Address, MATE_TOKEN_ADDRESS), 0);
        assertEq(
            evvm.getBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            (evvm.getRewardAmount() * 50) +
                balanceStakerBefore +
                input.priorityFeeAmount
        );
    }
}
