// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {EvvmMock} from "mock-contracts/EvvmMock.sol";
import {SMateMock} from "mock-contracts/SMateMock.sol";

contract DeployMock is Script {
    SMateMock sMate;

    function run() public {
        vm.broadcast();
        deployEvvm();
    }

    function deployEvvm() public returns (address sMateAddress) {
        sMate = new SMateMock(msg.sender);
        console2.log("sMate address: ", address(sMate));
        console2.log("Evvm address: ", sMate.getEvvmAddress());
        console2.log(
            "MNS address: ",
            EvvmMock(sMate.getEvvmAddress()).getMateNameServiceAddress()
        );
        return address(sMate);
    }
}
