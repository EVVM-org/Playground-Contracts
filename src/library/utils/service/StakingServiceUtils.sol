// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense
pragma solidity ^0.8.0;

import {PaymentStakingVariables} from "@EVVM/playground/library/utils/service/PaymentStakingVariables.sol";

abstract contract StakingServiceUtils is PaymentStakingVariables {
    constructor(
        address evvmAddress,
        address stakingAddress
    ) PaymentStakingVariables(evvmAddress, stakingAddress) {}

    function _makeStakeService(uint256 amountToStake) internal {
        staking.prepareServiceStaking(amountToStake);
        evvm.caPay(
            address(staking),
            getPrincipalTokenAddress(),
            staking.priceOfStaking() * amountToStake
        );
        staking.confirmServiceStaking();
    }

    function _makeUnstakeService(uint256 amountToUnstake) internal {
        staking.serviceUnstaking(amountToUnstake);
    }

}
