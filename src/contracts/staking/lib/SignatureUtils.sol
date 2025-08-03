// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

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
                    isExternalStaking ? "21cc1749" : "6257deec",
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
                    "21cc1749",
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
