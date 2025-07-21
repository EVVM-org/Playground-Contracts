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
import {EvvmMockStructs} from "@EVVM/playground/evvm/lib/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/evvm/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/evvm/lib/EvvmMockStorage.sol";

contract unitTestRevert_SMate_goldenStaking is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new EvvmMock(ADMIN.Address, address(sMate));
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
    }

    function giveMateToExecute(
        address user,
        uint256 sMateAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user,
            MATE_TOKEN_ADDRESS,
            (sMate.priceOfSMate() * sMateAmount) + priorityFee
        );

        totalOfMate = (sMate.priceOfSMate() * sMateAmount);
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
        returns (bytes memory signatureEVVM, bytes memory signatureSMate)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(sMate),
                    "",
                    MATE_TOKEN_ADDRESS,
                    sMate.priceOfSMate() * amountOfSmate,
                    priorityFee,
                    nonceEVVM,
                    priorityEVVM,
                    address(sMate)
                )
            );
        } else {
            (v, r, s) = vm.sign(
                COMMON_USER_NO_STAKER_1.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(sMate),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFee,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(sMate)
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
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(COMMON_USER_NO_STAKER_1.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            totalOfMate + totalOfPriorityFee
        );
    }

    /*
     ! note: if sMate in the future has a MNS identity, then rework
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
                "sMate",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                ETHER_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                1,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                1000,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                777,
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                true,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        vm.expectRevert();
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
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
        sMate.goldenStaking(true, 1, signatureEVVM);

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 10, signatureEVVM);

        vm.expectRevert();
        sMate.goldenStaking(false, 10, "");

        vm.stopPrank();

        assert(evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
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
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 10, signatureEVVM);

        vm.expectRevert();
        sMate.goldenStaking(false, 420, "");

        vm.stopPrank();

        assert(evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1)
        );
    }

    function test__unitRevert__goldenStaking__notInTimeToStake() external {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(5 days);
        skip(1 days);
        sMate.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            GOLDEN_STAKER.Address,
            10,
            0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            GOLDEN_STAKER.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                0,
                evvm.getNextCurrentSyncNonce(GOLDEN_STAKER.Address),
                false,
                address(sMate)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(GOLDEN_STAKER.Address);

        sMate.goldenStaking(true, 10, signatureEVVM);

        skip(sMate.getSecondsToUnlockFullUnstaking());

        sMate.goldenStaking(false, 10, "");

        vm.expectRevert();
        sMate.goldenStaking(true, 10, "");

        vm.stopPrank();

        assert(!evvm.isMateStaker(GOLDEN_STAKER.Address));
        assertEq(
            evvm.seeBalance(GOLDEN_STAKER.Address, MATE_TOKEN_ADDRESS),
            getAmountOfRewardsPerExecution(1) + totalOfMate
        );
    }
}
