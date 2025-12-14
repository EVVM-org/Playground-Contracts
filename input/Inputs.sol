// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {EvvmStructs} from "@evvm/playground-contracts/contracts/evvm/lib/EvvmStructs.sol";

abstract contract Inputs {
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address goldenFisher = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address activator = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    EvvmStructs.EvvmMetadata inputMetadata =
        EvvmStructs.EvvmMetadata({
            EvvmName: "EVVM",
            // evvmID will be set to 0, and it will be assigned when you register the evvm
            EvvmID: 0,
            principalTokenName: "Mate Token",
            principalTokenSymbol: "MATE",
            principalTokenAddress: 0x0000000000000000000000000000000000000001,
            totalSupply: 2033333333000000000000000000,
            eraTokens: 1016666666500000000000000000,
            reward: 5000000000000000000
        });
}
