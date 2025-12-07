// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {
    NameService
} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";
import {P2PSwap} from "@EVVM/playground/contracts/p2pSwap/P2PSwap.sol";
import {Inputs} from "../input/Inputs.sol";

contract DeployScript is Script, Inputs {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;
    P2PSwap p2pSwap;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        staking = new Staking(admin, goldenFisher);
        evvm = new Evvm(admin, address(staking), inputMetadata);
        estimator = new Estimator(
            activator,
            address(evvm),
            address(staking),
            admin
        );

        nameService = new NameService(address(evvm), admin);

        staking._setupEstimatorAndEvvm(address(estimator), address(evvm));
        treasury = new Treasury(address(evvm));
        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasury)
        );
        p2pSwap = new P2PSwap(
            address(evvm),
            address(staking),
            admin
        );

        vm.stopBroadcast();

        console2.log("Staking deployed at:", address(staking));
        console2.log("Evvm deployed at:", address(evvm));
        console2.log("Estimator deployed at:", address(estimator));
        console2.log("NameService deployed at:", address(nameService));
        console2.log("Treasury deployed at:", address(treasury));
        console2.log("P2PSwap deployed at:", address(p2pSwap));
    }
}
