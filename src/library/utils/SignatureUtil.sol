// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;

import {SignatureRecover} from "@EVVM/playground/library/primitives/SignatureRecover.sol";

library SignatureUtil {
    function verifySignature(
        string memory evvmID,
        string memory functionName,
        string memory inputs,
        bytes memory signature,
        address expectedSigner
    ) internal pure returns (bool) {
        return
            SignatureRecover.recoverSigner(
                string.concat(evvmID, ",", functionName, ",", inputs),
                signature
            ) == expectedSigner;
    }
}
