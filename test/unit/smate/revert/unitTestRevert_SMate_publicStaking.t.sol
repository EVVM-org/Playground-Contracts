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
import {EvvmMockStructs} from "mock-contracts/EvvmMockStructs.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";

contract unitTestRevert_SMate_publicStaking is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());

        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();
    }

    function giveMateToExecute(
        AccountData memory user,
        uint256 sMateAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            (sMate.priceOfSMate() * sMateAmount) + priorityFee
        );

        totalOfMate = (sMate.priceOfSMate() * sMateAmount);
        totalOfPriorityFee = priorityFee;
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
    }

    function makeSignature(
        AccountData memory signer,
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
                signer.PrivateKey,
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
                signer.PrivateKey,
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
            signer.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                isStaking,
                amountOfSmate,
                nonceSmate
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    /**
     * Function to test:
     * bPaySigAt[section]: incorrect payment signature // bad signature
     * bStakeSigAt[section]: incorrect stake signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unit_correct__presaleStake__bPaySigAtSigned() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtToAddress() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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
     ! note: if sMate in the future has a MNS identity, then rework
     !       this test
     */
    function test__unit_correct__presaleStake__bPaySigAtToIdentity() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "smate",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtToken() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                ETHER_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtAmount() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtPriorityFee() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                777,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtNonce() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                77,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtPriorityFlag() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                false,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bPaySigAtExecutor() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(evvm)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bStakeSigAtSigner() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bStakeSigAtIsStakingFlag()
        public
    {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                false,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bStakeSigAtAmount() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                777,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__bStakeSigAtNonce() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicStaking(
                true,
                111,
                777
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

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

    function test__unit_correct__presaleStake__NonceAlreadyUsed() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            2,
            0 ether
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            true,
            1,
            totalOfPriorityFee,
            1001001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            1,
            signatureSMate,
            totalOfPriorityFee,
            1001001,
            true,
            signatureEVVM
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            true,
            1,
            totalOfPriorityFee,
            2002002,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            1,
            signatureSMate,
            totalOfPriorityFee,
            2002002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            (totalOfMate / 2) + totalOfPriorityFee
        );
    }

    function test__unit_correct__presaleStake__UserTryToFullUnstakeWithoutWaitTime()
        public
    {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            true,
            111,
            totalOfPriorityFee,
            1001001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            false,
            111,
            totalOfPriorityFee,
            2002002,
            true,
            2002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        vm.expectRevert();
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            2002,
            111,
            signatureSMate,
            totalOfPriorityFee,
            2002002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        assert(evvm.isMateStaker(COMMON_USER_NO_STAKER_1.Address));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__unit_correct__presaleStake__notInTimeToRestake() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(5 days);
        skip(1 days);
        sMate.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            true,
            111,
            totalOfPriorityFee,
            1001001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001001,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        skip(sMate.getSecondsToUnlockFullUnstaking());

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            false,
            111,
            totalOfPriorityFee,
            2002002,
            true,
            2002
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            2002,
            111,
            signatureSMate,
            totalOfPriorityFee,
            2002002,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            true,
            111,
            totalOfPriorityFee,
            3003003,
            true,
            3003
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            3003,
            111,
            signatureSMate,
            totalOfPriorityFee,
            3003003,
            true,
            signatureEVVM
        );
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

    function test__unit_correct__presaleStake__UserTriesToUnstakeWithoutStaking()
        public
    {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            0,
            0 ether
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            false,
            111,
            totalOfPriorityFee,
            1001001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        vm.expectRevert();
        sMate.publicStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001001,
            true,
            signatureEVVM
        );
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

    function test__unit_correct__presaleStake__stakeWithoutFlagOnTrue() public {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            111,
            0 ether
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            COMMON_USER_NO_STAKER_1,
            true,
            111,
            totalOfPriorityFee,
            1001001,
            true,
            1001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        vm.expectRevert();
        sMate.publicStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001001,
            true,
            signatureEVVM
        );
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
}
