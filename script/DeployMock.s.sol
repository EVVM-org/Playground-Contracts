// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {EvvmTesnet} from "Tesnet-contracts/EvvmTesnet.sol";
import {SMateTesnet} from "Tesnet-contracts/SMateTesnet.sol";

contract DeployTestnet is Script {
    SMateTesnet sMate;

    function run() public {
        vm.broadcast();
        deployEvvm();
    }

    function deployEvvm() public returns (address sMateAddress) {
        sMate = new SMateTesnet(msg.sender);
        console2.log("sMate address: ", address(sMate));
        console2.log("Evvm address: ", sMate.getEvvmAddress());
        console2.log(
            "MNS address: ",
            EvvmTesnet(sMate.getEvvmAddress()).getMateNameServiceAddress()
        );
        return address(sMate);
    }
}
