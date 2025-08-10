// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;
/**

    8 8                                                                              
 ad88888ba    ad88888ba   88b           d88         db    888888888888  88888888888  
d8" 8 8 "8b  d8"     "8b  888b         d888        d88b        88       88           
Y8, 8 8      Y8,          88`8b       d8'88       d8'`8b       88       88           
`Y8a8a8a,    `Y8aaaaa,    88 `8b     d8' 88      d8'  `8b      88       88aaaaa      
  `"8"8"8b,    `"""""8b,  88  `8b   d8'  88     d8YaaaaY8b     88       88"""""      
    8 8 `8b          `8b  88   `8b d8'   88    d8""""""""8b    88       88           
Y8a 8 8 a8P  Y8a     a8P  88    `888'    88   d8'        `8b   88       88           
 "Y88888P"    "Y88888P"   88     `8'     88  d8'          `8b  88       88888888888  
    8 8                                                                                                                                                      

 * @title Staking Mate contract for Roll A Mate Protocol 
 * @author jistro.eth ariutokintumi.eth
 */

import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {SignatureRecover} from "@EVVM/playground/lib/SignatureRecover.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {ErrorsLib} from "./lib/ErrorsLib.sol";
import {SignatureUtils} from "@EVVM/playground/contracts/staking/lib/SignatureUtils.sol";

