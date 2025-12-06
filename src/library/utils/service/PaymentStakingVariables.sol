// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense
pragma solidity ^0.8.0;

import {IEvvm} from "@EVVM/playground/interfaces/IEvvm.sol";
import {IStaking} from "@EVVM/playground/interfaces/IStaking.sol";

abstract contract PaymentStakingVariables {
    IEvvm evvm;
    IStaking staking;
    constructor(address _evvmAddress, address _stakingAddress) {
        evvm = IEvvm(_evvmAddress);
        staking = IStaking(_stakingAddress);
    }

    function getPrincipalTokenAddress()
        internal
        pure
        virtual
        returns (address)
    {
        return address(1);
    }

    function getEtherAddress() internal pure virtual returns (address) {
        return address(0);
    }


    function _changeEvvmAddress(address newEvvmAddress) internal {
        evvm = IEvvm(newEvvmAddress);
    }

    function _changeStakingAddress(address newStakingAddress) internal {
        staking = IStaking(newStakingAddress);
    }

}