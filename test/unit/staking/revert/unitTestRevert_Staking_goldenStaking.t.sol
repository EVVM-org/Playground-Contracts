// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for 
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

contract unitTestRevert_Staking_goldenStaking is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

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
        

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function giveMateToExecute(
        address user,
        uint256 stakingAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (staking.priceOfStaking() * stakingAmount) + priorityFee
        );

        totalOfMate = (staking.priceOfStaking() * stakingAmount);
        totalOfPriorityFee = priorityFee;
    }

    function makeSignature(
        bool isStaking,
        uint256 amountOfSmate,
        uint256 priorityFee,
        uint256 nonceEVVM,
        bool priorityEVVM,
        uint256 nonceSmate
    )
        private
        view
        returns (bytes memory signatureEVVM, bytes memory signatureStaking)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(staking),
                    "",
                    MATE_TOKEN_ADDRESS,
                    staking.priceOfStaking() * amountOfSmate,
                    priorityFee,
                    nonceEVVM,
                    priorityEVVM,
                    address(staking)
                )
            );
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(staking),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFee,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(staking)
                )
            );
        }

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                isStaking,
                amountOfSmate,
                nonceSmate
            )
        );
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.getRewardAmount() * 2) * numberOfTx;
    }

    /**
     * Function to test:
     * nGU: nonGoldenUser
     * bPaySigAt[section]: incorrect payment signature // bad signature
     * bSigAt[section]: incorrect signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unitRevert__goldenStaking__nGU() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    /*
    function test__unitRevert__goldenStaking__bSigAt() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();
    }
    */

    function test__unitRevert__goldenStaking__bPaySigAtFrom() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            WILDCARD_USER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtToAddress() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(this),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    /*
     ! note: if staking in the future has a NameService identity, then rework
     !       this test
     */
    function test__unitRevert__goldenStaking__bPaySigAtToIdentity() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "staking",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtTokenAddress() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                ETHER_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtAmount() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                1,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtPriorityFee() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                1000,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtNonce() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                777,
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtPriorityFlag() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                true,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__bPaySigAtExecutor() external {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            1,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        staking.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unitRevert__goldenStaking__notInTimeToFullUnstake()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            10,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        staking.goldenStaking(true, 10, signatureEVVM);

        vm.expectRevert();
        staking.goldenStaking(false, 10, "");

        vm.stopPrank();

        assert(evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1)
        );
    }

    function test__unitRevert__goldenStaking__unstakeIsMoreThanStake()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            10,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        staking.goldenStaking(true, 10, signatureEVVM);

        vm.expectRevert();
        staking.goldenStaking(false, 420, "");

        vm.stopPrank();

        assert(evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1)
        );
    }

    function test__unitRevert__goldenStaking__notInTimeToStake() external {
        vm.startPrank(ADMIN.Address);
        staking.proposeSetSecondsToUnlockStaking(5 days);
        skip(1 days);
        staking.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            10,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(staking)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        staking.goldenStaking(true, 10, signatureEVVM);

        skip(staking.getSecondsToUnlockFullUnstaking());

        staking.goldenStaking(false, 10, "");

        vm.expectRevert();
        staking.goldenStaking(true, 10, "");

        vm.stopPrank();

        assert(!evvm.isAddressStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.getBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfMate
        );
    }
}
