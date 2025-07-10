// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";
import {EstimatorMock} from "@EVVM/playground/core/staking/EstimatorMock.sol";
import {MateNameServiceMock} from "@EVVM/playground/mateNameService/MateNameServiceMock.sol";

contract DeployScript is Script {
    SMateMock sMate;
    EvvmMock evvm;
    EstimatorMock estimator;
    MateNameServiceMock mateNameService;
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address goldenFisher = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address activator = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        sMate = new SMateMock(admin, goldenFisher);
        evvm = new EvvmMock(admin, address(sMate));
        estimator = new EstimatorMock(
            activator,
            address(evvm),
            address(sMate),
            admin
        );
        mateNameService = new MateNameServiceMock(address(evvm), admin);

        sMate._setupEstimatorAndEvvm(address(estimator), address(evvm));
        evvm._setupMateNameServiceAddress(address(mateNameService));

        vm.stopBroadcast();

        console2.log("SMate deployed at:", address(sMate));
        console2.log("Evvm deployed at:", address(evvm));
        console2.log("Estimator deployed at:", address(estimator));
    }
}
