// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {EvvmMock} from "@EVVM/playground/core/EvvmMock.sol";
import {SMateMock} from "@EVVM/playground/core/staking/SMateMock.sol";

contract DeployScript is Script {
    SMateMock sMate;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        sMate = new SMateMock(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.stopBroadcast();
        console.log("sMate address: ", address(sMate));
        console.log("Evvm address: ", sMate.getEvvmAddress());
        console.log(
            "MNS address: ",
            EvvmMock(sMate.getEvvmAddress()).getMateNameServiceAddress()
        );
    }
}
