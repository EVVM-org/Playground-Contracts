// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense
pragma solidity ^0.8.0;

library PayloadUtils {
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
