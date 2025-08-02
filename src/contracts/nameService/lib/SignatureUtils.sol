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
                    "393b9c6f",
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
                    "d134f8b4",
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
                    "52649c2e",
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
                    "21811609",
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
                    "ae36fe72", //methodIdentifier
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
                    "f1747483",
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
                    "e6efeffa",
                    ",",
                    _username,
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
                    "8001a999",
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
        string memory _username,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    "3e7899a1",
                    ",",
                    _username,
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
                    "d22c816c",
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
