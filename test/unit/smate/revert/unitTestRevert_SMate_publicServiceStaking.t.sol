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
import {EvvmMockStructs} from "@EVVM/playground/core/EvvmMockStructs.sol";

import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/core/EvvmMockStorage.sol";

contract unitTestRevert_SMate_publicServiceStaking is Test, Constants {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mns;
    MockContract mock;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());
        mns = MateNameServiceMock(evvm.getMateNameServiceAddress());
        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
        mock = new MockContract(address(sMate));
    }

    modifier enableStaking() {
        vm.startPrank(ADMIN.Address);

        sMate.prepareChangeAllowPublicStaking();
        skip(1 days);
        sMate.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        _;
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
        address serviceAddress,
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                serviceAddress,
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

    function test__unit_revert__publicServiceStaking__funcionNotEnabled()
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    /*
    function test__unit_revert__publicServiceStaking__() public enableStaking {
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }
    */

    function test__unit_revert__publicServiceStaking__bPaySigAtSigner()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtToAddress()
        public
        enableStaking
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
                address(mock),
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtToIdentity()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtTokenAddress()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtAmount()
        public
        enableStaking
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
                7,
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtPriorityFee()
        public
        enableStaking
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
                777,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtNonce()
        public
        enableStaking
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
                777,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtPriorityFlag()
        public
        enableStaking
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
                false,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bPaySigAtExecutorAddress()
        public
        enableStaking
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
                address(0)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bStakeSigAtSigner()
        public
        enableStaking
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
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bStakeSigAtServiceAddress()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(this),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bStakeSigAtIsStakingFlag()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                false,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bStakeSigAtAmount()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                555,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__bStakeSigAtNonce()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                777
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__NonceAlreadyUsed()
        public
        enableStaking
    {
        bytes memory signatureEVVM;
        bytes memory signatureSMate;
        uint8 v;
        bytes32 r;
        bytes32 s;

        (uint256 totalOfMate, uint256 totalOfPriorityFee) = giveMateToExecute(
            COMMON_USER_NO_STAKER_1,
            (111) * 2,
            0 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(sMate),
                "",
                MATE_TOKEN_ADDRESS,
                (totalOfMate / 2),
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
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
                (totalOfMate / 2),
                totalOfPriorityFee,
                1001,
                true,
                address(sMate)
            )
        );

        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            (totalOfMate / 2) + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__ServiceAddressIsNotAService()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                WILDCARD_USER.Address,
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            WILDCARD_USER.Address,
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.isMateStaker(address(mock)));
        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    function test__unit_revert__publicServiceStaking__UnstakingServiceIsDiferentToUserAddress()
        public
        enableStaking
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
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                address(mock),
                true,
                111,
                1001001
            )
        );
        signatureSMate = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        
        sMate.publicServiceStaking(
            true,
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            1001001,
            111,
            signatureSMate,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        vm.expectRevert();
        mock.unstake(
            111,
            1001001,
            COMMON_USER_NO_STAKER_1.Address
        );

        assert(evvm.isMateStaker(address(mock)));

    }
}

contract MockContract {
    SMateMock sMate;
    EvvmMock evvm;

    constructor(address sMateAddress) {
        sMate = SMateMock(sMateAddress);
        evvm = EvvmMock(sMate.getEvvmAddress());
    }

    function unstake(uint256 amount, uint256 nonceSMate, address _user) public {
        sMate.publicServiceStaking(
            false,
            _user,
            address(this),
            nonceSMate,
            amount,
            bytes(""),
            0,
            0,
            false,
            bytes("")
        );
    }

    function getBackMate(address user) public {
        evvm.caPay(
            user,
            0x0000000000000000000000000000000000000001,
            evvm.seeBalance(
                address(this),
                0x0000000000000000000000000000000000000001
            )
        );
    }
}
