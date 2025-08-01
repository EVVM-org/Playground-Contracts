// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;

library ErrorsLib {
    error SenderIsNotAdmin();
    error SenderIsNotGoldenFisher();
    error InvalidSignatureOnStaking();
    error StakingNonceAlreadyUsed();
    error PresaleStakingDisabled();
    error UserPresaleStakerLimitExceeded();
    error UserIsNotPresaleStaker();
    error PublicStakingDisabled();
    error AddressIsNotAService();
    error UserAndServiceMismatch();
    error UserMustWaitToStakeAgain();
    error UserMustWaitToFullUnstake();
}
