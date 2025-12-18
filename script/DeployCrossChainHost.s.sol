// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Evvm} from "@evvm/playground-contracts/contracts/evvm/Evvm.sol";
import {
    Staking
} from "@evvm/playground-contracts/contracts/staking/Staking.sol";
import {
    Estimator
} from "@evvm/playground-contracts/contracts/staking/Estimator.sol";
import {
    NameService
} from "@evvm/playground-contracts/contracts/nameService/NameService.sol";
import {
    EvvmStructs
} from "@evvm/playground-contracts/contracts/evvm/lib/EvvmStructs.sol";
import {
    TreasuryHostChainStation
} from "@evvm/playground-contracts/contracts/treasuryTwoChains/TreasuryHostChainStation.sol";
import {
    HostChainStationStructs
} from "@evvm/playground-contracts/contracts/treasuryTwoChains/lib/HostChainStationStructs.sol";
import {
    ExternalChainStationStructs
} from "@evvm/playground-contracts/contracts/treasuryTwoChains/lib/ExternalChainStationStructs.sol";
import {
    P2PSwap
} from "@evvm/playground-contracts/contracts/p2pSwap/P2PSwap.sol";
import {BaseInputs} from "../input/BaseInputs.sol";
import {CrossChainInputs} from "../input/CrossChainInputs.sol";

contract DeployTestnetCrossChain is Script, BaseInputs, CrossChainInputs {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    TreasuryHostChainStation treasuryHost;
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

        treasuryHost = new TreasuryHostChainStation(
            address(evvm),
            admin,
            crosschainConfigHost
        );

        
        evvm._setupNameServiceAndTreasuryAddress(
            address(nameService),
            address(treasuryHost)
        );

        p2pSwap = new P2PSwap(
            address(evvm),
            address(staking),
            admin
        );

        vm.stopBroadcast();
    }
}
