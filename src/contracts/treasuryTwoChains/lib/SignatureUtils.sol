// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

import {SignatureRecover} from "@EVVM/playground/library/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/playground/library/AdvancedStrings.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.0;

library SignatureUtils {
    /**
     *  @dev using EIP-191 (https://eips.ethereum.org/EIPS/eip-191) can be used to sign and
     *       verify messages, the next functions are used to verify the messages signed
     *       by the users
     */

    /**
     *  @notice This function is used to verify the message signed for the fisher bridge
     *  @param signer user who signed the message
     *  @param addressToReceive address of the receiver
     *  @param nonce nonce of the transaction
     *  @param tokenAddress address of the token to deposit
     *  @param priorityFee priorityFee to send to the white fisher
     *  @param amount amount to deposit
     *  @param signature signature of the user who wants to send the message
     *  @return true if the signature is valid
     */
    function verifyMessageSignedForFisherBridge(
        uint256 evvmID,
        address signer,
        address addressToReceive,
        uint256 nonce,
        address tokenAddress,
        uint256 priorityFee,
        uint256 amount,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            SignatureRecover.signatureVerification(
                Strings.toString(evvmID),
                "fisherBridge",
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
                signature,
                signer
            );
    }
}
