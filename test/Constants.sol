// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;

/**
 * @title EvvmStorage
 * @author jistro.eth
 * @dev Storage layout contract for EVVM proxy pattern implementation.
 *      This contract inherits all structures from EvvmStructs and
 *      defines the storage layout that will be used by the proxy pattern.
 *
 * @notice This contract should not be deployed directly, it's meant to be
 *         inherited by the implementation contracts to ensure they maintain
 *         the same storage layout.
 */

import {Evvm} from "@EVVM/playground/evvm/Evvm.sol";
import {SMateMock} from "@EVVM/playground/staking/SMateMock.sol";

abstract contract Constants {
    bytes32 constant DEPOSIT_HISTORY_SMATE_IDENTIFIER = bytes32(uint256(1));
    bytes32 constant WITHDRAW_HISTORY_SMATE_IDENTIFIER = bytes32(uint256(2));

    address constant MATE_TOKEN_ADDRESS =
        0x0000000000000000000000000000000000000001;

    address constant ETHER_ADDRESS = 0x0000000000000000000000000000000000000000;

    /*
        | ACCOUNT       |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  | 
        | ADMIN         |  X  |     |     |     |     |     |     |     |
        | Common users  |     |  X  |  X  |  X  |     |     |     |     |
        | Staker        |     |     |     |  X  |  X  |     |     |     |
        | Golden        |     |     |     |     |     |  X  |     |     |
        | Activator     |     |     |     |     |     |     |  X  |     |
        
        The 8th user is used as a WILDCARD
    */

    struct AccountData {
        address Address;
        uint256 PrivateKey;
    }

    AccountData ACCOUNT1 =
        AccountData({
            Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            PrivateKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });

    AccountData ACCOUNT2 =
        AccountData({
            Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            PrivateKey: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
        });

    AccountData ACCOUNT3 =
        AccountData({
            Address: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            PrivateKey: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
        });

    AccountData ACCOUNT4 =
        AccountData({
            Address: 0x90F79bf6EB2c4f870365E785982E1f101E93b906,
            PrivateKey: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
        });

    AccountData ACCOUNT5 =
        AccountData({
            Address: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
            PrivateKey: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a
        });

    AccountData ACCOUNT6 =
        AccountData({
            Address: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
            PrivateKey: 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
        });

    AccountData ACCOUNT7 =
        AccountData({
            Address: 0x976EA74026E726554dB657fA54763abd0C3a0aa9,
            PrivateKey: 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e
        });

    AccountData ACCOUNT8 =
        AccountData({
            Address: 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
            PrivateKey: 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
        });

    AccountData ADMIN =
        AccountData({
            Address: ACCOUNT1.Address,
            PrivateKey: ACCOUNT1.PrivateKey
        });

    AccountData COMMON_USER_NO_STAKER_1 =
        AccountData({
            Address: ACCOUNT2.Address,
            PrivateKey: ACCOUNT2.PrivateKey
        });

    AccountData COMMON_USER_NO_STAKER_2 =
        AccountData({
            Address: ACCOUNT3.Address,
            PrivateKey: ACCOUNT3.PrivateKey
        });

    AccountData COMMON_USER_STAKER =
        AccountData({
            Address: ACCOUNT4.Address,
            PrivateKey: ACCOUNT4.PrivateKey
        });

    // this should be apllied only on sMATE and estimator tests
    AccountData STAKER =
        AccountData({
            Address: ACCOUNT5.Address,
            PrivateKey: ACCOUNT5.PrivateKey
        });

    AccountData GOLDEN_STAKER =
        AccountData({
            Address: ACCOUNT6.Address,
            PrivateKey: ACCOUNT6.PrivateKey
        });

    AccountData ACTIVATOR =
        AccountData({
            Address: ACCOUNT7.Address,
            PrivateKey: ACCOUNT7.PrivateKey
        });

    AccountData WILDCARD_USER =
        AccountData({
            Address: ACCOUNT8.Address,
            PrivateKey: ACCOUNT8.PrivateKey
        });
}

contract MockContract {
    SMateMock sMate;
    Evvm evvm;

    constructor(address sMateAddress) {
        sMate = SMateMock(sMateAddress);
        evvm = Evvm(sMate.getEvvmAddress());
    }

    function unstake(uint256 amount, uint256 nonceSMate, address _user) public {
        sMate.publicServiceStaking(
            false,
            _user,
            address(this),
            nonceSMate,
            amount,
            bytes(""),
            0,
            0,
            false,
            bytes("")
        );
    }

    function getBackMate(address user) public {
        evvm.caPay(
            user,
            0x0000000000000000000000000000000000000001,
            evvm.seeBalance(
                address(this),
                0x0000000000000000000000000000000000000001
            )
        );
    }
}
