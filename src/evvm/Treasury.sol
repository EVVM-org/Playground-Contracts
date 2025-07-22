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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SignatureRecover} from "@EVVM/libraries/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/libraries/AdvancedStrings.sol";

contract Treasury {
    using SignatureRecover for *;
    using AdvancedStrings for *;

    error FailedToTransfer();
    error InvalidSignature();
    error InvalidToken();
    mapping(address token => address pool) private whitelistTokenUniswapPool;
    MockCrossChainBridge public gatewayMock;
    mapping(address user => uint256 nonce) private nextFisherDepositNonce;

    constructor(address token) {
        whitelistTokenUniswapPool[
            0x5FbDB2315678afecb367f032d93F642f64180aa3
        ] = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
        whitelistTokenUniswapPool[
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        ] = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        whitelistTokenUniswapPool[
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        ] = 0x4e68cC53D6B4f6e3F3c6B6a0e9Cd5d6D3f5B9f3D;
        whitelistTokenUniswapPool[
            0x5FbDB2315678afecb367f032d93F642f64180aa3
        ] = 0x4e68cC53D6B4f6e3F3c6B6a0e9Cd5d6D3f5B9f3D;
        whitelistTokenUniswapPool[
            token
        ] = 0x4e68cC53D6B4f6e3F3c6B6a0e9Cd5d6D3f5B9f3D;
        gatewayMock = new MockCrossChainBridge();
    }

    function seeTokenWhitelist(
        address tokenAddress
    ) public view returns (bool) {
        return whitelistTokenUniswapPool[tokenAddress] != address(0);
    }

    function deposit(
        address userToReceive,
        address token,
        uint256 amount,
        uint8 solutionId,
        bytes calldata options
    ) external payable {
        uint256 gasFeeToPay = msg.value;
        if (token == address(0)) {
            gasFeeToPay = msg.value - amount;
        } else {
            if (whitelistTokenUniswapPool[token] == address(0)) {
                revert();
            }

            /*if (!IERC20(token).transferFrom(msg.sender, address(this), amount)){
                revert();
            }*/
        }

        bytes memory payload = abi.encode(
            userToReceive == address(0) ? msg.sender : userToReceive,
            token,
            amount
        );

        if (solutionId == 1) {
            /// @dev Axelar
            gatewayMock.send{value: gasFeeToPay}(payload, "");
        } else if (solutionId == 2) {
            /// @dev CCIP
            gatewayMock.send{value: gasFeeToPay}(payload, "");
        } else if (solutionId == 3) {
            /// @dev Hyperlane
            gatewayMock.send{value: gasFeeToPay}(payload, "");
        } else if (solutionId == 4) {
            /// @dev LayerZero
            gatewayMock.send{value: gasFeeToPay}(payload, options);
        } else {
            revert();
        }
    }

    function fisherDepositETH(
        address addressToReceive,
        uint256 priorityFee,
        bytes memory signature
    ) public payable {
        if (
            !verifyMessageSignedForFisherBridgeETH(
                msg.sender,
                addressToReceive == address(0) ? msg.sender : addressToReceive,
                nextFisherDepositNonce[msg.sender],
                priorityFee,
                (msg.value - priorityFee),
                signature
            )
        ) {
            revert InvalidSignature();
        }

        if ((msg.value - priorityFee) > 0.1 ether) {
            revert();
        }

        nextFisherDepositNonce[msg.sender]++;
    }

    function fisherDepositERC20(
        address addressToReceive,
        address tokenAddress,
        uint256 amount,
        uint256 priorityFee,
        bytes memory signature
    ) public {
        if (
            !verifyMessageSignedForFisherBridgeERC20(
                msg.sender,
                addressToReceive == address(0) ? msg.sender : addressToReceive,
                nextFisherDepositNonce[msg.sender],
                tokenAddress,
                priorityFee,
                amount,
                signature
            )
        ) {
            revert();
        }

        if (whitelistTokenUniswapPool[tokenAddress] == address(0)) {
            revert();
        }

        if (
            !IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                (amount + priorityFee)
            )
        ) {
            revert();
        }

        nextFisherDepositNonce[msg.sender]++;
    }

    function getNextFisherDepositNonce(
        address user
    ) external view returns (uint256) {
        return nextFisherDepositNonce[user];
    }

    function getTokensWhitelistPool(
        address tokenAddress
    ) external view returns (address) {
        return whitelistTokenUniswapPool[tokenAddress];
    }

    function getIfTokenIsWhitelisted(
        address tokenAddress
    ) external view returns (bool) {
        return whitelistTokenUniswapPool[tokenAddress] != address(0);
    }

    //═Signature functions ════════════════════════════════════════════════════════════════════════

    /**
     *  @notice This function is used to verify the signature of the user who wants to
     *          interact with the fisherBridgeERC20 function
     * @param signer the address of the signer
     *
     * @param addressToReceive address of the account to receive the deposit
     * @param nonce nonce of nextFisherDepositNonce
     * @param tokenAddress token address
     * @param priorityFee priority fee for fishers
     * @param amount amount to deposit
     * @param signature signature of the user
     */
    function verifyMessageSignedForFisherBridgeERC20(
        address signer,
        address addressToReceive,
        uint256 nonce,
        address tokenAddress,
        uint256 priorityFee,
        uint256 amount,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            signer ==
            SignatureRecover.recoverSigner(
                string.concat(
                    AdvancedStrings.addressToString(addressToReceive),
                    ",",
                    Strings.toString(nonce),
                    ",",
                    AdvancedStrings.addressToString(tokenAddress),
                    ",",
                    Strings.toString(priorityFee),
                    ",",
                    Strings.toString(amount)
                ),
                signature
            );
    }

    /**
     *  @notice This function is used to verify the signature of the user who wants to
     *         interact with the fisherBridgeETH function
     * @param signer address of the signer
     * @param addressToReceive address of the account to receive the deposit
     * @param nonce nonce of nextFisherDepositNonce
     * @param priorityFee priority fee for fishers
     * @param amount amount to deposit
     * @param signature signature of the user
     */
    function verifyMessageSignedForFisherBridgeETH(
        address signer,
        address addressToReceive,
        uint256 nonce,
        uint256 priorityFee,
        uint256 amount,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            signer ==
            SignatureRecover.recoverSigner(
                string.concat(
                    AdvancedStrings.addressToString(addressToReceive),
                    ",",
                    Strings.toString(nonce),
                    ",",
                    Strings.toString(priorityFee),
                    ",",
                    Strings.toString(amount)
                ),
                signature
            );
    }
}

contract MockCrossChainBridge {
    function send(
        bytes calldata _payload,
        bytes calldata _options
    ) external payable returns (bytes memory, bytes memory, uint256) {
        uint256 gasFeeToPay = msg.value;
        bytes memory payload = _payload;
        bytes memory options = _options;
        return (payload, options, gasFeeToPay);
    }
}
