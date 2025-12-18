// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {EvvmStructs} from "@evvm/playground-contracts/contracts/evvm/lib/EvvmStructs.sol";
import {HostChainStationStructs} from "@evvm/playground-contracts/contracts/treasuryTwoChains/lib/HostChainStationStructs.sol";
import {ExternalChainStationStructs} from "@evvm/playground-contracts/contracts/treasuryTwoChains/lib/ExternalChainStationStructs.sol";

abstract contract CrossChainInputs {
    address constant ADMIN_EXTERNAL = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    HostChainStationStructs.CrosschainConfig crosschainConfigHost =
        HostChainStationStructs.CrosschainConfig({
            externalChainStationDomainId: 421614, //Domain ID for Arb Sepolia on Hyperlane
            mailboxAddress: 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766, //Mailbox for Host (ETH Sepolia) on Hyperlane
            externalChainStationEid: 40231, //EID for Arb Sepolia on LayerZero
            endpointAddress: 0x6EDCE65403992e310A62460808c4b910D972f10f, //Endpoint for Host (ETH Sepolia) on LayerZero
            externalChainStationChainName: "arbitrum-sepolia", //Chain Name for Arb Sepolia on Axelar
            gasServiceAddress: 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6, //Gas Service for Host (ETH Sepolia) on Axelar
            gatewayAddress: 0xe432150cce91c13a887f7D836923d5597adD8E31 //Gateway for Host (ETH Sepolia) on Axelar
        });

    ExternalChainStationStructs.CrosschainConfig crosschainConfigExternal =
        ExternalChainStationStructs.CrosschainConfig({
            hostChainStationDomainId: 11155111, //Domain ID for ETH Sepolia on Hyperlane
            mailboxAddress: 0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8, //Mailbox for External (ETH Sepolia) on Hyperlane
            hostChainStationEid: 40161, //EID for ETH Sepolia on LayerZero
            endpointAddress: 0x6EDCE65403992e310A62460808c4b910D972f10f, //Endpoint for External (ETH Sepolia) on LayerZero
            hostChainStationChainName: "ethereum-sepolia", //Chain Name for ETH Sepolia on Axelar
            gasServiceAddress: 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6, //Gas Service for External (ETH Sepolia) on Axelar
            gatewayAddress: 0xe1cE95479C84e9809269227C7F8524aE051Ae77a //Gateway for External (ETH Sepolia) on Axelar
        });
}
