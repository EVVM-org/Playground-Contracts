// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

contract DeployScript is Script {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;

    address admin = 0x5cBf2D4Bbf834912Ad0bD59980355b57695e8309;
    address goldenFisher = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address activator = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        staking = new Staking(admin, goldenFisher);
        evvm = new Evvm(
            admin,
            address(staking),
            EvvmStructs.EvvmMetadata({
                EvvmName: "EVVM",
                EvvmID: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                principalTokenName: "EVVM Staking Token",
                principalTokenSymbol: "EVVM-STK",
                principalTokenAddress: 0x0000000000000000000000000000000000000001,
                totalSupply: 2033333333000000000000000000,
                eraTokens: 2033333333000000000000000000 / 2,
                reward: 5000000000000000000
            })
        );
        estimator = new Estimator(
            activator,
            address(evvm),
            address(staking),
            admin
        );
        nameService = new NameService(address(evvm), admin);

        staking._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupNameServiceAddress(address(nameService));

        vm.stopBroadcast();

        console2.log("Staking deployed at:", address(staking));
        console2.log("Evvm deployed at:", address(evvm));
        console2.log("Estimator deployed at:", address(estimator));
    }
}
