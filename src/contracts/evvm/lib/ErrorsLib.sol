// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;

library ErrorsLib {
    error InvalidSignature();
    error SenderIsNotTheExecutor();
    error UpdateBalanceFailed();
    error InvalidAsyncNonce();
    error NotAnStaker();
    error InsufficientBalance();
    error InvalidAmount(uint256, uint256);
    error NotAnCA();
    error SenderIsNotTreasury();
}
