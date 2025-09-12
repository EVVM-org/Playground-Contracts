// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense
pragma solidity ^0.8.0;

import {EvvmStorage} from "@EVVM/playground/contracts/evvm/lib/EvvmStorage.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

abstract contract EvvmPlaygroundFunctions is EvvmStorage {
    function _addMateToTotalSupply(uint256 amount) public {
        evvmMetadata.totalSupply += amount;
    }
}
