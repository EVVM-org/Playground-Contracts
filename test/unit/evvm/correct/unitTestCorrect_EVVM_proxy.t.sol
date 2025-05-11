// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for SMate function correct behavior
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

contract unitTestCorrect_EVVM_proxy is Test, Constants {
    /**
     * Naming Convention for Init Test Functions
     * Basic Structure:
     * test__init__[typeOfTest]__[functionName]__[options]
     * General Rules:
     *  - Always start with "test__"
     *  - The name of the function to be executed must immediately follow "test__"
     *  - Options are added at the end, separated by underscores
     *
     * Example:
     * test__init__payNoMateStaking_sync__PF_nEX
     *
     * Example explanation:
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nEX: Does not include executor execution
     *
     * Notes:
     * Separate different parts of the name with double underscores (__)
     *
     * For this unit test two users execute 2 pay transactions before and
     * after the update, so insetad of the name of the function proxy we
     * going to use TxAndUseProxy to make the test more readable and
     * understandable
     *
     * Options fot this test:
     * - xU: Evvm updates x number of times
     */

    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;

    TartarusV1 v1;
    address addressV1;

    TartarusV2 v2;
    address addressV2;

    TartarusV3 v3;
    address addressV3;

    CounterDummy counter;
    address addressCounter;

    function setUp() public {
        sMate = new SMateMock(ADMIN.Address);
        evvm = EvvmMock(sMate.getEvvmAddress());
        estimator = EstimatorMock(sMate.getEstimatorAddress());

        v1 = new TartarusV1();
        addressV1 = address(v1);

        v2 = new TartarusV2();
        addressV2 = address(v2);

        counter = new CounterDummy();
        addressCounter = address(counter);
        v3 = new TartarusV3(address(addressCounter));
        addressV3 = address(v3);

        vm.stopPrank();
    }

    function makePayment(
        bool giveTokensForPayment,
        AccountData memory userToInteract,
        address addressTo,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee
    ) internal {
        if (giveTokensForPayment) {
            evvm._addBalance(
                userToInteract.Address,
                tokenAddress,
                amount + priorityFee
            );
        }
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            userToInteract.PrivateKey,
            Erc191TestBuilder.buildMessageSignedForPay(
                addressTo,
                "",
                tokenAddress,
                amount,
                priorityFee,
                evvm.getNextCurrentSyncNonce(userToInteract.Address),
                false,
                address(0)
            )
        );
        bytes memory signatureEVVM = Erc191TestBuilder.buildERC191Signature(
            v,
            r,
            s
        );

        evvm.payNoMateStaking_sync(
            userToInteract.Address,
            addressTo,
            "",
            tokenAddress,
            amount,
            priorityFee,
            address(0),
            signatureEVVM
        );
    }

    function updateImplementation(address newImplementation) internal {
        vm.startPrank(ADMIN.Address);
        evvm.proposeImplementation(newImplementation);
        skip(30 days);
        evvm.acceptImplementation();
        vm.stopPrank();
    }

    function test__unit_correct__proposeImplementation() public {
        vm.startPrank(ADMIN.Address);
        evvm.proposeImplementation(addressV1);
        vm.stopPrank();

        assertEq(evvm.getCurrentImplementation(), address(0));
        assertEq(evvm.getProposalImplementation(), addressV1);
        assertEq(
            evvm.getTimeToAcceptImplementation(),
            block.timestamp + 30 days
        );
    }

    function test__unit_correct__acceptImplementation() public {
        vm.startPrank(ADMIN.Address);
        evvm.proposeImplementation(addressV1);
        skip(30 days);
        evvm.acceptImplementation();
        vm.stopPrank();

        assertEq(evvm.getCurrentImplementation(), addressV1);
        assertEq(evvm.getProposalImplementation(), address(0));
        assertEq(evvm.getTimeToAcceptImplementation(), 0);
    }

    function test__unit_correct__rejectUpgrade() public {
        vm.startPrank(ADMIN.Address);
        evvm.proposeImplementation(addressV1);
        skip(1 days);
        evvm.rejectUpgrade();
        vm.stopPrank();

        assertEq(evvm.getCurrentImplementation(), address(0));
        assertEq(evvm.getProposalImplementation(), address(0));
        assertEq(evvm.getTimeToAcceptImplementation(), 0);
    }

    /// @notice because we tested in others init thes the pay
    ///         with no implementation we begin with 1 update
    function test__unit_correct__TxAndUseProxy__1U() public {
        makePayment(
            true,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100000,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        updateImplementation(addressV1);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );

        ITartarusV1(address(evvm)).burnToken(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            90
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99990
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );
    }

    function test__unit_correct__TxAndUseProxy__2U() public {
        makePayment(
            true,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100000,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        updateImplementation(addressV1);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );

        ITartarusV1(address(evvm)).burnToken(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            90
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99990
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        updateImplementation(addressV2);

        ITartarusV2(address(evvm)).fullTransfer(
            COMMON_USER_NO_STAKER_2.Address,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            99990
        );

        makePayment(
            true,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );
    }

    function test__unit_correct__TxAndUseProxy__3U() public {
        makePayment(
            true,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100000,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        updateImplementation(addressV1);

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );

        ITartarusV1(address(evvm)).burnToken(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            90
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            99990
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        updateImplementation(addressV2);

        ITartarusV2(address(evvm)).fullTransfer(
            COMMON_USER_NO_STAKER_2.Address,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            99990
        );

        makePayment(
            true,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            100,
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );

        updateImplementation(addressV3);

        ITartarusV3(address(evvm)).burnToken(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            99900
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );

        assertEq(ITartarusV3(address(evvm)).getCounter(), 1);

        makePayment(
            false,
            COMMON_USER_NO_STAKER_2,
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            50,
            0
        );

        makePayment(
            false,
            COMMON_USER_NO_STAKER_1,
            COMMON_USER_NO_STAKER_2.Address,
            MATE_TOKEN_ADDRESS,
            50,
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_1.Address,
                MATE_TOKEN_ADDRESS
            ),
            0
        );

        assertEq(
            evvm.seeBalance(
                COMMON_USER_NO_STAKER_2.Address,
                MATE_TOKEN_ADDRESS
            ),
            100
        );
    }
}

