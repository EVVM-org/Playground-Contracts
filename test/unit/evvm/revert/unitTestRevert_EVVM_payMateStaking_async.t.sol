// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function revert behavior
 * @notice some functions has evvm functions that are implemented
 *         and dosent need to be tested here
 */
pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";

contract unitTestRevert_EVVM_payStaker_async is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

    AccountData COMMON_USER_STAKER_1 = COMMON_USER_STAKER;
    AccountData COMMON_USER_STAKER_2 = WILDCARD_USER;

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
        

        evvm.setPointStaker(COMMON_USER_STAKER_1.Address, 0x01);
        evvm.setPointStaker(COMMON_USER_STAKER_2.Address, 0x01);
    }

    function addBalance(address user, address token, uint256 amount) private {
        evvm.addBalance(user, token, amount);
    }

    /**
     * For the signature tes we going to assume the executor is a bad actor,
     * but in the executor test an fisher try to execute the payment who obivously
     * is not the executor.
     * Function to test:
     * bSigAt[section]: incorrect signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unit_revert__payStaker_async__bSigAtFrom() external {
        addBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS, 0.11 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_STAKER_1.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_2.Address,
            COMMON_USER_STAKER_1.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_2.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtToAddress()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_STAKER_1.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtToIdentity()
        external
    {
        nameService._setIdentityBaseMetadata(
            "dummy",
            NameService.IdentityBaseMetadata({
                owner: COMMON_USER_NO_STAKER_2.Address,
                expireDate: block.timestamp + 366 days,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x00
            })
        );
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                address(0),
                "dummy",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            address(0),
            "fake",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtToken() external {
        addBalance(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            0.11 ether
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            MATE_TOKEN_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtAmount() external {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 1.11 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            1.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtPriorityFee()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 1.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            1 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            1.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtNonceNumber()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1456,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtPriorityFlag()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                false,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__bSigAtToExecutor()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_2.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_2.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async_wValAtExecutor()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_2.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__userFromHasLessThanAmountPlusFee()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.8 ether,
                0.04 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.8 ether,
            0.04 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();

        assertEq(
            evvm.getBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS),
            0.11 ether
        );
    }

    function test__unit_revert__payStaker_async__nonceAlreadyUsed()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                COMMON_USER_STAKER_1.Address
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER_1.Address);

        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            COMMON_USER_STAKER_1.Address,
            signatureEVVM
        );

        vm.stopPrank();
    }

    function test__unit_revert__payStaker_async__fisherIsNotStaker()
        external
    {
        addBalance(COMMON_USER_NO_STAKER_1.Address, ETHER_ADDRESS, 0.11 ether);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                evvm.getEvvmID(),
                COMMON_USER_NO_STAKER_2.Address,
                "",
                ETHER_ADDRESS,
                0.1 ether,
                0.01 ether,
                1001,
                true,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        evvm.payStaker_async(
            COMMON_USER_NO_STAKER_1.Address,
            COMMON_USER_NO_STAKER_2.Address,
            "",
            ETHER_ADDRESS,
            0.1 ether,
            0.01 ether,
            1001,
            address(0),
            signatureEVVM
        );

        vm.stopPrank();
    }
}
