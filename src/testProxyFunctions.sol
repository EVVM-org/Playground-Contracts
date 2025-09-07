// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;


abstract contract Storage {
    uint256 number;
    address owner;
    bool paused;
    mapping(uint256 => uint256) calc;

    // Solo guardamos una implementación a la vez
    address currentImplementation;

    event ImplementationUpdated(address oldImpl, address newImpl);
    event NumberChanged(uint256 newValue);
}

contract Base is Storage {
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    modifier notPaused() {
        if (paused) {
            revert();
        }
        _;
    }

    function add() external notPaused {
        number += 1;
        emit NumberChanged(number);
    }

    function add_Calc(uint256 id) external notPaused {
        calc[id]++;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function getCalc(uint256 id) external view returns (uint256) {
        return calc[id];
    }

    /// Funciones de proxy //////////////////////////////////////

    // Función simplificada para actualizar implementación
    function upgrade(address _newImpl) external onlyOwner {
        if (_newImpl == currentImplementation)
            revert("Es la misma implementacion");
        if (currentImplementation == address(0))
            revert("Implementacion invalida");

        address oldImpl = currentImplementation;
        currentImplementation = _newImpl;

        emit ImplementationUpdated(oldImpl, _newImpl);
    }

    fallback() external {
        if (currentImplementation == address(0))
            revert("Implementacion invalida");


        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(
                gas(),
                sload(currentImplementation.slot),
                0,
                calldatasize(),
                0,
                0
            )

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}




interface ILogic {
    function mul(uint256 x) external;

    function mul_Calc(uint256 id, uint256 x) external;
}

contract LogicV1 is Storage, ILogic {
    modifier notPaused() {
        require(!paused, "El contrato esta pausado");
        _;
    }

    function mul(uint256 x) external override notPaused {
        require(x > 0, "El multiplicador debe ser mayor a 0");
        number = number * x;
        emit NumberChanged(number);
    }

    function mul_Calc(uint256 id, uint256 x) external override notPaused {
        calc[id] = calc[id] * x;
    }
}
