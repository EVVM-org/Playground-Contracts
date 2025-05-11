// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function revert behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */

pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";

import {SMateMock} from "mock-contracts/SMateMock.sol";
import {MateNameServiceMock} from "mock-contracts/MateNameServiceMock.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {Erc191TestBuilder} from "@RollAMate/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "mock-contracts/EstimatorMock.sol";
import {EvvmMockStorage} from "mock-contracts/EvvmMockStorage.sol";
import {AdvancedStrings} from "@RollAMate/libraries/AdvancedStrings.sol";

contract unitTestRevert_MateNameService_preRegistrationUsername is
    Test,
    Constants
{
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
    }

    function addBalance(
        AccountData memory user,
        address token,
        uint256 priorityFeeAmount
    ) private returns (uint256 totalPriorityFeeAmount) {
        evvm._addBalance(user.Address, token, priorityFeeAmount);

        totalPriorityFeeAmount = priorityFeeAmount;
    }

    function makePreRegistrationUsernameSignature(
        AccountData memory user,
        string memory username,
        uint256 clowNumber,
        uint256 nonceMNS,
        bool givePriorityFee,
        uint256 priorityFeeAmount,
        uint256 nonceEVVM,
        bool priorityEVVM
    )
        private
        view
        returns (bytes memory signatureMNS, bytes memory signatureEVVM)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (givePriorityFee) {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                    keccak256(abi.encodePacked(username, uint256(clowNumber))),
                    nonceMNS
                )
            );
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPay(
                    address(mns),
                    "",
                    MATE_TOKEN_ADDRESS,
                    priorityFeeAmount,
                    0,
                    nonceEVVM,
                    priorityEVVM,
                    address(mns)
                )
            );
            signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);
        } else {
            (v, r, s) = vm.sign(
                user.PrivateKey,
                Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                    keccak256(abi.encodePacked(username, uint256(clowNumber))),
                    nonceMNS
                )
            );
            signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
            signatureEVVM = "";
        }
    }

    /**
     * Function to test:
     * bSigAt[variable]: bad signature at
     * bPaySigAt[variable]: bad payment signature at
     * some denominations on test can be explicit expleined
     */

    function test__unit_revert__preRegistrationUsername__bSigAtSigner()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bSigAtHashUsernameUser()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("user", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bSigAtHashUsernameClowNumber()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(777))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bSigAtNonceMNS()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                777
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtSigner()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_2.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtToAddress()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(evvm),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtToIdentity()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(0),
                "mns",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtTokenAddress()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                ETHER_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtAmount()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                0.1 ether,
                0,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtPriorityFeeAmount()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0.01 ether,
                101,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtNonceEVVM()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                777,
                true,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtPriorityFlag()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                false,
                address(mns)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__bPaySigAtExecutor()
        external
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPreRegistrationUsername(
                keccak256(abi.encodePacked("test", uint256(10101))),
                1001
            )
        );
        signatureMNS = Erc191TestBuilder.buildERC191Signature(v, r, s);
        (v, r, s) = vm.sign(
            COMMON_USER_NO_STAKER_1.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                address(mns),
                "",
                MATE_TOKEN_ADDRESS,
                totalPriorityFeeAmount,
                0,
                101,
                true,
                address(0)
            )
        );
        signatureEVVM = Erc191TestBuilder.buildERC191Signature(v, r, s);

        vm.startPrank(COMMON_USER_STAKER.Address);

        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            0
        );
    }

    function test__unit_revert__preRegistrationUsername__EVVMnonceAlreadyUsed()
        external
    {
        bytes memory signatureMNS;
        bytes memory signatureEVVM;

        uint256 totalPriorityFeeAmount = addBalance(
            COMMON_USER_NO_STAKER_1,
            MATE_TOKEN_ADDRESS,
            0.001 ether
        );

        (signatureMNS, signatureEVVM) = makePreRegistrationUsernameSignature(
            COMMON_USER_NO_STAKER_1,
            "user",
            10101,
            1001,
            true,
            0,
            101,
            true
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("user", uint256(10101))),
            0,
            signatureMNS,
            101,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (signatureMNS, signatureEVVM) = makePreRegistrationUsernameSignature(
            COMMON_USER_NO_STAKER_1,
            "test",
            10101,
            1001,
            true,
            totalPriorityFeeAmount,
            202,
            true
        );

        vm.startPrank(COMMON_USER_STAKER.Address);
        vm.expectRevert();
        mns.preRegistrationUsername(
            COMMON_USER_NO_STAKER_1.Address,
            1001,
            keccak256(abi.encodePacked("test", uint256(10101))),
            totalPriorityFeeAmount,
            signatureMNS,
            202,
            true,
            signatureEVVM
        );
        vm.stopPrank();

        (address user, ) = mns.getIdentityBasicMetadata(
            string.concat(
                "@",
                AdvancedStrings.bytes32ToString(
                    keccak256(abi.encodePacked("test", uint256(10101)))
                )
            )
        );
        assertEq(user, address(0));

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            totalPriorityFeeAmount
        );
        assertEq(
            evvm.seeBalance(COMMON_USER_STAKER.Address, MATE_TOKEN_ADDRESS),
            evvm.seeMateReward()
        );
    }
}
