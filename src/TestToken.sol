// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense

// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;
/*  
888b     d888                   888            .d8888b.                    888                             888    
8888b   d8888                   888           d88P  Y88b                   888                             888    
88888b.d88888                   888           888    888                   888                             888    
888Y88888P888  .d88b.   .d8888b 888  888      888         .d88b.  88888b.  888888 888d888 8888b.   .d8888b 888888 
888 Y888P 888 d88""88b d88P"    888 .88P      888        d88""88b 888 "88b 888    888P"      "88b d88P"    888    
888  Y8P  888 888  888 888      888888K       888    888 888  888 888  888 888    888    .d888888 888      888    
888   "   888 Y88..88P Y88b.    888 "88b      Y88b  d88P Y88..88P 888  888 Y88b.  888    888  888 Y88b.    Y88b.  
888       888  "Y88P"   "Y8888P 888  888       "Y8888P"   "Y88P"  888  888  "Y888 888    "Y888888  "Y8888P  "Y888                                                                                                          
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    constructor(
        address initialOwner
    ) ERC20("TestToken", "TEST") Ownable(initialOwner) {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
