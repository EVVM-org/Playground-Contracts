// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;
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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";

contract Treasury {
    address public evvmAddress;

    constructor(address _evvmAddress) {
        evvmAddress = _evvmAddress;
    }

    function depositNativeHostToken() external payable {
        Evvm(evvmAddress).addAmountToUser(msg.sender, address(0), msg.value);
    }

    function depositERC20HostToken(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        Evvm(evvmAddress).addAmountToUser(msg.sender, token, amount);
    }

    function withdrawNativeHostToken(uint256 amount) external {
        Evvm(evvmAddress).removeAmountFromUser(msg.sender, address(0), amount);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function withdrawERC20HostToken(address token, uint256 amount) external {
        Evvm(evvmAddress).removeAmountFromUser(msg.sender, token, amount);
        IERC20(token).transfer(msg.sender, amount);
    }

}
