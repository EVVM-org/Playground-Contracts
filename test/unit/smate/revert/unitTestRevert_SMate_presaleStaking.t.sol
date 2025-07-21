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
import {EvvmStructs} from "@EVVM/playground/evvm/lib/EvvmStructs.sol";

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestRevert_SMate_presaleStaking is Test, Constants {
    SMateMock sMate;
    Evvm evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(sMate));
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

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPresaleStaking();
        skip(1 days);
        sMate.confirmChangeAllowPresaleStaking();

        sMate.addPresaleStaker(COMMON_USER_NO_STAKER_1.Address);
        vm.stopPrank();
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

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.seeMateReward() * 2) * numberOfTx;
    }

    function makeSignature(
        bool isStaking,
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
                    sMate.priceOfSMate() * 1,
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
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                isStaking,
                1,
                nonceSmate
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
    }

    /**
     * Function to test:
     * nGU: nonGoldenUser
     * bPaySigAt[section]: incorrect payment signature // bad signature
     * bStakeSigAt[section]: incorrect stake signature // bad signature
     * wValAt[section]: wrong value
     * some denominations on test can be explicit expleined
     */

    function test__unitRevert__presaleStaking__bPaySigAtSigner() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtToAddress() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    /*
     ! note: if sMate in the future has a MNS identity, then rework
     !       this test
     */
    function test__unitRevert__presaleStaking__bPaySigAtToIdentity() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "smate",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtTokenAddress() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                ETHER_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtAmount() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                777,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtPriorityFee() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                777,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtNonce() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                11111,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtPriorityFlag() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                false,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bPaySigAtExecutor() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(0)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bStakeSigAtSigner() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bStakeSigAtIsStakingFlag()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                false,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bStakeSigAtAmount() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                10,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__bStakeSigAtNonce() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(true, 1, 111)
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    /*
    function test__unitRevert__presaleStaking__() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(
                COMMON_USER_STAKER.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }
    */

    function test__unitRevert__presaleStaking__notAPresaleStakingr() external {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_2.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_2.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(COMMON_USER_NO_STAKER_2.Address));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__nonceAlreadyUsed() external {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            1001001
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__allowExternalStakingIsFalse()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();
        vm.stopPrank();

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            1,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__userTriesToStakeMoreThanOne()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                true,
                2,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__userStakeMoreThanTheLimit()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            3,
            0
        );

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            totalOfPriorityFee,
            102,
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
            (totalOfMate / 3) + totalOfPriorityFee
        );

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unitRevert__presaleStaking__userUnstakeWithoutStaking()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            0,
            0
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                10001,
                true,
                address(sMate)
            )
        );

        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPresaleStaking(
                false,
                1,
                1001001
            )
        );
        bytes memory signatureSMate = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            1001001,
            signatureSMate,
            totalOfPriorityFee,
            10001,
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

        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__presaleStaking_AsyncExecution__fullUnstakeDosentRespectTimeLimit()
        external
    {
        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            103,
            true,
            103
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            103,
            signatureSMate,
            0,
            103,
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

    function test__unit_revert__presaleStaking_AsyncExecution__notInTimeToRestake()
        external
    {
        vm.startPrank(ADMIN.Address);
        sMate.proposeSetSecondsToUnlockStaking(5 days);
        skip(1 days);
        sMate.acceptSetSecondsToUnlockStaking();
        vm.stopPrank();

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1.Address,
            2,
            0
        );

        bytes memory signatureEVVM;
        bytes memory signatureSMate;

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            100,
            true,
            100
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            100,
            signatureSMate,
            0,
            100,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            101,
            true,
            101
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            101,
            signatureSMate,
            0,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            102,
            true,
            102
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            102,
            signatureSMate,
            0,
            102,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            false,
            0,
            103,
            true,
            103
        );

        skip(sMate.getSecondsToUnlockFullUnstaking());

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        sMate.presaleStaking(
            false,
            COMMON_USER_NO_STAKER_1.Address,
            103,
            signatureSMate,
            0,
            103,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureEVVM, signatureSMate) = makeSignature(
            true,
            0,
            104,
            true,
            104
        );

        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);
        vm.expectRevert();
        sMate.presaleStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            104,
            signatureSMate,
            0,
            104,
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
