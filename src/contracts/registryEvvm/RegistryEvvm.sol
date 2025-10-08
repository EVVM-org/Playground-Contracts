// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;

contract RegistryEvvm {
    /*
    Hacer un contrato mock que guarda un mapping de ID->BlockHash (en el que se pide escribirlo) y luego un view para ver el blockhash de un ID determinado.
     */
    mapping (uint256 evvmID => bytes hashIdentifier) public evvmIDToHashIdentifier;
}