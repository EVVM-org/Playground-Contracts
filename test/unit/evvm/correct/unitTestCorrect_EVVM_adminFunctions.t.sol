// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function correct behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */

pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants} from "test/Constants.sol";

import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Erc191TestBuilder} from "@EVVM/libraries/Erc191TestBuilder.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";

contract unitTestCorrect_EVVM_adminFunctions is Test, Constants {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    function setUp() public {
        staking = new Staking(ADMIN.Address, GOLDEN_STAKER.Address);
        evvm = new Evvm(ADMIN.Address, address(staking));
        estimator = new Estimator(
            ACTIVATOR.Address,
            address(evvm),
            address(staking),
            ADMIN.Address
        );
        nameService = new NameService(address(evvm), ADMIN.Address);

        staking._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupNameServiceAddress(address(nameService));
        
    }

    /**
     * Function to test: payNoMateStaking_sync
     * PF: Includes priority fee
     * nPF: No priority fee
     * EX: Includes executor execution
     * nEX: Does not include executor execution
     * ID: Uses a MNS identity
     * AD: Uses an address
     */

    function test__unit_correct__set_owner() external {
        vm.startPrank(ADMIN.Address);

        evvm.proposeAdmin(COMMON_USER_NO_STAKER_1.Address);

        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.startPrank(COMMON_USER_NO_STAKER_1.Address);

        evvm.acceptAdmin();

        vm.stopPrank();

        assertEq(evvm.getCurrentAdmin(), COMMON_USER_NO_STAKER_1.Address);
    }

    function test__unit_correct__cancel_set_owner() external {
        vm.startPrank(ADMIN.Address);

        evvm.proposeAdmin(COMMON_USER_NO_STAKER_1.Address);

        vm.warp(block.timestamp + 10 hours);

        evvm.rejectProposalAdmin();

        vm.stopPrank();

        assertEq(evvm.getCurrentAdmin(), ADMIN.Address);
    }

    function test__unit_correct__set_token_to_whitelist() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.warp(block.timestamp + 1 days);

        evvm.addTokenToWhitelist();

        vm.stopPrank();

        assert(
            evvm.getIfTokenIsWhitelisted(
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            )
        );

        assertEq(
            evvm.getTokenUniswapPool(
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            ),
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );
    }

    function test__unit_correct__cancel_set_token_to_whitelist() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.warp(block.timestamp + 10 hours);

        evvm.cancelPrepareTokenToBeWhitelisted();

        vm.stopPrank();
    }

    function test__unit_correct__changePool() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            address(0)
        );

        vm.warp(block.timestamp + 1 days);

        evvm.addTokenToWhitelist();

        evvm.changePool(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.stopPrank();

        assert(
            evvm.getIfTokenIsWhitelisted(
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            )
        );

        assertEq(
            evvm.getTokenUniswapPool(
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            ),
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );
    }

    function test__unit_correct__removeTokenWhitelist() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareTokenToBeWhitelisted(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x6C3e4cb2E96B01F4b866965A91ed4437839A121a
        );

        vm.warp(block.timestamp + 1 days);

        evvm.addTokenToWhitelist();

        evvm.removeTokenWhitelist(0xdAC17F958D2ee523a2206206994597C13D831ec7);

        vm.stopPrank();

        assert(
            !evvm.getIfTokenIsWhitelisted(
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            )
        );

        assertEq(
            evvm.getTokenUniswapPool(
                0xdAC17F958D2ee523a2206206994597C13D831ec7
            ),
            address(0)
        );
    }

    function test__unit_correct__set_MaxAmountToWithdraw() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareMaxAmountToWithdraw(1 ether);

        vm.warp(block.timestamp + 1 days);

        evvm.setMaxAmountToWithdraw();

        vm.stopPrank();

        assertEq(evvm.getMaxAmountToWithdraw(), 1 ether);
    }

    function test__unit_correct__cancel_set_MaxAmountToWithdraw() external {
        vm.startPrank(ADMIN.Address);

        evvm.prepareMaxAmountToWithdraw(1 ether);

        vm.warp(block.timestamp + 10 hours);

        evvm.cancelPrepareMaxAmountToWithdraw();

        vm.stopPrank();
    }

    //_addMateToTotalSupply getEraPrincipalToken

    function test__unit_correct__recalculateReward() external {
        console2.log(evvm.getEraPrincipalToken());

        evvm._addMateToTotalSupply(evvm.getEraPrincipalToken() + 1);

        evvm.recalculateReward();

        console2.log(evvm.getEraPrincipalToken());
    }
}
