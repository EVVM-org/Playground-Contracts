// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.org/docs/EVVMNoncommercialLicense

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
import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {ErrorsLib} from "@EVVM/playground/contracts/treasuryTwoChains/lib/ErrorsLib.sol";
import {TreasuryStructs} from "@EVVM/playground/contracts/treasuryTwoChains/lib/TreasuryStructs.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";

import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract TreasuryHostChainStation is TreasuryStructs, OApp, OAppOptionsType3 {
    /// @notice Address of the EVVM core contract
    address evvmAddress;

    AddressTypeProposal admin;

    AddressTypeProposal mailboxAddress;

    HyperlaneConfig hyperlane;

    LayerZeroConfig layerZero;

    bytes _options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), 50000, 0);
    
    mapping(uint256 externalChainId => ExternalChainConfig)
        public externalChainConfig;

    /**
     * @notice Initialize Treasury with EVVM contract address
     * @param _evvmAddress Address of the EVVM core contract
     */
    constructor(
        address _evvmAddress,
        address _admin,
        address _endpoint
    )  OApp(_endpoint, _admin) Ownable(_admin) {
        evvmAddress = _evvmAddress;
        admin = AddressTypeProposal({
            current: _admin,
            proposal: address(0),
            timeToAccept: 0
        });
        //_setPeer()
    }

    /**
     * @notice Withdraw ETH or ERC20 tokens
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function withdraw(
        address from,
        address toAddress,
        address token,
        uint256 amount,
        bytes1 protocolToExecute
    ) external payable {
        if (token == Evvm(evvmAddress).getEvvmMetadata().principalTokenAddress)
            revert ErrorsLib.PrincipalTokenIsNotWithdrawable();

        if (Evvm(evvmAddress).getBalance(msg.sender, token) < amount)
            revert ErrorsLib.InsufficientBalance();

        Evvm(evvmAddress).removeAmountFromUser(msg.sender, token, amount);

        bytes memory payload = encodePayload(token, toAddress, amount);

        if (protocolToExecute == 0x01) {
            // 0x01 = Hyperlane
            uint256 quote = getQuoteHyperlane(toAddress, token, amount);
            /*messageId = */ IMailbox(mailboxAddress.current).dispatch{
                value: quote
            }(
                hyperlane.domainId,
                hyperlane.externalChainStationAddress,
                payload
            );
        } else if (protocolToExecute == 0x02) {
            // 0x02 = LayerZero
            uint256 fee = quoteLayerZero(
                toAddress,
                token,
                amount
            );
            _lzSend(
                layerZero.eid,
                payload,
                _options,
                MessagingFee(fee, 0),
                msg.sender // Refund any excess fees to the sender.
            );
        } else {
            revert ();
        }
    }

    // Hyperlane Specific Functions //
    function getQuoteHyperlane(
        address toAddress,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        return
            IMailbox(mailboxAddress.current).quoteDispatch(
                hyperlane.domainId,
                hyperlane.externalChainStationAddress,
                encodePayload(token, toAddress, amount)
            );
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data
    ) external payable virtual {
        if (msg.sender != hyperlane.mailboxAddress)
            revert ErrorsLib.MailboxNotAuthorized();

        if (_sender != hyperlane.externalChainStationAddress)
            revert ErrorsLib.SenderNotAuthorized();

        if (_origin != hyperlane.domainId)
            revert ErrorsLib.ChainIdNotAuthorized();
        //bytes memory payload = abi.encode(token, toAddress, amount);

        (address token, address toAddress, uint256 amount) = abi.decode(
            _data,
            (address, address, uint256)
        );
        Evvm(evvmAddress).addAmountToUser(toAddress, token, amount);
    }

    // LayerZero Specific Functions //

    function quoteLayerZero(
        address toAddress,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        MessagingFee memory fee = _quote(
            layerZero.eid,
            encodePayload(token, toAddress, amount),
            _options,
            false
        );
        return fee.nativeFee;
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata message,
        address /*executor*/, // Executor address as specified by the OApp.
        bytes calldata /*_extraData*/ // Any extra data or options to trigger on receipt.
    ) internal override {
        // Decode the payload to get the message
        

        if (_origin.srcEid != layerZero.eid)
            revert ErrorsLib.ChainIdNotAuthorized();

        if (_origin.sender != layerZero.externalChainStationAddress)
            revert ErrorsLib.SenderNotAuthorized();

        (address token, address toAddress, uint256 amount) = abi.decode(
            message,
            (address, address, uint256)
        );
        Evvm(evvmAddress).addAmountToUser(toAddress, token, amount);
    }

    function encodePayload(
        address token,
        address toAddress,
        uint256 amount
    ) internal pure returns (bytes memory payload) {
        payload = abi.encode(token, toAddress, amount);
    }

    function decodePayload(
        bytes memory payload
    ) internal pure returns (address token, address toAddress, uint256 amount) {
        (token, toAddress, amount) = abi.decode(
            payload,
            (address, address, uint256)
        );
    }

    
}
