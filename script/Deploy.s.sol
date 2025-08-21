// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {Estimator} from "@EVVM/playground/contracts/staking/Estimator.sol";
import {NameService} from "@EVVM/playground/contracts/nameService/NameService.sol";
import {Treasury} from "@EVVM/playground/contracts/treasury/Treasury.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

contract DeployScript is Script {
    Staking staking;
    Evvm evvm;
    Estimator estimator;
    NameService nameService;
    Treasury treasury;

    address admin = 0x5cBf2D4Bbf834912Ad0bD59980355b57695e8309;
    address goldenFisher = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address activator = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;

    struct AddressData {
        address activator;
        address admin;
        address goldenFisher;
    }

    struct BasicMetadata {
        uint256 EvvmID;
        string EvvmName;
        string principalTokenName;
        string principalTokenSymbol;
    }

    struct AdvancedMetadata {
        uint256 eraTokens;
        uint256 reward;
        uint256 totalSupply;
    }

    function setUp() public {}

    function run() public {
        string memory path = "input/address.json";
        assert(vm.isFile(path));
        string memory data = vm.readFile(path);
        bytes memory dataJson = vm.parseJson(data);

        AddressData memory addressData = abi.decode(dataJson, (AddressData));

        path = "input/evvmBasicMetadata.json";
        data = vm.readFile(path);
        //console2.log("Deploy without parsing:", data);
        dataJson = vm.parseJson(data);
        //console2.logBytes(dataJson);

        BasicMetadata memory basicMetadata = abi.decode(
            dataJson,
            (BasicMetadata)
        );

        path = "input/evvmAdvancedMetadata.json";
        data = vm.readFile(path);
        console2.log("Deploy without parsing:", data);
        dataJson = vm.parseJson(data);
        console2.logBytes(dataJson);

        AdvancedMetadata memory advancedMetadata = abi.decode(
            dataJson,
            (AdvancedMetadata)
        );

        console2.log("Admin:", addressData.admin);
        console2.log("GoldenFisher:", addressData.goldenFisher);
        console2.log("Activator:", addressData.activator);
        console2.log("EvvmName:", basicMetadata.EvvmName);
        console2.log("EvvmID:", basicMetadata.EvvmID);
        console2.log("PrincipalTokenName:", basicMetadata.principalTokenName);
        console2.log(
            "PrincipalTokenSymbol:",
            basicMetadata.principalTokenSymbol
        );
        console2.log("TotalSupply:", advancedMetadata.totalSupply);
        console2.log("EraTokens:", advancedMetadata.eraTokens);
        console2.log("Reward:", advancedMetadata.reward);

        EvvmStructs.EvvmMetadata memory inputMetadata = EvvmStructs
            .EvvmMetadata({
                EvvmName: basicMetadata.EvvmName,
                EvvmID: basicMetadata.EvvmID,
                principalTokenName: basicMetadata.principalTokenName,
                principalTokenSymbol: basicMetadata.principalTokenSymbol,
                principalTokenAddress: 0x0000000000000000000000000000000000000001,
                totalSupply: advancedMetadata.totalSupply,
                eraTokens: advancedMetadata.eraTokens,
                reward: advancedMetadata.reward
            });

        vm.startBroadcast();

        staking = new Staking(addressData.admin, addressData.goldenFisher);
        evvm = new Evvm(addressData.admin, address(staking), inputMetadata);
        estimator = new Estimator(
            addressData.activator,
            address(evvm),
            address(staking),
            addressData.admin
        );
        
        nameService = new NameService(address(evvm), addressData.admin);

        staking._setupEstimatorAndEvvm(address(estimator), address(evvm));
        treasury = new Treasury(address(evvm));
        evvm._setupNameServiceAndTreasuryAddress(address(nameService), address(treasury));

        vm.stopBroadcast();

        console2.log("Staking deployed at:", address(staking));
        console2.log("Evvm deployed at:", address(evvm));
        console2.log("Estimator deployed at:", address(estimator));
    }
}
