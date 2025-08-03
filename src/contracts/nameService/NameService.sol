// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;
/*  
888b     d888                   888            .d8888b.                    888                             888    
8888b   d8888                   888           d88P  Y88b                   888                             888    
88888b.d88888                   888           888    888                   888                             888    
888Y88888P888  .d88b.   .d8888b 888  888      888         .d88b.  88888b.  888888 888d888 8888b.   .d8888b 888888 
888 Y888P 888 d88""88b d88P"    888 .88P      888        d88""88b 888 "88b 888    888P"      "88b d88P"    888    
888  Y8P  888 888  888 888      888888K       888    888 888  888 888  888 888    888    .d888888 888      888    
888   "   888 Y88..88P Y88b.    888 "88b      Y88b  d88P Y88..88P 888  888 Y88b.  888    888  888 Y88b.    Y88b.  
888       888  "Y88P"   "Y8888P 888  888       "Y8888P"   "Y88P"  888  888  "Y888 888    "Y888888  "Y8888P  "Y888                                                                                                          
 */

import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {ErrorsLib} from "@EVVM/playground/contracts/nameService/lib/ErrorsLib.sol";
import {SignatureUtils} from "@EVVM/playground/contracts/nameService/lib/SignatureUtils.sol";

contract NameService {
    struct AddressTypeProposal {
        address current;
        address proposal;
        uint256 timeToAccept;
    }

    struct UintTypeProposal {
        uint256 current;
        uint256 proposal;
        uint256 timeToAccept;
    }

    struct BoolTypeProposal {
        bool flag;
        uint256 timeToAcceptChange;
    }
    struct IdentityBaseMetadata {
        address owner;
        uint256 expireDate;
        uint256 customMetadataMaxSlots;
        uint256 offerMaxSlots;
        bytes1 flagNotAUsername;
    }

    mapping(string username => IdentityBaseMetadata basicMetadata)
        private identityDetails;

    struct OfferMetadata {
        address offerer;
        uint256 expireDate;
        uint256 amount;
    }

    mapping(string username => mapping(uint256 id => OfferMetadata))
        private usernameOffers;

    mapping(string username => mapping(uint256 numberKey => string customValue))
        private identityCustomMetadata;

    mapping(address => mapping(uint256 => bool)) private nameServiceNonce;

    UintTypeProposal amountToWithdrawTokens;

    AddressTypeProposal evvmAddress;

    AddressTypeProposal admin;

    AddressTypeProposal addressPhoneNumberRegistery;

    AddressTypeProposal addressEmailRegistery;

    AddressTypeProposal addressAutority;

    BoolTypeProposal stopChangeVerificationsAddress;

    address private constant PRINCIPAL_TOKEN_ADDRESS =
        0x0000000000000000000000000000000000000001;

    uint256 private mateTokenLockedForWithdrawOffers;

    modifier onlyAdmin() {
        if (msg.sender != admin.current) revert ErrorsLib.SenderIsNotAdmin();

        _;
    }

    modifier onlyOwnerOfIdentity(address _user, string memory _identity) {
        if (identityDetails[_identity].owner != _user)
            revert ErrorsLib.UserIsNotOwnerOfIdentity();

        _;
    }

    modifier verifyIfNonceIsAvailable(address _user, uint256 _nonce) {
        if (nameServiceNonce[_user][_nonce])
            revert ErrorsLib.NonceAlreadyUsed();

        _;
    }

    constructor(address _evvmAddress, address _initialOwner) {
        evvmAddress.current = _evvmAddress;
        admin.current = _initialOwner;
    }

    /**
     * @dev _setIdentityBaseMetadata and _setIdentityCustomMetadata are debug functions
     *      DO NOT USE IN PRODUCTION!!!!!!!
     */

    function _setIdentityBaseMetadata(
        string memory _identity,
        IdentityBaseMetadata memory _identityBaseMetadata
    ) external {
        identityDetails[_identity] = _identityBaseMetadata;
    }

    function _setIdentityCustomMetadata(
        string memory _identity,
        uint256 _numberKey,
        string memory _customValue
    ) external {
        identityCustomMetadata[_identity][_numberKey] = _customValue;
    }

    /**
     *  @notice This function is used to pre-register a username to avoid
     *          front-running attacks.
     *  @param user the address of the user who wants to pre-register
     *               the username
     *  @param hashPreRegisteredUsername the hash of pre-registered username
     *  @param nonce the nonce of the user
     *  @param signature the signature of the transaction of the priority fee
     *  @param priorityFee_EVVM the priority fee for the fisher who will include
     *                          the transaction
     *
     *  @notice if doesn't have a priority fee the next parameters are not necessary
     *
     *  @param nonce_EVVM the nonce of the user in the Evvm
     *  @param priorityFlag_EVVM the priority of the transaction in the
     *                           Evvm's payMateStaker function
     *  @param signature_EVVM the signature of the transaction in the
     *                                payMateStaker function in the Evvm
     */
    function preRegistrationUsername(
        address user,
        bytes32 hashPreRegisteredUsername,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) public verifyIfNonceIsAvailable(user, nonce) {
        if (
            !SignatureUtils.verifyMessageSignedForPreRegistrationUsername(
                user,
                hashPreRegisteredUsername,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        if (priorityFee_EVVM > 0) {
            makePay(
                user,
                nonce_EVVM,
                priorityFee_EVVM,
                0,
                priorityFlag_EVVM,
                signature_EVVM
            );
        }
        /// concatenamos @ con el hash del username para evitar que se pueda registrar un username que no sea un hash
        string memory key = string.concat(
            "@",
            AdvancedStrings.bytes32ToString(hashPreRegisteredUsername)
        );

        identityDetails[key] = IdentityBaseMetadata({
            owner: user,
            expireDate: block.timestamp + 30 minutes,
            customMetadataMaxSlots: 0,
            offerMaxSlots: 0,
            flagNotAUsername: 0x01
        });

        nameServiceNonce[user][nonce] = true;

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                Evvm(evvmAddress.current).getRewardAmount() + priorityFee_EVVM
            );
        }
    }

    /**
     *  @notice This function is used to register a username
     *  @param user the address of the user who wants to register
     *  @param username the username to register
     *  @param clowNumber the random number of the pre-registration
     *                     hash of the username to verify if the user
     *                     is the owner of the pre-registration hash
     *  @param nonce the nonce of the user
     *  @param signature the signature of the transaction
     *  @param priorityFee_EVVM the priority fee for the fisher who will include
     *  @param nonce_EVVM the nonce of the user in the Evvm
     *  @param priorityFlag_EVVM the priority of the transaction in the
     *                               Evvm's payMateStaker function
     *  @param signature_EVVM the signature of the transaction in the
     *                                payMateStaker function in the Evvm
     */
    function registrationUsername(
        address user,
        string memory username,
        uint256 clowNumber,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) public verifyIfNonceIsAvailable(user, nonce) {
        if (admin.current != user) isValidUsername(username);

        if (!isUsernameAvailable(username)) {
            revert ErrorsLib.UsernameAlreadyRegistered();
        }

        if (
            !SignatureUtils.verifyMessageSignedForRegistrationUsername(
                user,
                username,
                clowNumber,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        makePay(
            user,
            nonce_EVVM,
            getPricePerRegistration(),
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        string memory _key = string.concat(
            "@",
            AdvancedStrings.bytes32ToString(hashUsername(username, clowNumber))
        );

        if (
            identityDetails[_key].owner != user ||
            identityDetails[_key].expireDate > block.timestamp
        ) revert ErrorsLib.PreRegistrationNotValid();

        identityDetails[username] = IdentityBaseMetadata({
            owner: user,
            expireDate: block.timestamp + 366 days,
            customMetadataMaxSlots: 0,
            offerMaxSlots: 0,
            flagNotAUsername: 0x00
        });

        nameServiceNonce[user][nonce] = true;

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (50 * Evvm(evvmAddress.current).getRewardAmount()) +
                    priorityFee_EVVM
            );
        }

        delete identityDetails[_key];
    }

    /*
    function registrationTelephoneNumber(
        address _user,
        uint256 _nonce,
        string memory _phoneNumber,
        uint256 _timestampUser,
        bytes memory _signatureUser,
        uint256 _timestampAuthority,
        bytes memory _signatureAuthority,
        uint256 _priorityFeeForFisher,
        uint256 _nonce_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) public verifyIfNonceIsAvailable(_user, _nonce) {
        isValidPhoneNumberNumber(_phoneNumber);

        makePay(
            _user,
            _nonce_Evvm,
            getPricePerRegistration(),
            _priorityFeeForFisher,
            _priority_Evvm,
            _signature_Evvm
        );

        uint256 multiple = IPhoneNumberRegistery(
            addressPhoneNumberRegistery.current
        ).register(
                _user,
                _phoneNumber,
                _timestampUser,
                _signatureUser,
                _timestampAuthority,
                _signatureAuthority
            );

        if (multiple == 50) {
            identityDetails[_phoneNumber] = IdentityBaseMetadata({
                owner: _user,
                expireDate: 0,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x01
            });
        }

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (multiple * Evvm(evvmAddress.current).getRewardAmount()) +
                    _priorityFeeForFisher
            );
        }

        nameServiceNonce[_user][_nonce] = true;
    }

    function reverseTransferTelephoneNumber(
        address _user,
        uint256 _nonce,
        string memory _phoneNumber,
        uint256 _timestamp,
        bytes memory _signature
    ) public verifyIfNonceIsAvailable(_user, _nonce) {
        if (nameServiceNonce[_user][_nonce]) {
            revert();
        }

        uint256 multiple = IPhoneNumberRegistery(
            addressPhoneNumberRegistery.current
        ).reverseTransfer(_user, _phoneNumber, _timestamp, _signature);

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (multiple * Evvm(evvmAddress.current).getRewardAmount())
            );
        }

        nameServiceNonce[_user][_nonce] = true;
    }

    function claimTransferTelephoneNumber(string memory _phoneNumber) public {
        uint256 multiple = IPhoneNumberRegistery(
            addressPhoneNumberRegistery.current
        ).claimTransfer(_phoneNumber);

        (address newOwner, , , ) = IPhoneNumberRegistery(
            addressPhoneNumberRegistery.current
        ).getFullMetadata(_phoneNumber);

        identityDetails[_phoneNumber].owner = newOwner;

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (multiple * Evvm(evvmAddress.current).getRewardAmount())
            );
        }
    }

    function registrationEmail(
        address _user,
        uint256 _nonce,
        string memory _email,
        uint256 _timestampUser,
        bytes memory _signatureUser,
        uint256 _timestampAuthority,
        bytes memory _signatureAuthority,
        uint256 _priorityFeeForFisher,
        uint256 _nonce_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) public verifyIfNonceIsAvailable(_user, _nonce) {
        isValidEmail(_email);

        makePay(
            _user,
            _nonce_Evvm,
            getPricePerRegistration(),
            _priorityFeeForFisher,
            _priority_Evvm,
            _signature_Evvm
        );

        uint256 multiple = IEmailRegistery(addressEmailRegistery.current)
            .register(
                _user,
                _email,
                _timestampUser,
                _signatureUser,
                _timestampAuthority,
                _signatureAuthority
            );

        if (multiple == 50) {
            identityDetails[_email] = IdentityBaseMetadata({
                owner: _user,
                expireDate: 0,
                customMetadataMaxSlots: 0,
                offerMaxSlots: 0,
                flagNotAUsername: 0x01
            });
        }

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (multiple * Evvm(evvmAddress.current).getRewardAmount()) +
                    _priorityFeeForFisher
            );
        }

        nameServiceNonce[_user][_nonce] = true;
    }

    function reverseTransferEmail(
        address _user,
        uint256 _nonce,
        string memory _email,
        uint256 _timestamp,
        bytes memory _signature
    ) public verifyIfNonceIsAvailable(_user, _nonce) {
        if (nameServiceNonce[_user][_nonce]) {
            revert();
        }

        uint256 multiple = IEmailRegistery(addressEmailRegistery.current)
            .reverseTransfer(_user, _email, _timestamp, _signature);

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (multiple * Evvm(evvmAddress.current).getRewardAmount())
            );
        }

        nameServiceNonce[_user][_nonce] = true;
    }

    function claimTransferEmail(string memory _email) public {
        uint256 multiple = IEmailRegistery(addressEmailRegistery.current)
            .claimTransfer(_email);

        (address newOwner, , , ) = IEmailRegistery(
            addressEmailRegistery.current
        ).getFullMetadata(_email);

        identityDetails[_email].owner = newOwner;

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (multiple * Evvm(evvmAddress.current).getRewardAmount())
            );
        }
    }
    */

    function makeOffer(
        address user,
        string memory username,
        uint256 expireDate,
        uint256 amount,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) public verifyIfNonceIsAvailable(user, nonce) returns (uint256 offerID) {
        if (
            identityDetails[username].flagNotAUsername == 0x01 ||
            !verifyIfIdentityExists(username) ||
            amount == 0 ||
            expireDate <= block.timestamp
        ) revert ErrorsLib.PreRegistrationNotValid();

        if (
            !SignatureUtils.verifyMessageSignedForMakeOffer(
                user,
                username,
                expireDate,
                amount,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        makePay(
            user,
            nonce_EVVM,
            amount,
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        while (usernameOffers[username][offerID].offerer != address(0)) {
            offerID++;
        }

        usernameOffers[username][offerID] = OfferMetadata({
            offerer: user,
            expireDate: expireDate,
            amount: ((amount * 995) / 1000) /// calcula el 99.5% del valor de la oferta
        });

        makeCaPay(
            msg.sender,
            Evvm(evvmAddress.current).getRewardAmount() +
                ((amount * 125) / 100_000) +
                priorityFee_EVVM
        );
        mateTokenLockedForWithdrawOffers +=
            ((amount * 995) / 1000) +
            (amount / 800);

        if (offerID > identityDetails[username].offerMaxSlots) {
            identityDetails[username].offerMaxSlots++;
        } else if (identityDetails[username].offerMaxSlots == 0) {
            identityDetails[username].offerMaxSlots++;
        }

        nameServiceNonce[user][nonce] = true;
    }

    function withdrawOffer(
        address user,
        string memory username,
        uint256 offerID,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) public verifyIfNonceIsAvailable(user, nonce) {
        if (usernameOffers[username][offerID].offerer != user)
            revert ErrorsLib.UserIsNotOwnerOfOffer();

        if (
            !SignatureUtils.verifyMessageSignedForWithdrawOffer(
                user,
                username,
                offerID,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        if (priorityFee_EVVM > 0) {
            makePay(
                user,
                nonce_EVVM,
                priorityFee_EVVM,
                0,
                priorityFlag_EVVM,
                signature_EVVM
            );
        }

        makeCaPay(user, usernameOffers[username][offerID].amount);

        usernameOffers[username][offerID].offerer = address(0);

        makeCaPay(
            msg.sender,
            Evvm(evvmAddress.current).getRewardAmount() +
                //obtenemos el 0.5% y dividimos entre 4 para obtener el 0.125%
                //+ ((usernameOffers[_username][_offerID].amount  * 1 / 199)/4)
                //mas simplificado
                ((usernameOffers[username][offerID].amount * 1) / 796) +
                priorityFee_EVVM
        );

        mateTokenLockedForWithdrawOffers -=
            (usernameOffers[username][offerID].amount) +
            (((usernameOffers[username][offerID].amount * 1) / 199) / 4);

        nameServiceNonce[user][nonce] = true;
    }

    /**
     *  @notice This function is used to accept an offer for a username
     *  @param user the address of the user who owns the username
     *  @param username the username to accept the offer
     *  @param offerID the ID of the offer to accept
     *  @param nonce the nonce of the user
     *  @param signature the signature of the transaction
     *  @param priorityFee_EVVM the priority fee for the fisher who will include the
     *                       transaction
     *  @notice if doesn't have a priority fee the next parameters are not necessary
     *
     *  @param nonce_EVVM the nonce of the user in the Evvm
     *  @param priorityFlag_EVVM the priority of the transaction in the
     *                               Evvm's payMateStaker function
     *  @param signature_EVVM the signature of the transaction in the
     *                                payMateStaker function in the Evvm
     */
    function acceptOffer(
        address user,
        string memory username,
        uint256 offerID,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    )
        public
        onlyOwnerOfIdentity(user, username)
        verifyIfNonceIsAvailable(user, nonce)
    {
        if (
            usernameOffers[username][offerID].offerer == address(0) ||
            usernameOffers[username][offerID].expireDate < block.timestamp
        ) revert ErrorsLib.AcceptOfferVerificationFailed();

        if (
            !SignatureUtils.verifyMessageSignedForAcceptOffer(
                user,
                username,
                offerID,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        if (priorityFee_EVVM > 0) {
            makePay(
                user,
                nonce_EVVM,
                priorityFee_EVVM,
                0,
                priorityFlag_EVVM,
                signature_EVVM
            );
        }

        makeCaPay(user, usernameOffers[username][offerID].amount);

        identityDetails[username].owner = usernameOffers[username][offerID]
            .offerer;

        usernameOffers[username][offerID].offerer = address(0);

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (Evvm(evvmAddress.current).getRewardAmount()) +
                    (((usernameOffers[username][offerID].amount * 1) / 199) /
                        4) +
                    priorityFee_EVVM
            );
        }

        mateTokenLockedForWithdrawOffers -=
            (usernameOffers[username][offerID].amount) +
            (((usernameOffers[username][offerID].amount * 1) / 199) / 4);

        nameServiceNonce[user][nonce] = true;
    }

    /**
     *  @notice This function is used to renew a username
     *
     *  @custom:important
     *      if the owner of the username wants to renew the
     *      username one year before the expiration date, the
     *      price is 0 MATE only for a limited time, after that
     *      the price is consultable in the seePriceToRenew function
     *      but if the owner of the username wants to renew more than
     *      one year before the expiration date, the price is 500,000
     *      MATE and can be renewed up to 100 years
     *
     *  @param user the address of the user who owns the username
     *  @param username the username to renew
     *  @param nonce the nonce of the user
     *  @param signature the signature of the transaction
     *  @param priorityFee_EVVM the priority fee for the fisher who will include the
     *                       transaction
     *  @param nonce_EVVM the nonce of the user in the Evvm
     *  @param priorityFlag_EVVM the priority of the transaction in the
     *                               Evvm's payMateStaker function
     *  @param signature_EVVM the signature of the transaction in the
     *                                payMateStaker function in the Evvm
     */
    function renewUsername(
        address user,
        string memory username,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    )
        public
        onlyOwnerOfIdentity(user, username)
        verifyIfNonceIsAvailable(user, nonce)
    {
        if (
            identityDetails[username].flagNotAUsername == 0x01 ||
            identityDetails[username].expireDate > block.timestamp + 36500 days
        ) revert ErrorsLib.RenewUsernameVerificationFailed();

        if (
            !SignatureUtils.verifyMessageSignedForRenewUsername(
                user,
                username,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        uint256 priceOfRenew = seePriceToRenew(username);

        makePay(
            user,
            nonce_EVVM,
            priceOfRenew,
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                Evvm(evvmAddress.current).getRewardAmount() +
                    ((priceOfRenew * 50) / 100) + //? no estamos siendo muy generosos con el priority fee
                    priorityFee_EVVM
            );
        }

        identityDetails[username].expireDate += 366 days;
        nameServiceNonce[user][nonce] = true;
    }

    /*
     * How to use identityCustomMetadata:
     *
     * identityCustomMetadata["username"][key] = "value";
     *
     * Parameters:
     *
     * - key (numberKey):
     *   Should be treated as a nonce (unique number) to avoid overwriting existing values.
     *   The value 0 is used as a header to check for the absence of a value in case the user
     *   does not enter one.
     *
     * - value (customValue):
     *   Is a text string that allows storing any type of data.
     *   The data follows a standard to facilitate reading, although it is not mandatory
     *   to fully comply with it.
     *
     * Standard value format:
     * [schema]:[subschema]>[value]
     *
     * Examples:
     * memberOf:>EVVM
     * socialMedia:x     >jistro       // LinkedIn without subschema
     * email:dev   >jistro@evvm.org    // Email with "dev" subschema
     * email:callme>contact@jistro.xyz  // Email with "callme" subschema
     *
     * Important notes:
     * - 'schema' is based on https://schema.org/docs/schemas.html
     * - ':' is the separator between schema and subschema
     * - '>' is the separator between metadata and value
     * - If 'schema' or 'subschema' have fewer than 5 characters, they should be padded with spaces:
     *   Example: vk   :job  >jane-doe
     * - In case of social networks, the 'schema' should be "socialMedia" and the 'subschema' should be the social network name
     */
    function addCustomMetadata(
        address user,
        string memory identity,
        string memory value,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    )
        public
        onlyOwnerOfIdentity(user, identity)
        verifyIfNonceIsAvailable(user, nonce)
    {
        if (bytes(value).length == 0) revert ErrorsLib.EmptyCustomMetadata();

        if (
            !SignatureUtils.verifyMessageSignedForAddCustomMetadata(
                user,
                identity,
                value,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        makePay(
            user,
            nonce_EVVM,
            getPriceToAddCustomMetadata(),
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (5 * Evvm(evvmAddress.current).getRewardAmount()) +
                    ((getPriceToAddCustomMetadata() * 50) / 100) +
                    priorityFee_EVVM
            );
        }

        identityCustomMetadata[identity][
            identityDetails[identity].customMetadataMaxSlots
        ] = value;

        identityDetails[identity].customMetadataMaxSlots++;
        nameServiceNonce[user][nonce] = true;
    }

    function removeCustomMetadata(
        address user,
        string memory identity,
        uint256 key,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    )
        public
        onlyOwnerOfIdentity(user, identity)
        verifyIfNonceIsAvailable(user, nonce)
    {
        if (
            !SignatureUtils.verifyMessageSignedForRemoveCustomMetadata(
                user,
                identity,
                key,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        //check if the key is greater than the number of custom metadata
        if (identityDetails[identity].customMetadataMaxSlots <= key)
            revert ErrorsLib.InvalidKey();

        makePay(
            user,
            nonce_EVVM,
            getPriceToRemoveCustomMetadata(),
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        //si es el ultimo elemento
        if (identityDetails[identity].customMetadataMaxSlots == key) {
            delete identityCustomMetadata[identity][key];
        } else {
            for (
                uint256 i = key;
                i < identityDetails[identity].customMetadataMaxSlots;
                i++
            ) {
                identityCustomMetadata[identity][i] = identityCustomMetadata[
                    identity
                ][i + 1];
            }
            delete identityCustomMetadata[identity][
                identityDetails[identity].customMetadataMaxSlots
            ];
        }
        identityDetails[identity].customMetadataMaxSlots--;
        nameServiceNonce[user][nonce] = true;
        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                (5 * Evvm(evvmAddress.current).getRewardAmount()) +
                    priorityFee_EVVM
            );
        }
    }

    function flushCustomMetadata(
        address user,
        string memory identity,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    )
        public
        onlyOwnerOfIdentity(user, identity)
        verifyIfNonceIsAvailable(user, nonce)
    {
        if (
            !SignatureUtils.verifyMessageSignedForFlushCustomMetadata(
                user,
                identity,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        if (identityDetails[identity].customMetadataMaxSlots == 0)
            revert ErrorsLib.EmptyCustomMetadata();

        makePay(
            user,
            nonce_EVVM,
            getPriceToFlushCustomMetadata(identity),
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        for (
            uint256 i = 0;
            i < identityDetails[identity].customMetadataMaxSlots;
            i++
        ) {
            delete identityCustomMetadata[identity][i];
        }

        if (Evvm(evvmAddress.current).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                ((5 * Evvm(evvmAddress.current).getRewardAmount()) *
                    identityDetails[identity].customMetadataMaxSlots) +
                    priorityFee_EVVM
            );
        }

        identityDetails[identity].customMetadataMaxSlots = 0;
        nameServiceNonce[user][nonce] = true;
    }

    function flushUsername(
        address user,
        string memory username,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    )
        public
        verifyIfNonceIsAvailable(user, nonce)
        onlyOwnerOfIdentity(user, username)
    {
        if (
            block.timestamp >= identityDetails[username].expireDate ||
            identityDetails[username].flagNotAUsername == 0x01
        ) revert ErrorsLib.FlushUsernameVerificationFailed();

        if (
            !SignatureUtils.verifyMessageSignedForFlushUsername(
                user,
                username,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnNameService();

        makePay(
            user,
            nonce_EVVM,
            getPriceToFlushUsername(username),
            priorityFee_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        for (
            uint256 i = 0;
            i < identityDetails[username].customMetadataMaxSlots;
            i++
        ) {
            delete identityCustomMetadata[username][i];
        }

        makeCaPay(
            msg.sender,
            ((5 * Evvm(evvmAddress.current).getRewardAmount()) *
                identityDetails[username].customMetadataMaxSlots) +
                priorityFee_EVVM
        );

        identityDetails[username] = IdentityBaseMetadata({
            owner: address(0),
            expireDate: 0,
            customMetadataMaxSlots: 0,
            offerMaxSlots: identityDetails[username].offerMaxSlots,
            flagNotAUsername: 0x00
        });
        nameServiceNonce[user][nonce] = true;
    }

    //█Tools for admin█████████████████████████████████████████████████████████████████████████████

    function proposeAdmin(address _adminToPropose) public onlyAdmin {
        if (_adminToPropose == address(0) || _adminToPropose == admin.current) {
            revert();
        }

        admin.proposal = _adminToPropose;
        admin.timeToAccept = block.timestamp + 1 days;
    }

    function cancelProposeAdmin() public onlyAdmin {
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    function acceptProposeAdmin() public {
        if (admin.proposal != msg.sender) {
            revert();
        }
        if (block.timestamp < admin.timeToAccept) {
            revert();
        }

        admin = AddressTypeProposal({
            current: admin.proposal,
            proposal: address(0),
            timeToAccept: 0
        });
    }

    function proposeWithdrawMateTokens(uint256 _amount) public onlyAdmin {
        if (
            Evvm(evvmAddress.current).getBalance(
                address(this),
                PRINCIPAL_TOKEN_ADDRESS
            ) -
                (5083 +
                    Evvm(evvmAddress.current).getRewardAmount() +
                    mateTokenLockedForWithdrawOffers) <
            _amount ||
            _amount == 0
        ) {
            revert();
        }

        amountToWithdrawTokens.proposal = _amount;
        amountToWithdrawTokens.timeToAccept = block.timestamp + 1 days;
    }

    function cancelWithdrawMateTokens() public onlyAdmin {
        amountToWithdrawTokens.proposal = 0;
        amountToWithdrawTokens.timeToAccept = 0;
    }

    function claimWithdrawMateTokens() public onlyAdmin {
        if (block.timestamp < amountToWithdrawTokens.timeToAccept) {
            revert();
        }

        makeCaPay(admin.current, amountToWithdrawTokens.proposal);

        amountToWithdrawTokens.proposal = 0;
        amountToWithdrawTokens.timeToAccept = 0;
    }

    function proposeChangeEvvmAddress(
        address _newEvvmAddress
    ) public onlyAdmin {
        if (_newEvvmAddress == address(0)) {
            revert();
        }
        evvmAddress.proposal = _newEvvmAddress;
        evvmAddress.timeToAccept = block.timestamp + 1 days;
    }

    function cancelChangeEvvmAddress() public onlyAdmin {
        evvmAddress.proposal = address(0);
        evvmAddress.timeToAccept = 0;
    }

    function acceptChangeEvvmAddress() public onlyAdmin {
        if (block.timestamp < evvmAddress.timeToAccept) {
            revert();
        }
        evvmAddress = AddressTypeProposal({
            current: evvmAddress.proposal,
            proposal: address(0),
            timeToAccept: 0
        });
    }

    function proposeChangePhoneNumberRegistery(
        address _newAddress
    ) public onlyAdmin {
        addressPhoneNumberRegistery.proposal = _newAddress;
        addressPhoneNumberRegistery.timeToAccept = block.timestamp + 1 days;
    }

    function cancelChangePhoneNumberRegistery() public onlyAdmin {
        addressPhoneNumberRegistery.proposal = address(0);
        addressPhoneNumberRegistery.timeToAccept = 0;
    }

    function changePhoneNumberRegistery() public onlyAdmin {
        if (block.timestamp < addressPhoneNumberRegistery.timeToAccept) {
            revert();
        }
        addressPhoneNumberRegistery = AddressTypeProposal({
            current: addressPhoneNumberRegistery.proposal,
            proposal: address(0),
            timeToAccept: 0
        });
    }

    function prepareChangeEmailRegistery(address _newAddress) public onlyAdmin {
        addressEmailRegistery.proposal = _newAddress;
        addressEmailRegistery.timeToAccept = block.timestamp + 1 days;
    }

    function cancelChangeEmailRegistery() public onlyAdmin {
        addressEmailRegistery.proposal = address(0);
        addressEmailRegistery.timeToAccept = 0;
    }

    function changeEmailRegistery() public onlyAdmin {
        if (block.timestamp < addressEmailRegistery.timeToAccept) {
            revert();
        }
        addressEmailRegistery.current = addressEmailRegistery.proposal;

        addressEmailRegistery.proposal = address(0);
        addressEmailRegistery.timeToAccept = 0;
    }

    function prepareChangeAutority(address _newAddress) public onlyAdmin {
        addressAutority.proposal = _newAddress;
        addressAutority.timeToAccept = block.timestamp + 1 days;
    }

    function cancelChangeAutority() public onlyAdmin {
        addressAutority.proposal = address(0);
        addressAutority.timeToAccept = 0;
    }

    function changeAutority() public onlyAdmin {
        if (block.timestamp < addressAutority.timeToAccept) {
            revert();
        }
        addressAutority.current = addressAutority.proposal;

        addressAutority.proposal = address(0);
        addressAutority.timeToAccept = 0;

        //PhoneNumberRegistery(addressPhoneNumberRegistery.current)
        //    .changeAutority(addressAutority.current);

        //IEmailRegistery(addressEmailRegistery.current).changeAutority(
        //    addressAutority.current
        //);
    }

    function proposeSetStopChangeVerificationsAddress() public onlyAdmin {
        if (stopChangeVerificationsAddress.flag) {
            revert();
        }
        stopChangeVerificationsAddress.timeToAcceptChange =
            block.timestamp +
            1 days;
    }

    function cancelSetStopChangeVerificationsAddress() public onlyAdmin {
        stopChangeVerificationsAddress.timeToAcceptChange = 0;
    }

    function setStopChangeVerificationsAddress() public onlyAdmin {
        if (
            block.timestamp < stopChangeVerificationsAddress.timeToAcceptChange
        ) {
            revert();
        }
        stopChangeVerificationsAddress = BoolTypeProposal({
            flag: true,
            timeToAcceptChange: 0
        });
    }

    //█Tools███████████████████████████████████████████████████████████████████████████████████████

    //█Tools for Evvm payment████████████████████

    function makePay(
        address _user_Evvm,
        uint256 _nonce_Evvm,
        uint256 _ammount_Evvm,
        uint256 _priorityFee_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) internal {
        if (_priority_Evvm) {
            Evvm(evvmAddress.current).payMateStaking_async(
                _user_Evvm,
                address(this),
                "",
                PRINCIPAL_TOKEN_ADDRESS,
                _ammount_Evvm,
                _priorityFee_Evvm,
                _nonce_Evvm,
                address(this),
                _signature_Evvm
            );
        } else {
            Evvm(evvmAddress.current).payMateStaking_sync(
                _user_Evvm,
                address(this),
                "",
                PRINCIPAL_TOKEN_ADDRESS,
                _ammount_Evvm,
                _priorityFee_Evvm,
                address(this),
                _signature_Evvm
            );
        }
    }

    function makeCaPay(address _user_Evvm, uint256 _ammount_Evvm) internal {
        Evvm(evvmAddress.current).caPay(
            _user_Evvm,
            PRINCIPAL_TOKEN_ADDRESS,
            _ammount_Evvm
        );
    }

    //█Tools for identity validation███████████████████████████████████████████████████████████████
    function isValidUsername(string memory username) internal pure {
        bytes memory usernameBytes = bytes(username);

        // Check if username length is at least 4 characters
        if (usernameBytes.length < 4) revert ErrorsLib.InvalidUsername(0x01);

        // Check if username begins with a letter
        if (!_isLetter(usernameBytes[0]))
            revert ErrorsLib.InvalidUsername(0x02);

        // Iterate through each character in the username
        for (uint256 i = 0; i < usernameBytes.length; i++) {
            // Check if character is not a digit or letter
            if (!_isDigit(usernameBytes[i]) && !_isLetter(usernameBytes[i])) {
                revert ErrorsLib.InvalidUsername(0x03);
            }
        }
    }

    function isValidPhoneNumberNumber(
        string memory _phoneNumber
    ) internal pure returns (bool) {
        bytes memory _telephoneNumberBytes = bytes(_phoneNumber);
        if (
            _telephoneNumberBytes.length < 20 &&
            _telephoneNumberBytes.length > 5
        ) {
            revert();
        }
        for (uint256 i = 0; i < _telephoneNumberBytes.length; i++) {
            if (!_isDigit(_telephoneNumberBytes[i])) {
                revert();
            }
        }
        return true;
    }

    function isValidEmail(string memory _email) internal pure returns (bool) {
        bytes memory _emailBytes = bytes(_email);
        uint256 lengthCount = 0;
        bytes1 flagVerify = 0x00;
        for (uint point = 0; point < _emailBytes.length; point++) {
            //step 1 0x00 prefix
            if (flagVerify == 0x00) {
                if (_isOnlyEmailPrefixCharacters(_emailBytes[point])) {
                    lengthCount++;
                } else {
                    if (_isAAt(_emailBytes[point])) {
                        flagVerify = 0x01;
                    } else {
                        revert();
                    }
                }
            }

            //step 2 0x01 count the prefix length
            if (flagVerify == 0x01) {
                if (lengthCount < 3) {
                    revert();
                } else {
                    flagVerify = 0x02;
                    lengthCount = 0;
                    point++;
                }
            }

            //step 3 0x02 domain name
            if (flagVerify == 0x02) {
                if (_isLetter(_emailBytes[point])) {
                    lengthCount++;
                } else {
                    if (_isAPoint(_emailBytes[point])) {
                        flagVerify = 0x03;
                    } else {
                        revert();
                    }
                }
            }

            //step 4 0x03 count the domain name length
            if (flagVerify == 0x03) {
                if (lengthCount < 3) {
                    revert();
                } else {
                    flagVerify = 0x04;
                    lengthCount = 0;
                    point++;
                }
            }

            //step 5 0x04 top level domain
            if (flagVerify == 0x04) {
                if (_isLetter(_emailBytes[point])) {
                    lengthCount++;
                } else {
                    if (_isAPoint(_emailBytes[point])) {
                        if (lengthCount < 2) {
                            revert();
                        } else {
                            lengthCount = 0;
                        }
                    } else {
                        revert();
                    }
                }
            }
        }

        if (flagVerify != 0x04) {
            revert();
        }

        return true;
    }

    function _isDigit(bytes1 character) private pure returns (bool) {
        return (character >= 0x30 && character <= 0x39); // ASCII range for digits 0-9
    }

    function _isLetter(bytes1 character) private pure returns (bool) {
        return ((character >= 0x41 && character <= 0x5A) ||
            (character >= 0x61 && character <= 0x7A)); // ASCII ranges for letters A-Z and a-z
    }

    function _isAnySimbol(bytes1 character) private pure returns (bool) {
        return ((character >= 0x21 && character <= 0x2F) || /// @dev includes characters from "!" to "/"
            (character >= 0x3A && character <= 0x40) || /// @dev includes characters from ":" to "@"
            (character >= 0x5B && character <= 0x60) || /// @dev includes characters from "[" to "`"
            (character >= 0x7B && character <= 0x7E)); /// @dev includes characters from "{" to "~"
    }

    function _isOnlyEmailPrefixCharacters(
        bytes1 character
    ) private pure returns (bool) {
        return (_isLetter(character) ||
            _isDigit(character) ||
            (character >= 0x21 && character <= 0x2F) || /// @dev includes characters from "!" to "/"
            (character >= 0x3A && character <= 0x3F) || /// @dev includes characters from ":" to "?"
            (character >= 0x5B && character <= 0x60) || /// @dev includes characters from "[" to "`"
            (character >= 0x7B && character <= 0x7E)); /// @dev includes characters from "{" to "~"
    }

    function _isAPoint(bytes1 character) private pure returns (bool) {
        return character == 0x2E;
    }

    function _isAAt(bytes1 character) private pure returns (bool) {
        return character == 0x40;
    }

    //█Tools for username hash█████████████████████████████████████████████████████████████████████

    function hashUsername(
        string memory _username,
        uint256 _randomNumber
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_username, _randomNumber));
    }

    //█Getters█████████████████████████████████████████████████████████████████████████████████████

    //█Getters for services██████████████████████████████████████████████████████████████

    function verifyIfIdentityExists(
        string memory _identity
    ) public view returns (bool) {
        if (identityDetails[_identity].flagNotAUsername == 0x01) {
            if (
                identityDetails[_identity].owner == address(0) ||
                identityDetails[_identity].expireDate != 0
            ) {
                return false;
            } else {
                return true;
            }
        } else {
            if (identityDetails[_identity].expireDate == 0) {
                return false;
            } else {
                return true;
            }
        }
    }

    function strictVerifyIfIdentityExist(
        string memory _username
    ) public view returns (bool) {
        if (identityDetails[_username].flagNotAUsername == 0x01) {
            if (
                identityDetails[_username].owner == address(0) ||
                identityDetails[_username].expireDate != 0
            ) {
                revert();
            } else {
                return true;
            }
        } else {
            if (identityDetails[_username].expireDate == 0) {
                revert();
            } else {
                return true;
            }
        }
    }

    function getOwnerOfIdentity(
        string memory _username
    ) public view returns (address) {
        return identityDetails[_username].owner;
    }

    function verifyStrictAndGetOwnerOfIdentity(
        string memory _username
    ) public view returns (address answer) {
        if (strictVerifyIfIdentityExist(_username)) {
            answer = identityDetails[_username].owner;
        }
    }

    /**
     *  @notice This function is used to see the price to renew a username
     *  @param _identity the username to see the price to renew
     *  @return price the price to renew the username
     */
    function seePriceToRenew(
        string memory _identity
    ) public view returns (uint256 price) {
        ///verifica si es menor a 366 días
        if (identityDetails[_identity].expireDate >= block.timestamp) {
            if (usernameOffers[_identity][0].expireDate != 0) {
                ///buscamos el precio mas alto de las ofertas
                for (
                    uint256 i = 0;
                    i < identityDetails[_identity].offerMaxSlots;
                    i++
                ) {
                    if (
                        usernameOffers[_identity][i].expireDate >
                        block.timestamp &&
                        usernameOffers[_identity][i].offerer != address(0)
                    ) {
                        if (usernameOffers[_identity][i].amount > price) {
                            price = usernameOffers[_identity][i].amount;
                        }
                    }
                }
            }
            //Tiene un costo variable pero mínimo de 500 MATE,
            if (price == 0) {
                price = 500 * 10 ** 18;
            } else {
                uint256 mateReward = Evvm(evvmAddress.current)
                    .getRewardAmount();
                ///coloca el precio del username en un 0.5% del precio de la oferta más alta, con tope en 500,000 * mateReward
                price = ((price * 5) / 1000) > (500000 * mateReward)
                    ? (500000 * mateReward)
                    : ((price * 5) / 1000);
            }
        } else {
            price = 500_000 * Evvm(evvmAddress.current).getRewardAmount();
        }
    }

    function getPriceToAddCustomMetadata() public view returns (uint256 price) {
        price = 10 * Evvm(evvmAddress.current).getRewardAmount();
    }

    function getPriceToRemoveCustomMetadata()
        public
        view
        returns (uint256 price)
    {
        price = 10 * Evvm(evvmAddress.current).getRewardAmount();
    }

    function getPriceToFlushCustomMetadata(
        string memory _identity
    ) public view returns (uint256 price) {
        price =
            (10 * Evvm(evvmAddress.current).getRewardAmount()) *
            identityDetails[_identity].customMetadataMaxSlots;
    }

    function getPriceToFlushUsername(
        string memory _identity
    ) public view returns (uint256 price) {
        price =
            ((10 * Evvm(evvmAddress.current).getRewardAmount()) *
                identityDetails[_identity].customMetadataMaxSlots) +
            Evvm(evvmAddress.current).getRewardAmount();
    }

    //█User██████████████████████████████████████████████████████████████████████████████

    function checkIfNameServiceNonceIsAvailable(
        address _user,
        uint256 _nonce
    ) public view returns (bool) {
        return nameServiceNonce[_user][_nonce];
    }

    //█Identity (general)████████████████████████████████████████████████████████████████
    function isUsernameAvailable(
        string memory _username
    ) public view returns (bool) {
        if (identityDetails[_username].expireDate == 0) {
            return true;
        } else {
            return
                identityDetails[_username].expireDate + 60 days <
                block.timestamp;
        }
    }

    function getIdentityBasicMetadata(
        string memory _username
    ) public view returns (address, uint256) {
        return (
            identityDetails[_username].owner,
            identityDetails[_username].expireDate
        );
    }

    function getAmountOfCustomMetadata(
        string memory _username
    ) public view returns (uint256) {
        return identityDetails[_username].customMetadataMaxSlots;
    }

    function getFullCustomMetadataOfIdentity(
        string memory _username
    ) public view returns (string[] memory) {
        string[] memory _customMetadata = new string[](
            identityDetails[_username].customMetadataMaxSlots
        );
        for (
            uint256 i = 0;
            i < identityDetails[_username].customMetadataMaxSlots;
            i++
        ) {
            _customMetadata[i] = identityCustomMetadata[_username][i];
        }
        return _customMetadata;
    }

    function getSingleCustomMetadataOfIdentity(
        string memory _username,
        uint256 _key
    ) public view returns (string memory) {
        return identityCustomMetadata[_username][_key];
    }

    function getCustomMetadataMaxSlotsOfIdentity(
        string memory _username
    ) public view returns (uint256) {
        return identityDetails[_username].customMetadataMaxSlots;
    }

    //█Usernames█████████████████████████████████████████████████████████████████████████

    /**
     * @dev Returns offres has not been withdrawn (expired or unexpired)
     * @param _username The username to get the offers
     */
    function getOffersOfUsername(
        string memory _username
    ) public view returns (OfferMetadata[] memory offers) {
        offers = new OfferMetadata[](identityDetails[_username].offerMaxSlots);

        for (uint256 i = 0; i < identityDetails[_username].offerMaxSlots; i++) {
            offers[i] = usernameOffers[_username][i];
        }
    }

    function getSingleOfferOfUsername(
        string memory _username,
        uint256 _offerID
    ) public view returns (OfferMetadata memory offer) {
        return usernameOffers[_username][_offerID];
    }

    function getLengthOfOffersUsername(
        string memory _username
    ) public view returns (uint256 length) {
        do {
            length++;
        } while (usernameOffers[_username][length].expireDate != 0);
    }

    function getExpireDateOfIdentity(
        string memory _identity
    ) public view returns (uint256) {
        return identityDetails[_identity].expireDate;
    }

    function getPricePerRegistration() public view returns (uint256) {
        return Evvm(evvmAddress.current).getRewardAmount() * 100;
    }

    function getAdmin() public view returns (address) {
        return admin.current;
    }

    function getAdminFullDetails()
        public
        view
        returns (
            address currentAdmin,
            address proposalAdmin,
            uint256 timeToAcceptAdmin
        )
    {
        return (admin.current, admin.proposal, admin.timeToAccept);
    }

    function getProposedWithdrawAmountFullDetails()
        public
        view
        returns (
            uint256 proposalAmountToWithdrawTokens,
            uint256 timeToAcceptAmountToWithdrawTokens
        )
    {
        return (
            amountToWithdrawTokens.proposal,
            amountToWithdrawTokens.timeToAccept
        );
    }

    function getEvvmAddress() public view returns (address) {
        return evvmAddress.current;
    }

    function getEvvmAddressFullDetails()
        public
        view
        returns (
            address currentEvvmAddress,
            address proposalEvvmAddress,
            uint256 timeToAcceptEvvmAddress
        )
    {
        return (
            evvmAddress.current,
            evvmAddress.proposal,
            evvmAddress.timeToAccept
        );
    }

    function getPhoneNumberRegistery() public view returns (address) {
        return addressPhoneNumberRegistery.current;
    }

    function getPhoneNumberRegisteryFullDetails()
        public
        view
        returns (
            address currentPhoneNumberRegistery,
            address proposalPhoneNumberRegistery,
            uint256 timeToAcceptPhoneNumberRegistery
        )
    {
        return (
            addressPhoneNumberRegistery.current,
            addressPhoneNumberRegistery.proposal,
            addressPhoneNumberRegistery.timeToAccept
        );
    }

    function getEmailRegistery() public view returns (address) {
        return addressEmailRegistery.current;
    }

    function getEmailRegisteryFullDetails()
        public
        view
        returns (
            address currentEmailRegistery,
            address proposalEmailRegistery,
            uint256 timeToAcceptEmailRegistery
        )
    {
        return (
            addressEmailRegistery.current,
            addressEmailRegistery.proposal,
            addressEmailRegistery.timeToAccept
        );
    }

    function getAutority() public view returns (address) {
        return addressAutority.current;
    }

    function getAutorityFullDetails()
        public
        view
        returns (
            address currentAutority,
            address proposalAutority,
            uint256 timeToAcceptAutority
        )
    {
        return (
            addressAutority.current,
            addressAutority.proposal,
            addressAutority.timeToAccept
        );
    }

    function getStopChangeVerificationsAddressFullDetails()
        public
        view
        returns (bool flag, uint256 timeToAcceptChange)
    {
        return (
            stopChangeVerificationsAddress.flag,
            stopChangeVerificationsAddress.timeToAcceptChange
        );
    }
}