contract Staking {
    using SignatureRecover for *;

    struct presaleStakerMetadata {
        bool isAllow;
        uint256 stakingAmount;
    }

    /**
     * @dev Struct to store the history of the user
     * @param transactionType if the transaction is staking or unstaking
     *          - 0x01 for staking
     *          - 0x02 for unstaking
     *
     * @param amount amount of sMATE staked/unstaked
     * @param timestamp timestamp of the transaction
     * @param totalStaked total amount of sMATE staked
     */
    struct HistoryMetadata {
        bytes32 transactionType;
        uint256 amount;
        uint256 timestamp;
        uint256 totalStaked;
    }

    struct AddressTypeProposal {
        address actual;
        address proposal;
        uint256 timeToAccept;
    }

    struct UintTypeProposal {
        uint256 actual;
        uint256 proposal;
        uint256 timeToAccept;
    }

    struct BoolTypeProposal {
        bool flag;
        uint256 timeToAccept;
    }

    address private EVVM_ADDRESS;

    uint256 private constant LIMIT_PRESALE_STAKER = 800;
    uint256 private presaleStakerCount;
    uint256 private constant PRICE_OF_STAKING = 5083 * (10 ** 18);

    AddressTypeProposal private admin;
    AddressTypeProposal private goldenFisher;
    AddressTypeProposal private estimator;
    UintTypeProposal private secondsToUnlockStaking;
    UintTypeProposal private secondsToUnllockFullUnstaking;
    BoolTypeProposal private allowPresaleStaking;
    BoolTypeProposal private allowPublicStaking;

    address private constant PRINCIPAL_TOKEN_ADDRESS =
        0x0000000000000000000000000000000000000001;

    bytes1 private breakerSetupEstimatorAndEvvm;

    mapping(address => mapping(uint256 => bool)) private stakingNonce;

    mapping(address => presaleStakerMetadata) private userPresaleStaker;

    mapping(address => HistoryMetadata[]) private userHistory;

    modifier onlyOwner() {
        if (msg.sender != admin.actual) revert ErrorsLib.SenderIsNotAdmin();

        _;
    }

    constructor(address initialAdmin, address initialGoldenFisher) {
        admin.actual = initialAdmin;

        goldenFisher.actual = initialGoldenFisher;

        allowPublicStaking.flag = false;
        allowPresaleStaking.flag = false;

        secondsToUnlockStaking.actual = 0;

        secondsToUnllockFullUnstaking.actual = 21 days;

        breakerSetupEstimatorAndEvvm = 0x01;
    }

    function _setupEstimatorAndEvvm(
        address _estimator,
        address _evvm
    ) external {
        if (breakerSetupEstimatorAndEvvm == 0x00) revert();

        estimator.actual = _estimator;
        EVVM_ADDRESS = _evvm;
        breakerSetupEstimatorAndEvvm = 0x00;
    }

    /**
     *  @dev goldenStaking allows the goldenFisher address to make a stakingProcess.
     *  @param isStaking boolean to check if the user is staking or unstaking
     *  @param amountOfStaking amount of sMATE to stake/unstake
     *  @param signature_EVVM signature for the Evvm contract
     *
     * @notice only the goldenFisher address can call this function and only
     *         can use sync evvm nonces
     */
    function goldenStaking(
        bool isStaking,
        uint256 amountOfStaking,
        bytes memory signature_EVVM
    ) external {
        if (msg.sender != goldenFisher.actual)
            revert ErrorsLib.SenderIsNotGoldenFisher();

        stakingUserProcess(
            goldenFisher.actual,
            amountOfStaking,
            isStaking,
            0,
            Evvm(EVVM_ADDRESS).getNextCurrentSyncNonce(msg.sender),
            false,
            signature_EVVM
        );
    }

    /*
        presaleStaking accede a un mapping que se cargará al 
        inicializar el contrato y se puede alimentar de 
        entradas únicamente por el contract owner, con un 
        máximo de 800 entradas hardcodeado por código (el 800), 
        revisa presaleClaims y si procede llama a presaleInternalExecution.
     */

    /**
     *  @dev presaleStaking allows the presale users to make a stakingProcess.
     *  @param user user address of the user that wants to stake/unstake
     *  @param isStaking boolean to check if the user is staking or unstaking
     *  @param nonce nonce for the Staking contract
     *  @param signature signature for the Staking contract
     *  @param priorityFee_EVVM priority fee for the Evvm contract
     *  @param nonce_EVVM nonce for the Evvm contract // staking or unstaking
     *  @param priorityFlag_EVVM priority for the Evvm contract (true for async, false for sync)
     *  @param signature_EVVM signature for the Evvm contract // staking or unstaking
     *
     *  @notice the presale users can only take 2 Staking tokens, and only one at a time
     */
    function presaleStaking(
        address user,
        bool isStaking,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) external {
        if (
            !SignatureUtils.verifyMessageSignedForStake(
                user,
                false,
                isStaking,
                1,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnStaking();

        if (checkIfStakeNonceUsed(user, nonce))
            revert ErrorsLib.StakingNonceAlreadyUsed();

        presaleClaims(isStaking, user);

        if (!allowPresaleStaking.flag)
            revert ErrorsLib.PresaleStakingDisabled();

        stakingUserProcess(
            user,
            1,
            isStaking,
            priorityFee_EVVM,
            nonce_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        stakingNonce[user][nonce] = true;
    }

    /*
        presaleClaims administra el mapping (o datos del tipo que sea) 
        donde se determina que un address incluida en el presaleStaking 
        solo puede hacer 2 stakings de 5083 MATE, o sea obtener 2 sMATE, 
        si hace staking suma 1 (siempre que tenga slots) y si hace 
        unstaking resta 1. Esta función dejará de usarse cuando 
        publicStaking pase a ser (1), o sea cuando el protocolo 
        quede abierto.
     */

    /**
     *  @dev presaleClaims manages the presaleStaker mapping, only the presale users can make a stakingProcess.
     *  @param _isStaking boolean to check if the user is staking or unstaking
     *  @param _user user address of the user that wants to stake/unstake
     */
    function presaleClaims(bool _isStaking, address _user) internal {
        if (allowPublicStaking.flag) {
            revert ErrorsLib.PresaleStakingDisabled();
        } else {
            if (userPresaleStaker[_user].isAllow) {
                if (_isStaking) {
                    // staking

                    if (userPresaleStaker[_user].stakingAmount >= 2)
                        revert ErrorsLib.UserPresaleStakerLimitExceeded();

                    userPresaleStaker[_user].stakingAmount++;
                } else {
                    // unstaking

                    if (userPresaleStaker[_user].stakingAmount == 0)
                        revert ErrorsLib.UserPresaleStakerLimitExceeded();

                    userPresaleStaker[_user].stakingAmount--;
                }
            } else {
                revert ErrorsLib.UserIsNotPresaleStaker();
            }
        }
    }

    /**
     *  @dev publicStaking allows the users to make a stakingProcess.
     *  @param user user address of the user that wants to stake/unstake
     *  @param isStaking boolean to check if the user is staking or unstaking
     *  @param amountOfStaking amount of sMATE to stake/unstake
     *  @param nonce nonce for the Staking contract
     *  @param signature signature for the Staking contract
     *  @param priorityFee_EVVM priority fee for the Evvm contract // staking or unstaking
     *  @param nonce_EVVM nonce for the Evvm contract // staking or unstaking
     *  @param priorityFlag_EVVM priority for the Evvm contract (true for async, false for sync) // staking or unstaking
     *  @param signature_EVVM signature for the Evvm contract // staking or unstaking
     */

    function publicStaking(
        address user,
        bool isStaking,
        uint256 amountOfStaking,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) external {
        if (!allowPublicStaking.flag) {
            revert();
        }

        if (
            !SignatureUtils.verifyMessageSignedForStake(
                user,
                true,
                isStaking,
                amountOfStaking,
                nonce,
                signature
            )
        ) revert ErrorsLib.InvalidSignatureOnStaking();

        if (checkIfStakeNonceUsed(user, nonce))
            revert ErrorsLib.StakingNonceAlreadyUsed();

        stakingUserProcess(
            user,
            amountOfStaking,
            isStaking,
            priorityFee_EVVM,
            nonce_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );

        stakingNonce[user][nonce] = true;
    }

    function publicServiceStaking(
        address user,
        address service,
        bool isStaking,
        uint256 amountOfStaking,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) external {
        if (!allowPublicStaking.flag) revert ErrorsLib.PublicStakingDisabled();

        uint256 size;

        assembly {
            /// @dev check the size of the opcode of the address
            size := extcodesize(service)
        }

        if (size == 0) revert ErrorsLib.AddressIsNotAService();

        if (isStaking) {
            if (
                !SignatureUtils.verifyMessageSignedForPublicServiceStake(
                    user,
                    service,
                    isStaking,
                    amountOfStaking,
                    nonce,
                    signature
                )
            ) revert ErrorsLib.InvalidSignatureOnStaking();
        } else {
            if (service != user) revert ErrorsLib.UserAndServiceMismatch();
        }

        if (checkIfStakeNonceUsed(user, nonce))
            revert ErrorsLib.StakingNonceAlreadyUsed();

        stakingServiceProcess(
            user,
            service,
            isStaking,
            amountOfStaking,
            isStaking ? priorityFee_EVVM : 0,
            isStaking ? nonce_EVVM : 0,
            isStaking ? priorityFlag_EVVM : false,
            isStaking ? signature_EVVM : bytes("")
        );

        stakingNonce[user][nonce] = true;
    }

    function stakingServiceProcess(
        address user,
        address service,
        bool isStaking,
        uint256 amountOfStaking,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) internal {
        stakingBaseProcess(
            user,
            service,
            isStaking,
            amountOfStaking,
            priorityFee_EVVM,
            nonce_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );
    }

    /**
     *  @dev stakingUserProcess allows the contract to make a stakingProcess.
     *  @param user user address of the user that wants to stake/unstake
     *  @param amountOfStaking amount of sMATE to stake/unstake
     *  @param isStaking boolean to check if the user is staking or unstaking
     *  @param priorityFee_EVVM priority fee for the Evvm contract
     *  @param nonce_EVVM nonce for the Evvm contract
     *  @param priorityFlag_EVVM priority for the Evvm contract (true for async, false for sync)
     *  @param signature_EVVM signature for the Evvm contract
     */

    function stakingUserProcess(
        address user,
        uint256 amountOfStaking,
        bool isStaking,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) internal {
        stakingBaseProcess(
            user,
            user,
            isStaking,
            amountOfStaking,
            priorityFee_EVVM,
            nonce_EVVM,
            priorityFlag_EVVM,
            signature_EVVM
        );
    }

    /**
     * @dev Base function that handles both service and user staking processes
     * @param userAccount address of the user paying for the transaction
     * @param stakingAccount address that will receive the stake/unstake
     * @param isStaking boolean indicating if staking or unstaking
     * @param amountOfStaking amount of sMATE tokens
     * @param priorityFee_EVVM priority fee for EVVM
     * @param nonce_EVVM nonce for EVVM
     * @param priorityFlag_EVVM priority flag for EVVM
     * @param signature_EVVM signature for EVVM
     */
    function stakingBaseProcess(
        address userAccount,
        address stakingAccount,
        bool isStaking,
        uint256 amountOfStaking,
        uint256 priorityFee_EVVM,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        bytes memory signature_EVVM
    ) internal {
        uint256 auxSMsteBalance;

        if (isStaking) {
            if (
                getTimeToUserUnlockStakingTime(stakingAccount) > block.timestamp
            ) revert ErrorsLib.UserMustWaitToStakeAgain();

            makePay(
                userAccount,
                (PRICE_OF_STAKING * amountOfStaking),
                priorityFee_EVVM,
                priorityFlag_EVVM,
                nonce_EVVM,
                signature_EVVM
            );

            Evvm(EVVM_ADDRESS).pointStaker(stakingAccount, 0x01);

            auxSMsteBalance = userHistory[stakingAccount].length == 0
                ? amountOfStaking
                : userHistory[stakingAccount][
                    userHistory[stakingAccount].length - 1
                ].totalStaked + amountOfStaking;
        } else {
            if (amountOfStaking == getUserAmountStaked(stakingAccount)) {
                if (
                    getTimeToUserUnlockFullUnstakingTime(stakingAccount) >
                    block.timestamp
                ) revert ErrorsLib.UserMustWaitToFullUnstake();

                Evvm(EVVM_ADDRESS).pointStaker(stakingAccount, 0x00);
            }

            // Only for user unstaking, not service
            if (userAccount == stakingAccount && priorityFee_EVVM != 0) {
                makePay(
                    userAccount,
                    priorityFee_EVVM,
                    0,
                    priorityFlag_EVVM,
                    nonce_EVVM,
                    signature_EVVM
                );
            }

            auxSMsteBalance =
                userHistory[stakingAccount][
                    userHistory[stakingAccount].length - 1
                ].totalStaked -
                amountOfStaking;

            makeCaPay(
                PRINCIPAL_TOKEN_ADDRESS,
                stakingAccount,
                (PRICE_OF_STAKING * amountOfStaking)
            );
        }

        userHistory[stakingAccount].push(
            HistoryMetadata({
                transactionType: isStaking
                    ? bytes32(uint256(1))
                    : bytes32(uint256(2)),
                amount: amountOfStaking,
                timestamp: block.timestamp,
                totalStaked: auxSMsteBalance
            })
        );

        if (Evvm(EVVM_ADDRESS).isAddressStaker(msg.sender)) {
            makeCaPay(
                PRINCIPAL_TOKEN_ADDRESS,
                msg.sender,
                (Evvm(EVVM_ADDRESS).getRewardAmount() * 2) + priorityFee_EVVM
            );
        }
    }

    function gimmeYiel(
        address user
    )
        external
        returns (
            bytes32 epochAnswer,
            address tokenToBeRewarded,
            uint256 amountTotalToBeRewarded,
            uint256 idToOverwriteUserHistory,
            uint256 timestampToBeOverwritten
        )
    {
        if (userHistory[user].length > 0) {
            (
                epochAnswer,
                tokenToBeRewarded,
                amountTotalToBeRewarded,
                idToOverwriteUserHistory,
                timestampToBeOverwritten
            ) = Estimator(estimator.actual).makeEstimation(user);

            if (amountTotalToBeRewarded > 0) {
                makeCaPay(tokenToBeRewarded, user, amountTotalToBeRewarded);

                userHistory[user][idToOverwriteUserHistory]
                    .transactionType = epochAnswer;
                userHistory[user][idToOverwriteUserHistory]
                    .amount = amountTotalToBeRewarded;
                userHistory[user][idToOverwriteUserHistory]
                    .timestamp = timestampToBeOverwritten;

                if (Evvm(EVVM_ADDRESS).isAddressStaker(msg.sender)) {
                    makeCaPay(
                        PRINCIPAL_TOKEN_ADDRESS,
                        msg.sender,
                        (Evvm(EVVM_ADDRESS).getRewardAmount() * 1)
                    );
                }
            }
        }
    }

    //▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
    // Tools for Evvm
    //▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀

    function makePay(
        address user,
        uint256 amount,
        uint256 priorityFee,
        bool priorityFlag,
        uint256 nonce,
        bytes memory signature
    ) internal {
        if (priorityFlag) {
            Evvm(EVVM_ADDRESS).payMateStaking_async(
                user,
                address(this),
                "",
                PRINCIPAL_TOKEN_ADDRESS,
                amount,
                priorityFee,
                nonce,
                address(this),
                signature
            );
        } else {
            Evvm(EVVM_ADDRESS).payMateStaking_sync(
                user,
                address(this),
                "",
                PRINCIPAL_TOKEN_ADDRESS,
                amount,
                priorityFee,
                address(this),
                signature
            );
        }
    }

    function makeCaPay(
        address tokenAddress,
        address user,
        uint256 amount
    ) internal {
        Evvm(EVVM_ADDRESS).caPay(user, tokenAddress, amount);
    }

    //▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
    // Admin Functions
    //▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀

    function addPresaleStaker(address _staker) external onlyOwner {
        if (presaleStakerCount > LIMIT_PRESALE_STAKER) {
            revert();
        }
        userPresaleStaker[_staker].isAllow = true;
        presaleStakerCount++;
    }

    function addPresaleStakers(address[] calldata _stakers) external onlyOwner {
        for (uint256 i = 0; i < _stakers.length; i++) {
            if (presaleStakerCount > LIMIT_PRESALE_STAKER) {
                revert();
            }
            userPresaleStaker[_stakers[i]].isAllow = true;
            presaleStakerCount++;
        }
    }

    function proposeAdmin(address _newAdmin) external onlyOwner {
        admin.proposal = _newAdmin;
        admin.timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposalAdmin() external onlyOwner {
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    function acceptNewAdmin() external {
        if (
            msg.sender != admin.proposal || admin.timeToAccept > block.timestamp
        ) {
            revert();
        }
        admin.actual = admin.proposal;
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    function proposeGoldenFisher(address _goldenFisher) external onlyOwner {
        goldenFisher.proposal = _goldenFisher;
        goldenFisher.timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposalGoldenFisher() external onlyOwner {
        goldenFisher.proposal = address(0);
        goldenFisher.timeToAccept = 0;
    }

    function acceptNewGoldenFisher() external onlyOwner {
        if (goldenFisher.timeToAccept > block.timestamp) {
            revert();
        }
        goldenFisher.actual = goldenFisher.proposal;
        goldenFisher.proposal = address(0);
        goldenFisher.timeToAccept = 0;
    }

    function proposeSetSecondsToUnlockStaking(
        uint256 _secondsToUnlockStaking
    ) external onlyOwner {
        secondsToUnlockStaking.proposal = _secondsToUnlockStaking;
        secondsToUnlockStaking.timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposalSetSecondsToUnlockStaking() external onlyOwner {
        secondsToUnlockStaking.proposal = 0;
        secondsToUnlockStaking.timeToAccept = 0;
    }

    function acceptSetSecondsToUnlockStaking() external onlyOwner {
        if (secondsToUnlockStaking.timeToAccept > block.timestamp) {
            revert();
        }
        secondsToUnlockStaking.actual = secondsToUnlockStaking.proposal;
        secondsToUnlockStaking.proposal = 0;
        secondsToUnlockStaking.timeToAccept = 0;
    }

    function prepareSetSecondsToUnllockFullUnstaking(
        uint256 _secondsToUnllockFullUnstaking
    ) external onlyOwner {
        secondsToUnllockFullUnstaking.proposal = _secondsToUnllockFullUnstaking;
        secondsToUnllockFullUnstaking.timeToAccept = block.timestamp + 1 days;
    }

    function cancelSetSecondsToUnllockFullUnstaking() external onlyOwner {
        secondsToUnllockFullUnstaking.proposal = 0;
        secondsToUnllockFullUnstaking.timeToAccept = 0;
    }

    function confirmSetSecondsToUnllockFullUnstaking() external onlyOwner {
        if (secondsToUnllockFullUnstaking.timeToAccept > block.timestamp) {
            revert();
        }
        secondsToUnllockFullUnstaking.actual = secondsToUnllockFullUnstaking
            .proposal;
        secondsToUnllockFullUnstaking.proposal = 0;
        secondsToUnllockFullUnstaking.timeToAccept = 0;
    }

    function prepareChangeAllowPublicStaking() external onlyOwner {
        allowPublicStaking.timeToAccept = block.timestamp + 1 days;
    }

    function cancelChangeAllowPublicStaking() external onlyOwner {
        allowPublicStaking.timeToAccept = 0;
    }

    function confirmChangeAllowPublicStaking() external onlyOwner {
        if (allowPublicStaking.timeToAccept > block.timestamp) {
            revert();
        }
        allowPublicStaking = BoolTypeProposal({
            flag: !allowPublicStaking.flag,
            timeToAccept: 0
        });
    }

    function prepareChangeAllowPresaleStaking() external onlyOwner {
        allowPresaleStaking.timeToAccept = block.timestamp + 1 days;
    }

    function cancelChangeAllowPresaleStaking() external onlyOwner {
        allowPresaleStaking.timeToAccept = 0;
    }

    function confirmChangeAllowPresaleStaking() external onlyOwner {
        if (allowPresaleStaking.timeToAccept > block.timestamp) {
            revert();
        }
        allowPresaleStaking = BoolTypeProposal({
            flag: !allowPresaleStaking.flag,
            timeToAccept: 0
        });
    }

    function proposeEstimator(address _estimator) external onlyOwner {
        estimator.proposal = _estimator;
        estimator.timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposalEstimator() external onlyOwner {
        estimator.proposal = address(0);
        estimator.timeToAccept = 0;
    }

    function acceptNewEstimator() external onlyOwner {
        if (estimator.timeToAccept > block.timestamp) {
            revert();
        }
        estimator.actual = estimator.proposal;
        estimator.proposal = address(0);
        estimator.timeToAccept = 0;
    }

    //▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
    // Getter Functions
    //▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀

    function getAddressHistory(
        address _account
    ) public view returns (HistoryMetadata[] memory) {
        return userHistory[_account];
    }

    function getSizeOfAddressHistory(
        address _account
    ) public view returns (uint256) {
        return userHistory[_account].length;
    }

    function getAddressHistoryByIndex(
        address _account,
        uint256 _index
    ) public view returns (HistoryMetadata memory) {
        return userHistory[_account][_index];
    }

    function priceOfStaking() external pure returns (uint256) {
        return PRICE_OF_STAKING;
    }

    function getTimeToUserUnlockFullUnstakingTime(
        address _account
    ) public view returns (uint256) {
        for (uint256 i = userHistory[_account].length; i > 0; i--) {
            if (userHistory[_account][i - 1].totalStaked == 0) {
                return
                    userHistory[_account][i - 1].timestamp +
                    secondsToUnllockFullUnstaking.actual;
            }
        }

        return
            userHistory[_account][0].timestamp +
            secondsToUnllockFullUnstaking.actual;
    }

    function getTimeToUserUnlockStakingTime(
        address _account
    ) public view returns (uint256) {
        uint256 lengthOfHistory = userHistory[_account].length;

        if (lengthOfHistory == 0) {
            return 0;
        }
        if (userHistory[_account][lengthOfHistory - 1].totalStaked == 0) {
            return
                userHistory[_account][lengthOfHistory - 1].timestamp +
                secondsToUnlockStaking.actual;
        } else {
            return 0;
        }
    }

    function getSecondsToUnlockFullUnstaking() external view returns (uint256) {
        return secondsToUnllockFullUnstaking.actual;
    }

    function getSecondsToUnlockStaking() external view returns (uint256) {
        return secondsToUnlockStaking.actual;
    }

    function getUserAmountStaked(
        address _account
    ) public view returns (uint256) {
        uint256 lengthOfHistory = userHistory[_account].length;

        if (lengthOfHistory == 0) {
            return 0;
        }

        return userHistory[_account][lengthOfHistory - 1].totalStaked;
    }

    function checkIfStakeNonceUsed(
        address _account,
        uint256 _nonce
    ) public view returns (bool) {
        return stakingNonce[_account][_nonce];
    }

    function getGoldenFisher() external view returns (address) {
        return goldenFisher.actual;
    }

    function getGoldenFisherProposal() external view returns (address) {
        return goldenFisher.proposal;
    }

    function getPresaleStaker(
        address _account
    ) external view returns (bool, uint256) {
        return (
            userPresaleStaker[_account].isAllow,
            userPresaleStaker[_account].stakingAmount
        );
    }

    function getEstimatorAddress() external view returns (address) {
        return estimator.actual;
    }

    function getEstimatorProposal() external view returns (address) {
        return estimator.proposal;
    }

    function getPresaleStakerCount() external view returns (uint256) {
        return presaleStakerCount;
    }

    function getAllDataOfAllowPublicStaking()
        external
        view
        returns (BoolTypeProposal memory)
    {
        return allowPublicStaking;
    }

    function getAllowPresaleStaking()
        external
        view
        returns (BoolTypeProposal memory)
    {
        return allowPresaleStaking;
    }

    function getEvvmAddress() external view returns (address) {
        return EVVM_ADDRESS;
    }

    function getMateAddress() external pure returns (address) {
        return PRINCIPAL_TOKEN_ADDRESS;
    }

    function getOwner() external view returns (address) {
        return admin.actual;
    }
}
