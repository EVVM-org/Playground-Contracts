// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;

/**
 * @title TreasuryStructs
 * @dev Library of common structures used across TreasuryTwoChains.
 *      This contract serves as a shared type system for the entire ecosystem,
 *      ensuring consistency in data structures between the core TreasuryTwoChains and
 *      external service contracts.
 *
 * @notice This contract should be inherited by both TreasuryTwoChains contracts
 *         that need to interact with these data structures.
 */

abstract contract TreasuryStructs {
    struct AddressTypeProposal {
        address current;
        address proposal;
        uint256 timeToAccept;
    }

    struct ExternalChainConfig {
        address treasuryAddress;
        HyperlaneConfig hyperlaneConfig;
    }

    struct HyperlaneConfig {
        uint32 domainId;
        bytes32 externalChainStationAddress;
        address mailboxAddress;
    }

    struct LayerZeroConfig {
        uint32 eid;
        bytes32 externalChainStationAddress;
    }
}
