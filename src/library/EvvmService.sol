// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense

pragma solidity ^0.8.0;

import {EvvmStructs} from "@EVVM/playground/interfaces/IEvvm.sol";
import {SignatureUtil} from "@EVVM/playground/library/utils/SignatureUtil.sol";
import {AsyncNonce} from "@EVVM/playground/library/utils/nonces/AsyncNonce.sol";
import {PaymentStakingVariables} from "@EVVM/playground/library/utils/service/PaymentStakingVariables.sol";

abstract contract EvvmService is AsyncNonce, PaymentStakingVariables {
    error InvalidServiceSignature();

    constructor(
        address evvmAddress,
        address stakingAddress
    ) PaymentStakingVariables(evvmAddress, stakingAddress) {}

    function validateServiceSignature(
        string memory functionName,
        string memory inputs,
        bytes memory signature,
        address expectedSigner
    ) internal view virtual {
        if (
            !SignatureUtil.verifySignature(
                evvm.getEvvmID(),
                functionName,
                inputs,
                signature,
                expectedSigner
            )
        ) revert InvalidServiceSignature();
    }

    function requestPay(
        address from,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        bytes memory signature
    ) internal virtual {
        evvm.pay(
            from,
            address(this),
            "",
            token,
            amount,
            priorityFee,
            nonce,
            priorityFlag,
            address(this),
            signature
        );
    }

    function requestDispersePay(
        EvvmStructs.DispersePayMetadata[] memory toData,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        bytes memory signature
    ) internal virtual {
        evvm.dispersePay(
            address(this),
            toData,
            token,
            amount,
            priorityFee,
            nonce,
            priorityFlag,
            address(this),
            signature
        );
    }

    function makeCaPay(
        address to,
        address token,
        uint256 amount
    ) internal virtual {
        evvm.caPay(to, token, amount);
    }

    function makeDisperseCaPay(
        EvvmStructs.DisperseCaPayMetadata[] memory toData,
        address token,
        uint256 amount
    ) internal virtual {
        evvm.disperseCaPay(toData, token, amount);
    }

    function _makeStakeService(uint256 amountToStake) internal {
        staking.prepareServiceStaking(amountToStake);
        evvm.caPay(
            address(staking),
            getPrincipalTokenAddress(),
            staking.priceOfStaking() * amountToStake
        );
        staking.confirmServiceStaking();
    }

    function _makeUnstakeService(uint256 amountToUnstake) internal {
        staking.serviceUnstaking(amountToUnstake);
    }
}
