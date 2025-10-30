// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

import {SignatureRecover} from "@EVVM/playground/library/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/playground/library/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.0;

library SignatureUtils {
    /**
     *  @dev using EIP-191 (https://eips.ethereum.org/EIPS/eip-191) can be used to sign and
     *       verify messages, the next functions are used to verify the messages signed
     *       by the users
     */

    function verifyMessageSignedForStake(
        uint256 evvmID,
        address user,
        bool isExternalStaking,
        bool _isStaking,
        uint256 _amountOfStaking,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                Strings.toString(evvmID),
                isExternalStaking ? "publicStaking" : "presaleStaking",
                string.concat(
                    _isStaking ? "true" : "false",
                    ",",
                    Strings.toString(_amountOfStaking),
                    ",",
                    Strings.toString(_nonce)
                ),
                signature,
                user
            );
    }
}
