// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense

import {SignatureRecover} from "@EVVM/playground/lib/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.0;

library SignatureUtils {
    /**
     *  @dev using EIP-191 (https://eips.ethereum.org/EIPS/eip-191) can be used to sign and
     *       verify messages, the next functions are used to verify the messages signed
     *       by the users
     */

    function verifyMessageSignedForStake(
        address user,
        bool isExternalStaking,
        bool _isStaking,
        uint256 _amountOfStaking,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    /**
                     * @dev if isExternalStaking is true,
                     * the function selector is for publicStaking
                     * else is for presaleInternalExecution
                     */
                    isExternalStaking ? "c769095c" : "c0f6e7d1",
                    ",",
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

    function verifyMessageSignedForPublicServiceStake(
        address user,
        address serviceAddress,
        bool _isStaking,
        uint256 _amountOfStaking,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "e2ccd470",
                    ",",
                    AdvancedStrings.addressToString(serviceAddress),
                    ",",
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
