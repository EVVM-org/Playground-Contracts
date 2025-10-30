// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense
pragma solidity ^0.8.0;

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";

abstract contract StakingServiceHooks {
    address stakingHookAddress;
    address evvmHookAddress;
    constructor(address _stakingAddress) {
        stakingHookAddress = _stakingAddress;
        evvmHookAddress = Staking(stakingHookAddress).getEvvmAddress();
    }
    function makeStakeService(uint256 amountToStake) public {
        Staking(stakingHookAddress).prepareServiceStaking(amountToStake);
        Evvm(evvmHookAddress).caPay(
            address(stakingHookAddress),
            0x0000000000000000000000000000000000000001,
            Staking(stakingHookAddress).priceOfStaking() * amountToStake
        );
        Staking(stakingHookAddress).confirmServiceStaking();
    }

    function makeUnstakeService(uint256 amountToUnstake) public {
        Staking(stakingHookAddress).serviceUnstaking(amountToUnstake);
    }

    function _changeStakingHookAddress(address newStakingAddress) internal {
        stakingHookAddress = newStakingAddress;
        evvmHookAddress = Staking(stakingHookAddress).getEvvmAddress();
    }

    function changeEvvmHookAddress(address newEvvmAddress) internal {
        evvmHookAddress = newEvvmAddress;
    }
}
