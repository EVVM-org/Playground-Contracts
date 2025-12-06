// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;

import {EvvmStructs} from "@EVVM/playground/interfaces/IEvvm.sol";
import {SignatureUtil} from "@EVVM/playground/library/utils/SignatureUtil.sol";
import {AsyncNonce} from "@EVVM/playground/library/utils/nonces/AsyncNonce.sol";
import {StakingServiceUtils} from "@EVVM/playground/library/utils/service/StakingServiceUtils.sol";
import {MakeServicePaymentOnEvvm} from "@EVVM/playground/library/utils/service/MakeServicePaymentOnEvvm.sol";

abstract contract EvvmService is
    AsyncNonce,
    StakingServiceUtils,
    MakeServicePaymentOnEvvm
{
    error InvalidServiceSignature();

    constructor(
        address evvmAddress,
        address stakingAddress
    )
        StakingServiceUtils(stakingAddress)
        MakeServicePaymentOnEvvm(evvmAddress)
    {}

    function validateServiceSignature(
        string memory functionName,
        string memory inputs,
        bytes memory signature,
        address expectedSigner
    ) internal view virtual {
        if (
            !SignatureUtil.verifySignature(
                evvm.getEvvmID(),
                functionName,
                inputs,
                signature,
                expectedSigner
            )
        ) revert InvalidServiceSignature();
    }


}
