// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;

import {SignatureRecover} from "@EVVM/playground/library/primitives/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/playground/library/utils/AdvancedStrings.sol";

library SignatureUtil {
    function verifySignature(
        uint256 evvmID,
        string memory functionName,
        string memory inputs,
        bytes memory signature,
        address expectedSigner
    ) internal pure returns (bool) {
        return
            SignatureRecover.recoverSigner(
                string.concat(
                    AdvancedStrings.uintToString(evvmID),
                    ",",
                    functionName,
                    ",",
                    inputs
                ),
                signature
            ) == expectedSigner;
    }
}
