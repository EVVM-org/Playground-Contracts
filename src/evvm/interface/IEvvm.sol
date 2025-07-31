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


import {IEvvmStructs} from "@EVVM/playground/evvm/interface/IEvvmStructs.sol";


interface IEvvm is IEvvmStructs {

    function _setupNameServiceAddress(address _nameServiceAddress) external;

    fallback() external;

    function _addBalance(address user, address token, uint256 quantity) external;

    function _setPointStaker(address user, bytes1 answer) external;

    function _addMateToTotalSupply(uint256 amount) external;

    function withdrawalSync(
        address user,
        address addressToReceive,
        address token,
        uint256 amount,
        uint256 priorityFee,
        bytes memory signature,
        uint8 _solutionId,
        bytes calldata _options
    ) external payable;

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
    ) external payable;

    function payNoMateStaking_sync(
        address from,
        address to_address,
        string memory to_identity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        address executor,
        bytes memory signature
    ) external;

    function payNoMateStaking_async(
        address from,
        address to_address,
        string memory to_identity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        address executor,
        bytes memory signature
    ) external;

    function payMateStaking_sync(
        address from,
        address to_address,
        string memory to_identity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        address executor,
        bytes memory signature
    ) external;

    function payMateStaking_async(
        address from,
        address to_address,
        string memory to_identity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        address executor,
        bytes memory signature
    ) external;

    function payMultiple(PayData[] memory payData) external returns (
        uint256 successfulTransactions,
        uint256 failedTransactions,
        bool[] memory results
    );

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
    ) external;

    function caPay(address to, address token, uint256 amount) external;

    function disperseCaPay(
        DisperseCaPayMetadata[] memory toData,
        address token,
        uint256 amount
    ) external;

    function fisherWithdrawal(
        address user,
        address addressToReceive,
        address token,
        uint256 priorityFee,
        uint256 amount,
        bytes memory signature
    ) external;
}