interface ITartarusV1 {
    function burnToken(address user, address token, uint256 amount) external;
}

contract TartarusV1 is EvvmMockStorage {
    function burnToken(address user, address token, uint256 amount) external {
        if (balances[user][token] < amount) {
            revert();
        }

        balances[user][token] -= amount;
    }
}

interface ITartarusV2 {
    function burnToken(address user, address token, uint256 amount) external;

    function fullTransfer(address from, address to, address token) external;
}

contract TartarusV2 is EvvmMockStorage {
    function fullTransfer(address from, address to, address token) external {
        balances[to][token] += balances[from][token];
        balances[from][token] -= balances[from][token];
    }
}

interface ITartarusV3 {
    function burnToken(address user, address token, uint256 amount) external;

    function getCounter() external view returns (uint256);
}

// Primero definimos la interfaz
interface ICounter {
    function increment() external;

    function getCounter() external view returns (uint256);
}

contract TartarusV3 is EvvmMockStorage {
    address public immutable counterAddress;

    constructor(address _counterAddress) {
        counterAddress = _counterAddress;
    }

    function burnToken(address user, address token, uint256 amount) external {
        if (balances[user][token] < amount) {
            revert();
        }

        balances[user][token] -= amount;

        ICounter(counterAddress).increment();
    }

    function getCounter() external view returns (uint256) {
        // Usamos la interfaz para la llamada
        (bool success, bytes memory data) = counterAddress.staticcall(
            abi.encodeWithSignature("getCounter()")
        );
        if (!success) {
            revert();
        }
        return abi.decode(data, (uint256));
    }
}

contract CounterDummy {
    uint256 counterNum;

    function increment() external {
        counterNum++;
    }

    function getCounter() external view returns (uint256) {
        return counterNum;
    }
}
