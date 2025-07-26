// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {Staking} from "@EVVM/playground/staking/Staking.sol";
import {Estimator} from "@EVVM/playground/staking/Estimator.sol";
import {NameService} from "@EVVM/playground/nameService/NameService.sol";

contract DeployScript is Script {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address goldenFisher = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address activator = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        staking = new Staking(admin, goldenFisher);
        evvm = new Evvm(admin, address(staking));
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
