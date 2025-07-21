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

import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mns/MateNameServiceMock.sol";
import {EvvmMock} from "@EVVM/playground/evvm/EvvmMock.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {EstimatorMock} from "@EVVM/playground/staking/EstimatorMock.sol";
import {EvvmMockStorage} from "@EVVM/playground/evvm/lib/EvvmMockStorage.sol";

contract unitTestRevert_EVVM_proxy is Test, Constants {
    /**
     * Naming Convention for Init Test Functions
     * Basic Structure:
     * test__init__[typeOfTest]__[functionName]__[errorType]
     * General Rules:
     *  - Always start with "test__"
     *  - The name of the function to be executed must immediately follow "test__"
     *  - Options are added at the end, separated by underscores
     *
     * Example:
     * test__init__payNoMateStaking_sync__nonceAlreadyUsed
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
    MateNameServiceMock mns;

    ExtraFunctionsV1 v1;
    address addressV1;

    bytes32 constant DEPOSIT_IDENTIFIER = bytes32(uint256(1));
    bytes32 constant WITHDRAW_IDENTIFIER = bytes32(uint256(2));

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

        v1 = new ExtraFunctionsV1();
        addressV1 = address(v1);

        vm.stopPrank();
    
        evvm._setPointStaker(COMMON_USER_STAKER.Address, 0x01);
    }

    function test__init__revert__proposeImplementation__notAdmin() public {
        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        evvm.proposeImplementation(addressV1);

        vm.stopPrank();
    }

    function test__init__revert__acceptImplementation__notAdmin() public {
        vm.startPrank(ADMIN.Address);
        evvm.proposeImplementation(addressV1);
        vm.stopPrank();

        skip(30 days);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        vm.expectRevert();
        evvm.acceptImplementation();

        vm.stopPrank();
    }

    function test__init__revert__acceptImplementation__tryToAcceptBeforeTime()
        public
    {
        vm.startPrank(ADMIN.Address);

        evvm.proposeImplementation(addressV1);

        //time less than 30 days
        skip(29 days);

        vm.expectRevert();
        evvm.acceptImplementation();

        vm.stopPrank();
    }

    function test__init__revert__rejectUpgrade__notAdmin() public {
        vm.startPrank(ADMIN.Address);
        evvm.proposeImplementation(addressV1);
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);
        vm.expectRevert();
        evvm.rejectUpgrade();
        vm.stopPrank();
    }

    /// @notice because we tested in others init thes the pay
    ///         with no implementation we begin with 1 update
    function test__init__revert__TxAndUseProxy__doesNotHaveImplementation()
        public
    {
        vm.expectRevert();
        IExtraFunctionsV1(address(evvm)).burnToken(
            COMMON_USER_NO_STAKER_1.Address,
            MATE_TOKEN_ADDRESS,
            10
        );
    }
}

interface IExtraFunctionsV1 {
    function burnToken(address user, address token, uint256 amount) external;
}

contract ExtraFunctionsV1 is EvvmMockStorage {
    function burnToken(address user, address token, uint256 amount) external {
        if (balances[user][token] < amount) {
            revert();
        }

        balances[user][token] -= amount;
    }
}
