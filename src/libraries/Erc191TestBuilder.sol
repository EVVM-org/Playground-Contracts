// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;
/**
 * @title Erc191TestBuilder
 * @author jistro.eth
 * @notice this library is used to build ERC191 messages for foundry test scripts
 *         more info in
 *         https://book.getfoundry.sh/cheatcodes/create-wallet
 *         https://book.getfoundry.sh/cheatcodes/sign
 */

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AdvancedStrings} from "@RollAMate/libraries/AdvancedStrings.sol";

library Erc191TestBuilder {
    //-----------------------------------------------------------------------------------
    // EVVM
    //-----------------------------------------------------------------------------------
    function buildMessageSignedForPay(
        address _receiverAddress,
        string memory _receiverIdentity,
        address _token,
        uint256 _amount,
        uint256 _priorityFee,
        uint256 _nonce,
        bool _priority_boolean,
        address _executor
    ) internal pure returns (bytes32 messageHash) {
        string memory messageToSign = _receiverAddress == address(0)
            ? string.concat(
                _priority_boolean ? "f4e1895b" : "4faa1fa2",
                ",",
                _receiverIdentity,
                ",",
                AdvancedStrings.addressToString(_token),
                ",",
                Strings.toString(_amount),
                ",",
                Strings.toString(_priorityFee),
                ",",
                Strings.toString(_nonce),
                ",",
                _priority_boolean ? "true" : "false",
                ",",
                AdvancedStrings.addressToString(_executor)
            )
            : string.concat(
                _priority_boolean ? "f4e1895b" : "4faa1fa2",
                ",",
                AdvancedStrings.addressToString(_receiverAddress),
                ",",
                AdvancedStrings.addressToString(_token),
                ",",
                Strings.toString(_amount),
                ",",
                Strings.toString(_priorityFee),
                ",",
                Strings.toString(_nonce),
                ",",
                _priority_boolean ? "true" : "false",
                ",",
                AdvancedStrings.addressToString(_executor)
            );
        messageHash = buildHashForSign(messageToSign);
    }

    function buildMessageSignedForDispersePay(
        bytes32 hashList,
        address _token,
        uint256 _amount,
        uint256 _priorityFee,
        uint256 _nonce,
        bool _priority_boolean,
        address _executor
    ) public pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "ef83c1d6",
                    ",",
                    AdvancedStrings.bytes32ToString(hashList),
                    ",",
                    AdvancedStrings.addressToString(_token),
                    ",",
                    Strings.toString(_amount),
                    ",",
                    Strings.toString(_priorityFee),
                    ",",
                    Strings.toString(_nonce),
                    ",",
                    _priority_boolean ? "true" : "false",
                    ",",
                    AdvancedStrings.addressToString(_executor)
                )
            );
    }

    //-----------------------------------------------------------------------------------
    // MATE NAME SERVICE
    //-----------------------------------------------------------------------------------

    function buildMessageSignedForPreRegistrationUsername(
        bytes32 _hashUsername,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "393b9c6f",
                    ",",
                    AdvancedStrings.bytes32ToString(_hashUsername),
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForRegistrationUsername(
        string memory _username,
        uint256 _clowNumber,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "d134f8b4",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_clowNumber),
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForMakeOffer(
        string memory _username,
        uint256 _dateExpire,
        uint256 _amount,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "52649c2e",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_dateExpire),
                    ",",
                    Strings.toString(_amount),
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForWithdrawOffer(
        string memory _username,
        uint256 _offerId,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "21811609",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_offerId),
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForAcceptOffer(
        string memory _username,
        uint256 _offerId,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "ae36fe72", //methodIdentifier
                    ",",
                    _username,
                    ",",
                    Strings.toString(_offerId),
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForRenewUsername(
        string memory _username,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "f1747483",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForAddCustomMetadata(
        string memory _username,
        string memory _value,
        uint256 _mateNameServiceNonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "e6efeffa",
                    ",",
                    _username,
                    ",",
                    _value,
                    ",",
                    Strings.toString(_mateNameServiceNonce)
                )
            );
    }

    function buildMessageSignedForRemoveCustomMetadata(
        string memory _username,
        uint256 _key,
        uint256 _nonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "8001a999",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_key),
                    ",",
                    Strings.toString(_nonce)
                )
            );
    }

    function buildMessageSignedForFlushCustomMetadata(
        string memory _username,
        uint256 _nonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "3e7899a1",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_nonce)
                )
            );
    }

    function buildMessageSignedForFlushUsername(
        string memory _username,
        uint256 _nonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "d22c816c",
                    ",",
                    _username,
                    ",",
                    Strings.toString(_nonce)
                )
            );
    }

    //-----------------------------------------------------------------------------------
    // sMate functions
    //-----------------------------------------------------------------------------------

    function buildMessageSignedForPublicStaking(
        bool _isStaking,
        uint256 _amountOfSMate,
        uint256 _nonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "21cc1749",
                    ",",
                    _isStaking ? "true" : "false",
                    ",",
                    Strings.toString(_amountOfSMate),
                    ",",
                    Strings.toString(_nonce)
                )
            );
    }

    function buildMessageSignedForPresaleStaking(
        bool _isStaking,
        uint256 _amountOfSMate,
        uint256 _nonce
    ) internal pure returns (bytes32 messageHash) {
        return
            buildHashForSign(
                string.concat(
                    "6257deec",
                    ",",
                    _isStaking ? "true" : "false",
                    ",",
                    Strings.toString(_amountOfSMate),
                    ",",
                    Strings.toString(_nonce)
                )
            );
    }

    //-----------------------------------------------------------------------------------
    // General functions
    //-----------------------------------------------------------------------------------

    function buildHashForSign(
        string memory messageToSign
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n",
                    Strings.toString(bytes(messageToSign).length),
                    messageToSign
                )
            );
    }

    function buildERC191Signature(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(r, s, bytes1(v));
    }
}
