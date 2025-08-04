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
    
    function verifyMessageSignedForPreRegistrationUsername(
        address signer,
        bytes32 _hashUsername,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "5d232a55",
                    ",",
                    AdvancedStrings.bytes32ToString(_hashUsername),
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForRegistrationUsername(
        address signer,
        string memory _username,
        uint256 _clowNumber,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "afabc8db",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_clowNumber),
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForMakeOffer(
        address signer,
        string memory _username,
        uint256 _dateExpire,
        uint256 _amount,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "d82e5d8b",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_dateExpire),
                    ",",
                    Strings.toString(_amount),
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForWithdrawOffer(
        address signer,
        string memory _username,
        uint256 _offerId,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "5761d8ed",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_offerId),
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForAcceptOffer(
        address signer,
        string memory _username,
        uint256 _offerId,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "8e3bde43",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_offerId),
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForRenewUsername(
        address signer,
        string memory _username,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "35723e23",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForAddCustomMetadata(
        address signer,
        string memory _identity,
        string memory _value,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "4cfe021f",
                    ",",
                    _identity,
                    ",",
                    _value,
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForRemoveCustomMetadata(
        address signer,
        string memory _username,
        uint256 _key,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "8adf3927",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_key),
                    ",",
                    Strings.toString(_nonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForFlushCustomMetadata(
        address signer,
        string memory _identity,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "3ca44e54",
                    ",",
                    _identity,
                    ",",
                    Strings.toString(_nonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForFlushUsername(
        address signer,
        string memory _username,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "044695cb",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_nonce)
                ),
                signature,
                signer
            );
    }
}
