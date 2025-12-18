// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {TreasuryExternalChainStation} from "@evvm/playground-contracts/contracts/treasuryTwoChains/TreasuryExternalChainStation.sol";
import {CrossChainInputs} from "../input/CrossChainInputs.sol";

contract DeployTestnetCrossChainExternal is Script, CrossChainInputs {
    TreasuryExternalChainStation treasuryExternal;
    function setUp() public {}

    function run() public {

            vm.startBroadcast();

            treasuryExternal = new TreasuryExternalChainStation(
                ADMIN_EXTERNAL,
                crosschainConfigExternal,
                0
            );

            vm.stopBroadcast();

    }
}
