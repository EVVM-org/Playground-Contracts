// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

import {SignatureUtil} from "@EVVM/playground/library/utils/SignatureUtil.sol";
import {AdvancedStrings} from "@EVVM/playground/library/utils/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.0;

library SignatureUtils {
    /**
     *  @dev using EIP-191 (https://eips.ethereum.org/EIPS/eip-191) can be used to sign and
     *       verify messages, the next functions are used to verify the messages signed
     *       by the users
     */

    function verifyMessageSignedForPreRegistrationUsername(
        uint256 evvmID,
        address signer,
        bytes32 _hashUsername,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "preRegistrationUsername",
                string.concat(
                    AdvancedStrings.bytes32ToString(_hashUsername),
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForRegistrationUsername(
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _clowNumber,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "registrationUsername",
                string.concat(
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
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _dateExpire,
        uint256 _amount,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "makeOffer",
                string.concat(
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
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _offerId,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "withdrawOffer",
                string.concat(
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
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _offerId,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "acceptOffer",
                string.concat(
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
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "renewUsername",
                string.concat(
                    _username,
                    ",",
                    Strings.toString(_nameServiceNonce)
                ),
                signature,
                signer
            );
    }

    function verifyMessageSignedForAddCustomMetadata(
        uint256 evvmID,
        address signer,
        string memory _identity,
        string memory _value,
        uint256 _nameServiceNonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "addCustomMetadata",
                string.concat(
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
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _key,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "removeCustomMetadata",
                string.concat(
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
        uint256 evvmID,
        address signer,
        string memory _identity,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "flushCustomMetadata",
                string.concat(_identity, ",", Strings.toString(_nonce)),
                signature,
                signer
            );
    }

    function verifyMessageSignedForFlushUsername(
        uint256 evvmID,
        address signer,
        string memory _username,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureUtil.verifySignature(
                evvmID,
                "flushUsername",
                string.concat(_username, ",", Strings.toString(_nonce)),
                signature,
                signer
            );
    }
}
