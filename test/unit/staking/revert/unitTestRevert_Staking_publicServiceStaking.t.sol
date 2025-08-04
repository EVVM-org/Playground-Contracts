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

import {Constants, MockContract} from "test/Constants.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/playground/lib/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";

contract unitTestRevert_Staking_publicServiceStaking is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    MockContract mock;

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
        mock = new MockContract(address(staking));
    }

    modifier enableStaking() {
        vm.startPrank(ADMIN.Address);

        staking.prepareChangeAllowPublicStaking();
        skip(1 days);
        staking.confirmChangeAllowPublicStaking();

        vm.stopPrank();

        _;
    }

    function giveMateToExecute(
        AccountData memory user,
        uint256 stakingAmount,
        uint256 priorityFee
    ) private returns (uint256 totalOfMate, uint256 totalOfPriorityFee) {
        evvm._addBalance(
            user.Address,
            MATE_TOKEN_ADDRESS,
            (staking.priceOfStaking() * stakingAmount) + priorityFee
        );

        totalOfMate = (staking.priceOfStaking() * stakingAmount);
        totalOfPriorityFee = priorityFee;
    }

    function getAmountOfRewardsPerExecution(
        uint256 numberOfTx
    ) private view returns (uint256) {
        return (evvm.getRewardAmount() * 2) * numberOfTx;
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
        returns (bytes memory signatureEVVM, bytes memory signatureStaking)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (isStaking) {
            (v, r, s) = vm.sign(
                signer.PrivateKey,
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
                signer.PrivateKey,
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
            signer.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPublicServiceStake(
                serviceAddress,
                isStaking,
                amountOfSmate,
                nonceSmate
            )
        );
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalOfMate + totalOfPriorityFee
        );
    }

    /*
    function test__unit_revert__publicServiceStaking__() public enableStaking {
        bytes memory signatureEVVM;
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                ETHER_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                7,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                777,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                777,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                false,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                (totalOfMate / 2),
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                (totalOfMate / 2),
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        vm.expectRevert();
        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            WILDCARD_USER.Address,
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        assert(!evvm.istakingStaker(address(mock)));
        assertEq(
            evvm.getBalance(
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
        bytes memory signatureStaking;
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
                address(staking),
                "",
                MATE_TOKEN_ADDRESS,
                totalOfMate,
                totalOfPriorityFee,
                1001,
                true,
                address(staking)
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
        signatureStaking = Erc191TestBuilder.buildERC191Signature(v, r, s);
        vm.startPrank(COMMON_USER_NO_STAKER_2.Address);

        staking.publicServiceStaking(
            COMMON_USER_NO_STAKER_1.Address,
            address(mock),
            true,
            111,
            1001001,
            signatureStaking,
            totalOfPriorityFee,
            1001,
            true,
            signatureEVVM
        );

        vm.stopPrank();

        vm.expectRevert();
        mock.unstake(111, 1001001, COMMON_USER_NO_STAKER_1.Address);

        assert(evvm.istakingStaker(address(mock)));
    }
}
