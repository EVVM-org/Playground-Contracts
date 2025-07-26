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

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Mns} from "@EVVM/playground/mns/Mns.sol";
import {SignatureRecover} from "@EVVM/libraries/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";
import {EvvmStorage} from "@EVVM/playground/evvm/lib/EvvmStorage.sol";
import {ErrorsLib} from "./lib/ErrorsLib.sol";

contract EVVM is EvvmStorage {
    modifier onlyAdmin() {
        if (msg.sender != admin.current) {
            revert();
        }
        _;
    }

    constructor(address _initialOwner, address _sMateContractAddress) {
        sMateContractAddress = _sMateContractAddress;

        admin.current = _initialOwner;

        maxAmountToWithdraw.current = 0.1 ether;

        balances[_sMateContractAddress][evvmMetadata.principalTokenAddress] = getRewardAmount() * 2;

        stakerList[_sMateContractAddress] = 0x01;

        breakerSetupMateNameServiceAddress = 0x01;
    }

    function _setupMateNameServiceAddress(
        address _mateNameServiceAddress
    ) external {
        if (breakerSetupMateNameServiceAddress == 0x00) {
            revert();
        }
        mateNameServiceAddress = _mateNameServiceAddress;
        balances[mateNameServiceAddress][evvmMetadata.principalTokenAddress] = 10000 * 10 ** 18;
        stakerList[mateNameServiceAddress] = 0x01;
    }

    fallback() external {
        if (currentImplementation == address(0)) revert();

        assembly {
            /**
             *  Copy the data of the call
             *  copy s bytes of calldata from position
             *  f to mem in position t
             *  calldatacopy(t, f, s)
             */
            calldatacopy(0, 0, calldatasize())

            /**
             * 2. We make a delegatecall to the implementation
             *    and we copy the result
             */
            let result := delegatecall(
                gas(), // Send all the available gas
                sload(currentImplementation.slot), // Address of the implementation
                0, // Start of the memory where the data is
                calldatasize(), // Size of the data
                0, // Where we will store the response
                0 // Initial size of the response
            )

            /// Copy the response
            returndatacopy(0, 0, returndatasize())

            /// Handle the result
            switch result
            case 0 {
                revert(0, returndatasize()) // If it failed, revert
            }
            default {
                return(0, returndatasize()) // If it worked, return
            }
        }
    }

    /**
     * @dev _addBalance, _addMateToTotalSupply and _setPointStaker are debug functions
     *       DO NOT USE IN PRODUCTION!!!!!!!
     */
    function _addBalance(
        address user,
        address token,
        uint256 quantity
    ) external {
        balances[user][token] += quantity;
    }

    function _setPointStaker(address user, bytes1 answer) external {
        stakerList[user] = answer;
    }

    function _addMateToTotalSupply(uint256 amount) external {
        evvmMetadata.totalSupply += amount;
    }

    //░▒▓█Withdrawal functions██████████████████████████████████████████████████▓▒░

    function withdrawalSync(
        address user,
        address addressToReceive,
        address token,
        uint256 amount,
        uint256 priorityFee,
        bytes memory signature,
        uint8 _solutionId,
        bytes calldata _options
    ) public payable {
        if (
            !verifyMessageSignedForWithdrawal(
                user,
                addressToReceive,
                token,
                amount,
                priorityFee,
                nextSyncUsedNonce[user],
                false,
                signature
            )
        ) {
            revert ErrorsLib.InvalidSignature();
        }

        if (token == evvmMetadata.principalTokenAddress || balances[user][token] < amount) {
            revert();
        }

        if (token == ETH_ADDRESS) {
            if (amount > 100000000000000000) {
                revert();
            }
        }

        balances[user][token] -= amount;

        /// @dev unused variable just for avoiding the warning
        _solutionId;
        _options;

        nextSyncUsedNonce[user]++;
    }

    function withdrawalAsync(
        address user,
        address addressToReceive,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bytes memory signature,
        uint8 _solutionId,
        bytes calldata _options
    ) public payable {
        if (
            !verifyMessageSignedForWithdrawal(
                user,
                addressToReceive,
                token,
                amount,
                priorityFee,
                nonce,
                true,
                signature
            )
        ) {
            revert ErrorsLib.InvalidSignature();
        }

        if (
            token == evvmMetadata.principalTokenAddress ||
            asyncUsedNonce[user][nonce] ||
            balances[user][token] < amount
        ) {
            revert();
        }

        if (token == ETH_ADDRESS) {
            if (amount > 100000000000000000) {
                revert();
            }
        }

        balances[user][token] -= amount;

        /// @dev unused variable just for avoiding the warning
        _solutionId;
        _options;

        asyncUsedNonce[user][nonce] = true;
    }

    //░▒▓█Pay functions█████████████████████████████████████████████████████████▓▒░

    /**
     *  @notice Pay function for non sMate holders (syncronous nonce)
     *  @param from user // who wants to pay
     *  @param to_address address of the receiver
     *  @param to_identity identity of the receiver
     *  @param token address of the token to send
     *  @param amount amount to send
     *  @param priorityFee priorityFee to send to the sMate holder
     *  @param signature signature of the user who wants to send the message
     */
    function payNoMateStaking_sync(
        address from,
        address to_address,
        string memory to_identity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        address executor,
        bytes memory signature
    ) external {
        if (
            !verifyMessageSignedForPay(
                from,
                to_address,
                to_identity,
                token,
                amount,
                priorityFee,
                nextSyncUsedNonce[from],
                false,
                executor,
                signature
            )
        ) {
            revert();
        }

        if (executor != address(0)) {
            if (msg.sender != executor) {
                revert();
            }
        }

        address to = !Strings.equal(to_identity, "")
            ? Mns(mateNameServiceAddress).verifyStrictAndGetOwnerOfIdentity(
                to_identity
            )
            : to_address;

        if (!_updateBalance(from, to, token, amount)) {
            revert();
        }

        nextSyncUsedNonce[from]++;
    }

    /**
     *  @notice Pay function
     *  @param from user // who wants to pay
     *  @param to_address address of the receiver
     *  @param to_identity identity of the receiver
     *  @param token address of the token to send
     *  @param amount amount to send
     *  @param priorityFee priorityFee to send to the sMate holder
     *  @param nonce nonce of the transaction
     *  @param priorityFlag if the transaction is priority or not (false = sync, true = async)
     *  @param executor address of the executor
     *  @param signature signature of the user who wants to send the message
     */
    function pay(
        address from,
        address to_address,
        string memory to_identity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        address executor,
        bytes memory signature
    ) external {
        if (
            !verifyMessageSignedForPay(
                from,
                to_address,
                to_identity,
                token,
                amount,
                priorityFee,
                priorityFlag ? nonce : nextSyncUsedNonce[from],
                priorityFlag,
                executor,
                signature
            )
        ) revert();

        if (executor != address(0)) {
            if (msg.sender != executor) revert();
        }

        if (priorityFlag) {
            if (asyncUsedNonce[from][nonce]) revert();
        }

        address to = !Strings.equal(to_identity, "")
            ? Mns(mateNameServiceAddress).verifyStrictAndGetOwnerOfIdentity(
                to_identity
            )
            : to_address;

        if (!_updateBalance(from, to, token, amount)) revert();

        if (isMateStaker(msg.sender)) {
            if (priorityFee > 0) {
                if (!_updateBalance(from, msg.sender, token, priorityFee)) {
                    revert();
                }
            }

            _giveMateReward(msg.sender, 1);
        }
    }

    
    function payMultiple(
        PayData[] memory payData
    )
        external
        returns (
            uint256 successfulTransactions,
            uint256 failedTransactions,
            bool[] memory results
        )
    {
        address to_aux;
        results = new bool[](payData.length);
        for (uint256 iteration = 0; iteration < payData.length; iteration++) {
            if (
                !verifyMessageSignedForPay(
                    payData[iteration].from,
                    payData[iteration].to_address,
                    payData[iteration].to_identity,
                    payData[iteration].token,
                    payData[iteration].amount,
                    payData[iteration].priorityFee,
                    payData[iteration].priority
                        ? payData[iteration].nonce
                        : nextSyncUsedNonce[payData[iteration].from],
                    payData[iteration].priority,
                    payData[iteration].executor,
                    payData[iteration].signature
                )
            ) {
                revert();
            }

            if (payData[iteration].executor != address(0)) {
                if (msg.sender != payData[iteration].executor) {
                    failedTransactions++;
                    results[iteration] = false;
                    continue;
                }
            }

            if (payData[iteration].priority) {
                /// @dev priority == true (async)

                if (
                    !asyncUsedNonce[payData[iteration].from][
                        payData[iteration].nonce
                    ]
                ) {
                    asyncUsedNonce[payData[iteration].from][
                        payData[iteration].nonce
                    ] = true;
                } else {
                    failedTransactions++;
                    results[iteration] = false;
                    continue;
                }
            } else {
                /// @dev priority == false (sync)

                if (
                    nextSyncUsedNonce[payData[iteration].from] ==
                    payData[iteration].nonce
                ) {
                    nextSyncUsedNonce[payData[iteration].from]++;
                } else {
                    failedTransactions++;
                    results[iteration] = false;
                    continue;
                }
            }

            to_aux = !Strings.equal(payData[iteration].to_identity, "")
                ? Mns(mateNameServiceAddress).verifyStrictAndGetOwnerOfIdentity(
                    payData[iteration].to_identity
                )
                : payData[iteration].to_address;

            if (
                payData[iteration].priorityFee + payData[iteration].amount >
                balances[payData[iteration].from][payData[iteration].token]
            ) {
                failedTransactions++;
                results[iteration] = false;
                continue;
            }

            if (
                !_updateBalance(
                    payData[iteration].from,
                    to_aux,
                    payData[iteration].token,
                    payData[iteration].amount
                )
            ) {
                failedTransactions++;
                results[iteration] = false;
                continue;
            } else {
                if (
                    payData[iteration].priorityFee > 0 &&
                    isMateStaker(msg.sender)
                ) {
                    if (
                        !_updateBalance(
                            payData[iteration].from,
                            msg.sender,
                            payData[iteration].token,
                            payData[iteration].priorityFee
                        )
                    ) {
                        failedTransactions++;
                        results[iteration] = false;
                        continue;
                    }
                }

                successfulTransactions++;
                results[iteration] = true;
            }
        }

        if (isMateStaker(msg.sender)) {
            _giveMateReward(msg.sender, successfulTransactions);
        }
    }

    function dispersePay(
        address from,
        DispersePayMetadata[] memory toData,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priority,
        address executor,
        bytes memory signature
    ) external {
        if (
            !verifyMessageSignedForDispersePay(
                from,
                sha256(abi.encode(toData)),
                token,
                amount,
                priorityFee,
                priority ? nonce : nextSyncUsedNonce[from],
                priority,
                executor,
                signature
            )
        ) {
            revert ErrorsLib.InvalidSignature();
        }

        if (executor != address(0)) {
            if (msg.sender != executor) {
                revert();
            }
        }

        if (priority) {
            if (asyncUsedNonce[from][nonce]) {
                revert ErrorsLib.InvalidAsyncNonce();
            }
        }

        if (balances[from][token] < amount + priorityFee) {
            revert();
        }

        uint256 acomulatedAmount = 0;
        balances[from][token] -= (amount + priorityFee);
        address to_aux;
        for (uint256 i = 0; i < toData.length; i++) {
            acomulatedAmount += toData[i].amount;

            if (!Strings.equal(toData[i].to_identity, "")) {
                if (
                    Mns(mateNameServiceAddress).strictVerifyIfIdentityExist(
                        toData[i].to_identity
                    )
                ) {
                    to_aux = Mns(mateNameServiceAddress).getOwnerOfIdentity(
                        toData[i].to_identity
                    );
                }
            } else {
                to_aux = toData[i].to_address;
            }

            balances[to_aux][token] += toData[i].amount;
        }

        if (acomulatedAmount != amount) {
            revert();
        }

        if (isMateStaker(msg.sender)) {
            _giveMateReward(msg.sender, 1);
            balances[msg.sender][token] += priorityFee;
        } else {
            balances[from][token] += priorityFee;
        }

        if (priority) {
            asyncUsedNonce[from][nonce] = true;
        } else {
            nextSyncUsedNonce[from]++;
        }
    }

    function caPay(address to, address token, uint256 amount) external {
        uint256 size;
        address from = msg.sender;

        assembly {
            /// @dev check the size of the opcode of the address
            size := extcodesize(from)
        }

        if (size == 0) {
            revert();
        }

        if (!_updateBalance(from, to, token, amount)) {
            revert();
        }

        if (isMateStaker(msg.sender)) {
            _giveMateReward(msg.sender, 1);
        }
    }

    function disperseCaPay(
        DisperseCaPayMetadata[] memory toData,
        address token,
        uint256 amount
    ) external {
        uint256 size;
        address from = msg.sender;

        assembly {
            /// @dev check the size of the opcode of the address
            size := extcodesize(from)
        }

        if (size == 0) {
            revert();
        }

        uint256 acomulatedAmount = 0;
        if (balances[msg.sender][token] < amount) {
            revert();
        }

        balances[msg.sender][token] -= amount;

        for (uint256 i = 0; i < toData.length; i++) {
            acomulatedAmount += toData[i].amount;
            if (acomulatedAmount > amount) {
                revert();
            }

            balances[toData[i].toAddress][token] += toData[i].amount;
        }

        if (acomulatedAmount != amount) {
            revert();
        }

        if (isMateStaker(msg.sender)) {
            _giveMateReward(msg.sender, 1);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    /// fisher bridge functions ///////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////

    function fisherWithdrawal(
        address user,
        address addressToReceive,
        address token,
        uint256 priorityFee,
        uint256 amount,
        bytes memory signature
    ) public {
        if (
            !verifyMessageSignedForFisherBridge(
                user,
                addressToReceive,
                nextFisherWithdrawalNonce[user],
                token,
                priorityFee,
                amount,
                signature
            )
        ) {
            revert ErrorsLib.InvalidSignature();
        }

        if (
            token == evvmMetadata.principalTokenAddress ||
            balances[user][token] < amount + priorityFee
        ) {
            revert();
        }

        if (token == ETH_ADDRESS) {
            if (amount > maxAmountToWithdraw.current) {
                revert();
            }
        }

        balances[user][token] -= (amount + priorityFee);

        balances[msg.sender][token] += priorityFee;

        balances[msg.sender][evvmMetadata.principalTokenAddress] += evvmMetadata.reward;

        nextFisherWithdrawalNonce[user]++;

        nextFisherWithdrawalNonce[user]++;
    }

    //░▒▓█Internal functions████████████████████████████████████████████████████▓▒░

    //░▒▓█Balance functions██████████████████████████▓▒░
    function _updateBalance(
        address from,
        address to,
        address token,
        uint256 value
    ) internal returns (bool) {
        uint256 fromBalance = balances[from][token];
        uint256 toBalance = balances[to][token];
        if (fromBalance < value) {
            return false;
        } else {
            balances[from][token] = fromBalance - value;

            balances[to][token] = toBalance + value;

            return (toBalance + value == balances[to][token]);
        }
    }

    function _giveMateReward(
        address user,
        uint256 amount
    ) internal returns (bool) {
        uint256 mateReward = evvmMetadata.reward * amount;
        uint256 userBalance = balances[user][evvmMetadata.principalTokenAddress];

        balances[user][evvmMetadata.principalTokenAddress] = userBalance + mateReward;

        return (userBalance + mateReward == balances[user][evvmMetadata.principalTokenAddress]);
    }

    //░▒▓█Signature functions████████████████████████▓▒░
    /**
     *  @dev using EIP-191 (https://eips.ethereum.org/EIPS/eip-191) can be used to sign and
     *       verify messages, the next functions are used to verify the messages signed
     *       by the users
     */

    /**
     *  @notice This function is used to verify the message signed for the withdrawal
     *  @param signer user who signed the message
     *  @param addressToReceive address of the receiver
     *  @param _token address of the token to withdraw
     *  @param _amount amount to withdraw
     *  @param _priorityFee priorityFee to send to the white fisher
     *  @param _nonce nonce of the transaction
     *  @param _priority_boolean if the transaction is priority or not
     *  @param signature signature of the user who wants to send the message
     *  @return true if the signature is valid
     */
    function verifyMessageSignedForWithdrawal(
        address signer,
        address addressToReceive,
        address _token,
        uint256 _amount,
        uint256 _priorityFee,
        uint256 _nonce,
        bool _priority_boolean,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    _priority_boolean ? "920f3d76" : "52896a1f",
                    ",",
                    AdvancedStrings.addressToString(addressToReceive),
                    ",",
                    AdvancedStrings.addressToString(_token),
                    ",",
                    Strings.toString(_amount),
                    ",",
                    Strings.toString(_priorityFee),
                    ",",
                    Strings.toString(_nonce),
                    ",",
                    _priority_boolean ? "true" : "false"
                ),
                signature,
                signer
            );
    }

    /**
     *  @notice This function is used to verify the message signed for the payment
     *  @param signer user who signed the message
     *  @param _receiverAddress address of the receiver
     *  @param _receiverIdentity identity of the receiver
     *
     *  @notice if the _receiverAddress is 0x0 the function will use the _receiverIdentity
     *
     *  @param _token address of the token to send
     *  @param _amount amount to send
     *  @param _priorityFee priorityFee to send to the sMate holder
     *  @param _nonce nonce of the transaction
     *  @param _priority_boolean if the transaction is priority or not
     *  @param _executor the executor of the transaction
     *  @param signature signature of the user who wants to send the message
     *  @return true if the signature is valid
     */
    function verifyMessageSignedForPay(
        address signer,
        address _receiverAddress,
        string memory _receiverIdentity,
        address _token,
        uint256 _amount,
        uint256 _priorityFee,
        uint256 _nonce,
        bool _priority_boolean,
        address _executor,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    _priority_boolean ? "f4e1895b" : "4faa1fa2",
                    ",",
                    _receiverAddress == address(0)
                        ? _receiverIdentity
                        : AdvancedStrings.addressToString(_receiverAddress),
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
                ),
                signature,
                signer
            );
    }

    /**
     *  @notice This function is used to verify the message signed for the dispersePay
     *  @param signer user who signed the message
     *  @param hashList hash of the list of the transactions, the hash is calculated
     *                  using sha256(abi.encode(toData))
     *  @param _token token address to send
     *  @param _amount amount to send
     *  @param _priorityFee priorityFee to send to the fisher who wants to send the message
     *  @param _nonce nonce of the transaction
     *  @param _priority_boolean if the transaction is priority or not
     *  @param _executor the executor of the transaction
     *  @param signature signature of the user who wants to send the message
     *  @return true if the signature is valid
     */
    function verifyMessageSignedForDispersePay(
        address signer,
        bytes32 hashList,
        address _token,
        uint256 _amount,
        uint256 _priorityFee,
        uint256 _nonce,
        bool _priority_boolean,
        address _executor,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
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
                ),
                signature,
                signer
            );
    }

    /**
     *  @notice This function is used to verify the message signed for the fisher bridge
     *  @param signer user who signed the message
     *  @param addressToReceive address of the receiver
     *  @param _nonce nonce of the transaction
     *  @param tokenAddress address of the token to deposit
     *  @param _priorityFee priorityFee to send to the white fisher
     *  @param _amount amount to deposit
     *  @param signature signature of the user who wants to send the message
     *  @return true if the signature is valid
     */
    function verifyMessageSignedForFisherBridge(
        address signer,
        address addressToReceive,
        uint256 _nonce,
        address tokenAddress,
        uint256 _priorityFee,
        uint256 _amount,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                string.concat(
                    AdvancedStrings.addressToString(addressToReceive),
                    ",",
                    Strings.toString(_nonce),
                    ",",
                    AdvancedStrings.addressToString(tokenAddress),
                    ",",
                    Strings.toString(_priorityFee),
                    ",",
                    Strings.toString(_amount)
                ),
                signature,
                signer
            );
    }

    //░▒▓█Functions for admin███████████████████████████████████████████████████▓▒░

    //░▒▓█Proxy███▓▒░
    function proposeImplementation(address _newImpl) external onlyAdmin {
        proposalImplementation = _newImpl;
        timeToAcceptImplementation = block.timestamp + 30 days;
    }

    function rejectUpgrade() external onlyAdmin {
        proposalImplementation = address(0);
        timeToAcceptImplementation = 0;
    }

    function acceptImplementation() external onlyAdmin {
        if (block.timestamp < timeToAcceptImplementation) revert();
        currentImplementation = proposalImplementation;
        proposalImplementation = address(0);
        timeToAcceptImplementation = 0;
    }

    //░▒▓█MNS address███▓▒░
    function setMNSAddress(address _mateNameServiceAddress) external onlyAdmin {
        mateNameServiceAddress = _mateNameServiceAddress;
    }

    //░▒▓█Change admin███▓▒░
    function proposeAdmin(address _newOwner) external onlyAdmin {
        if (_newOwner == address(0) || _newOwner == admin.current) {
            revert();
        }

        admin.proposal = _newOwner;
        admin.timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposalAdmin() external onlyAdmin {
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    function acceptAdmin() external {
        if (block.timestamp < admin.timeToAccept) {
            revert();
        }
        if (msg.sender != admin.proposal) {
            revert();
        }

        admin.current = admin.proposal;

        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    //░▒▓█Whitelist tokens███▓▒░

    /**
     * @notice This next functions are used to whitelist tokens and set the uniswap pool for
     *         each token, the uniswap pool is used to calculate the limit of the amount to
     *         send in the withdrawal functions
     */

    function prepareTokenToBeWhitelisted(
        address token,
        address pool
    ) external onlyAdmin {
        whitelistTokenToBeAdded_address = token;
        whitelistTokenToBeAdded_pool = pool;
        whitelistTokenToBeAdded_dateToSet = block.timestamp + 1 days;
    }

    function cancelPrepareTokenToBeWhitelisted() external onlyAdmin {
        whitelistTokenToBeAdded_address = address(0);
        whitelistTokenToBeAdded_pool = address(0);
        whitelistTokenToBeAdded_dateToSet = 0;
    }

    function addTokenToWhitelist() external onlyAdmin {
        if (block.timestamp < whitelistTokenToBeAdded_dateToSet) {
            revert();
        }
        whitelistedTokens[
            whitelistTokenToBeAdded_address
        ] = whitheListedTokenMetadata({
            isAllowed: true,
            uniswapPool: whitelistTokenToBeAdded_pool
        });

        whitelistedTokens[whitelistTokenToBeAdded_address].isAllowed = true;

        whitelistTokenToBeAdded_address = address(0);
        whitelistTokenToBeAdded_pool = address(0);
        whitelistTokenToBeAdded_dateToSet = 0;
    }

    function changePool(address token, address pool) external onlyAdmin {
        if (!whitelistedTokens[token].isAllowed) {
            revert();
        }
        whitelistedTokens[token].uniswapPool = pool;
    }

    function removeTokenWhitelist(address token) external onlyAdmin {
        if (!whitelistedTokens[token].isAllowed) {
            revert();
        }
        whitelistedTokens[token].isAllowed = false;
        whitelistedTokens[token].uniswapPool = address(0);
    }

    function prepareMaxAmountToWithdraw(uint256 amount) external onlyAdmin {
        maxAmountToWithdraw.proposal = amount;
        maxAmountToWithdraw.timeToAccept = block.timestamp + 1 days;
    }

    function cancelPrepareMaxAmountToWithdraw() external onlyAdmin {
        maxAmountToWithdraw.proposal = 0;
        maxAmountToWithdraw.timeToAccept = 0;
    }

    function setMaxAmountToWithdraw() external onlyAdmin {
        if (block.timestamp < maxAmountToWithdraw.timeToAccept) {
            revert();
        }
        maxAmountToWithdraw.current = maxAmountToWithdraw.proposal;
        maxAmountToWithdraw.proposal = 0;
        maxAmountToWithdraw.timeToAccept = 0;
    }

    //░▒▓█reward functions██████████████████████████████████████████████████████▓▒░

    function recalculateReward() public {
        if (evvmMetadata.totalSupply > evvmMetadata.eraTokens) {
            evvmMetadata.eraTokens += ((evvmMetadata.totalSupply - evvmMetadata.eraTokens) / 2);
            balances[msg.sender][evvmMetadata.principalTokenAddress] +=
                evvmMetadata.reward *
                getRandom(1, 5083);
            evvmMetadata.reward = evvmMetadata.reward / 2;
        } else {
            revert();
        }
    }

    function getRandom(
        uint256 min,
        uint256 max
    ) internal view returns (uint256) {
        return
            min +
            (uint256(
                keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
            ) % (max - min + 1));
    }

    //░▒▓█sMate functions███████████████████████████████████████████████████████▓▒░

    function pointStaker(address user, bytes1 answer) public {
        if (msg.sender != sMateContractAddress) {
            revert();
        }
        stakerList[user] = answer;
    }

    //░▒▓█Getter functions██████████████████████████████████████████████████████▓▒░

    function getMateNameServiceAddress() external view returns (address) {
        return mateNameServiceAddress;
    }

    function getSMateContractAddress() external view returns (address) {
        return sMateContractAddress;
    }

    function getMaxAmountToWithdraw() external view returns (uint256) {
        return maxAmountToWithdraw.current;
    }

    function getNextCurrentSyncNonce(
        address user
    ) external view returns (uint256) {
        return nextSyncUsedNonce[user];
    }

    function getIfUsedAsyncNonce(
        address user,
        uint256 nonce
    ) external view returns (bool) {
        return asyncUsedNonce[user][nonce];
    }

    function getNextFisherWithdrawalNonce(
        address user
    ) external view returns (uint256) {
        return nextFisherWithdrawalNonce[user];
    }

    function getNextFisherDepositNonce(
        address user
    ) external view returns (uint256) {
        return nextFisherDepositNonce[user];
    }

    function getBalance(
        address user,
        address token
    ) external view returns (uint) {
        return balances[user][token];
    }

    function isMateStaker(address user) public view returns (bool) {
        return stakerList[user] == 0x01;
    }

    function getEraPrincipalToken() public view returns (uint256) {
        return evvmMetadata.eraTokens;
    }

    function getRewardAmount() public view returns (uint256) {
        return evvmMetadata.reward;
    }

    function getPrincipalTokenTotalSupply() public view returns (uint256) {
        return evvmMetadata.totalSupply;
    }

    function getIfTokenIsWhitelisted(address token) public view returns (bool) {
        return whitelistedTokens[token].isAllowed;
    }

    function getTokenUniswapPool(address token) public view returns (address) {
        return whitelistedTokens[token].uniswapPool;
    }

    function getCurrentImplementation() public view returns (address) {
        return currentImplementation;
    }

    function getProposalImplementation() public view returns (address) {
        return proposalImplementation;
    }

    function getTimeToAcceptImplementation() public view returns (uint256) {
        return timeToAcceptImplementation;
    }

    function getCurrentAdmin() public view returns (address) {
        return admin.current;
    }

    function getProposalAdmin() public view returns (address) {
        return admin.proposal;
    }

    function getTimeToAcceptAdmin() public view returns (uint256) {
        return admin.timeToAccept;
    }

    function getWhitelistTokenToBeAdded() public view returns (address) {
        return whitelistTokenToBeAdded_address;
    }
}
