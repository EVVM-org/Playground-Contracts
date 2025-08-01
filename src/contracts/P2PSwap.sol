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

import {Evvm} from "@EVVM/playground/contracts/evvm/Evvm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SignatureRecover} from "@EVVM/playground/lib/SignatureRecover.sol";
import {AdvancedStrings} from "@EVVM/playground/lib/AdvancedStrings.sol";
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

contract P2PSwap {
    using SignatureRecover for *;
    using AdvancedStrings for *;

    address owner;
    address owner_proposal;
    uint256 owner_timeToAccept;

    address evvmAddress;

    address constant MATE_TOKEN_ADDRESS =
        0x0000000000000000000000000000000000000001;
    address constant ETH_ADDRESS = 0x0000000000000000000000000000000000000000;

    struct MarketInformation {
        address tokenA;
        address tokenB;
        uint256 maxSlot;
        uint256 ordersAvailable;
    }

    struct Order {
        address seller;
        uint256 amountA;
        uint256 amountB;
    }

    struct OrderForGetter {
        uint256 marketId;
        uint256 orderId;
        address seller;
        uint256 amountA;
        uint256 amountB;
    }

    struct Percentage {
        uint256 seller;
        uint256 service;
        uint256 mateStaker;
    }

    struct MetadataMakeOrder {
        uint256 nonce;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        bytes signature;
    }

    struct MetadataCancelOrder {
        uint256 nonce;
        address tokenA;
        address tokenB;
        uint256 orderId;
        bytes signature;
    }

    struct MetadataDispatchOrder {
        uint256 nonce;
        address tokenA;
        address tokenB;
        uint256 orderId;
        uint256 amountOfTokenBToFill;
        bytes signature;
    }

    Percentage rewardPersentage;
    Percentage rewardPersentage_proposal;
    uint256 rewardPersentage_timeToAcceptNewChange;

    uint256 percentageFee;
    uint256 percentageFee_proposal;
    uint256 percentageFee_timeToAccept;

    uint256 maxLimitFillFixedFee;
    uint256 maxLimitFillFixedFee_proposal;
    uint256 maxLimitFillFixedFee_timeToAccept;

    address tokenToWithdraw;
    uint256 amountToWithdraw;
    address recipientToWithdraw;
    uint256 timeToWithdrawal;

    uint256 marketCount;

    mapping(address user => mapping(uint256 nonce => bool isUsed)) nonceP2PSwap;

    mapping(address tokenA => mapping(address tokenB => uint256 id)) marketId;

    mapping(uint256 id => MarketInformation info) marketMetadata;

    mapping(uint256 idMarket => mapping(uint256 idOrder => Order)) ordersInsideMarket;

    mapping(address => uint256) balancesOfContract;

    constructor(address _evvmAddress, address _owner) {
        evvmAddress = _evvmAddress;
        owner = _owner;
        maxLimitFillFixedFee = 0.001 ether;
        percentageFee = 500;
        rewardPersentage = Percentage({
            seller: 5000,
            service: 4000,
            mateStaker: 1000
        });
    }

    function makeOrder(
        address user,
        MetadataMakeOrder memory metadata,
        bytes memory signature,
        uint256 _priorityFee_Evvm,
        uint256 _nonce_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) external returns (uint256 market, uint256 orderId) {
        if (
            !verifyMessageSignedForMakeOrder(
                user,
                metadata.nonce,
                metadata.tokenA,
                metadata.tokenB,
                metadata.amountA,
                metadata.amountB,
                signature
            )
        ) {
            revert();
        }

        if (nonceP2PSwap[user][metadata.nonce]) {
            revert();
        }

        makePay(
            user,
            metadata.tokenA,
            _nonce_Evvm,
            metadata.amountA,
            _priorityFee_Evvm,
            _priority_Evvm,
            _signature_Evvm
        );

        market = findMarket(metadata.tokenA, metadata.tokenB);
        if (market == 0) {
            market = createMarket(metadata.tokenA, metadata.tokenB);
        }

        if (
            marketMetadata[market].maxSlot ==
            marketMetadata[market].ordersAvailable
        ) {
            marketMetadata[market].maxSlot++;
            marketMetadata[market].ordersAvailable++;
            orderId = marketMetadata[market].maxSlot;
        } else {
            for (uint256 i = 1; i <= marketMetadata[market].maxSlot + 1; i++) {
                if (ordersInsideMarket[market][i].seller == address(0)) {
                    orderId = i;
                    break;
                }
            }
            marketMetadata[market].ordersAvailable++;
        }

        ordersInsideMarket[market][orderId] = Order(
            user,
            metadata.amountA,
            metadata.amountB
        );

        if (Evvm(evvmAddress).istakingStaker(msg.sender)) {
            if (_priorityFee_Evvm > 0) {
                makeCaPay(msg.sender, metadata.tokenA, _priorityFee_Evvm);
            }

            makeCaPay(
                msg.sender,
                MATE_TOKEN_ADDRESS,
                _priorityFee_Evvm > 0
                    ? (Evvm(evvmAddress).getRewardAmount() * 3)
                    : (Evvm(evvmAddress).getRewardAmount() * 2)
            );
        }

        nonceP2PSwap[user][metadata.nonce] = true;
    }

    function cancelOrder(
        address user,
        MetadataCancelOrder memory metadata,
        uint256 _priorityFee_Evvm,
        uint256 _nonce_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) external {
        if (
            !verifyMessageSignedForCancelOrder(
                user,
                metadata.nonce,
                metadata.tokenA,
                metadata.tokenB,
                metadata.orderId,
                metadata.signature
            )
        ) {
            revert();
        }

        uint256 market = findMarket(metadata.tokenA, metadata.tokenB);

        if (
            market == 0 ||
            nonceP2PSwap[user][metadata.nonce] ||
            ordersInsideMarket[market][metadata.orderId].seller != user
        ) {
            revert();
        }

        if (_priorityFee_Evvm > 0) {
            makePay(
                user,
                MATE_TOKEN_ADDRESS,
                _nonce_Evvm,
                _priorityFee_Evvm,
                0,
                _priority_Evvm,
                _signature_Evvm
            );
        }

        makeCaPay(
            user,
            metadata.tokenA,
            ordersInsideMarket[market][metadata.orderId].amountA
        );

        ordersInsideMarket[market][metadata.orderId].seller = address(0);

        if (Evvm(evvmAddress).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                MATE_TOKEN_ADDRESS,
                _priorityFee_Evvm > 0
                    ? ((Evvm(evvmAddress).getRewardAmount() * 3) +
                        _priorityFee_Evvm)
                    : (Evvm(evvmAddress).getRewardAmount() * 2)
            );
        }
        marketMetadata[market].ordersAvailable--;
        nonceP2PSwap[user][metadata.nonce] = true;
    }

    function dispatchOrder_fillPropotionalFee(
        address user,
        MetadataDispatchOrder memory metadata,
        uint256 _priorityFee_Evvm,
        uint256 _nonce_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) external {
        if (
            !verifyMessageSignedForDispatchOrder(
                user,
                metadata.nonce,
                metadata.tokenA,
                metadata.tokenB,
                metadata.orderId,
                metadata.signature
            )
        ) {
            revert();
        }

        uint256 market = findMarket(metadata.tokenA, metadata.tokenB);

        if (
            market == 0 ||
            ordersInsideMarket[market][metadata.orderId].seller == address(0) ||
            nonceP2PSwap[user][metadata.nonce]
        ) {
            revert();
        }

        uint256 fee = calculateFillPropotionalFee(
            ordersInsideMarket[market][metadata.orderId].amountB
        );

        if (
            metadata.amountOfTokenBToFill <
            ordersInsideMarket[market][metadata.orderId].amountB + fee
        ) {
            revert();
        }

        makePay(
            user,
            metadata.tokenB,
            _nonce_Evvm,
            metadata.amountOfTokenBToFill,
            _priorityFee_Evvm,
            _priority_Evvm,
            _signature_Evvm
        );

        // si es mas del fee + el monto de la orden hacemos caPay al usuario del sobranate
        if (
            metadata.amountOfTokenBToFill >
            ordersInsideMarket[market][metadata.orderId].amountB + fee
        ) {
            makeCaPay(
                user,
                metadata.tokenB,
                metadata.amountOfTokenBToFill -
                    (ordersInsideMarket[market][metadata.orderId].amountB + fee)
            );
        }

        EvvmStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmStructs.DisperseCaPayMetadata(
            ordersInsideMarket[market][metadata.orderId].amountB +
                (fee * (rewardPersentage.seller / 10_000)),
            ordersInsideMarket[market][metadata.orderId].seller
        );
        toData[1] = EvvmStructs.DisperseCaPayMetadata(
            _priorityFee_Evvm + (fee * (rewardPersentage.mateStaker / 10_000)),
            msg.sender
        );

        balancesOfContract[metadata.tokenB] +=
            fee *
            (rewardPersentage.service / 10_000);

        makeDisperseCaPay(toData, metadata.tokenB, fee);

        makeCaPay(
            user,
            metadata.tokenA,
            ordersInsideMarket[market][metadata.orderId].amountA
        );

        if (Evvm(evvmAddress).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                MATE_TOKEN_ADDRESS,
                metadata.amountOfTokenBToFill >
                    ordersInsideMarket[market][metadata.orderId].amountB + fee
                    ? Evvm(evvmAddress).getRewardAmount() * 5
                    : Evvm(evvmAddress).getRewardAmount() * 4
            );
        }

        ordersInsideMarket[market][metadata.orderId].seller = address(0);
        marketMetadata[market].ordersAvailable--;
        nonceP2PSwap[user][metadata.nonce] = true;
    }

    function dispatchOrder_fillFixedFee(
        address user,
        MetadataDispatchOrder memory metadata,
        uint256 _priorityFee_Evvm,
        uint256 _nonce_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm,
        uint256 _amountOut ///@dev for testing purposes
    ) external {
        if (
            !verifyMessageSignedForDispatchOrder(
                user,
                metadata.nonce,
                metadata.tokenA,
                metadata.tokenB,
                metadata.orderId,
                metadata.signature
            )
        ) {
            revert();
        }

        uint256 market = findMarket(metadata.tokenA, metadata.tokenB);

        if (
            market == 0 ||
            ordersInsideMarket[market][metadata.orderId].seller == address(0) ||
            nonceP2PSwap[user][metadata.nonce]
        ) {
            revert();
        }

        (uint256 fee, uint256 fee10) = calculateFillFixedFee(
            metadata.tokenB,
            ordersInsideMarket[market][metadata.orderId].amountB,
            _amountOut
        );

        if (
            metadata.amountOfTokenBToFill <
            ordersInsideMarket[market][metadata.orderId].amountB + fee - fee10
        ) {
            revert();
        }

        makePay(
            user,
            metadata.tokenB,
            _nonce_Evvm,
            metadata.amountOfTokenBToFill,
            _priorityFee_Evvm,
            _priority_Evvm,
            _signature_Evvm
        );

        uint256 finalFee = metadata.amountOfTokenBToFill >=
            ordersInsideMarket[market][metadata.orderId].amountB +
                fee -
                fee10 &&
            metadata.amountOfTokenBToFill <
            ordersInsideMarket[market][metadata.orderId].amountB + fee
            ? metadata.amountOfTokenBToFill -
                ordersInsideMarket[market][metadata.orderId].amountB
            : fee;

        // si es mas del fee + el monto de la orden hacemos caPay al usuario del sobranate
        if (
            metadata.amountOfTokenBToFill >
            ordersInsideMarket[market][metadata.orderId].amountB + fee
        ) {
            makeCaPay(
                user,
                metadata.tokenB,
                metadata.amountOfTokenBToFill -
                    (ordersInsideMarket[market][metadata.orderId].amountB + fee)
            );
        }

        EvvmStructs.DisperseCaPayMetadata[]
            memory toData = new EvvmStructs.DisperseCaPayMetadata[](2);

        toData[0] = EvvmStructs.DisperseCaPayMetadata(
            ordersInsideMarket[market][metadata.orderId].amountB +
                (finalFee * (rewardPersentage.seller / 10_000)),
            ordersInsideMarket[market][metadata.orderId].seller
        );
        toData[1] = EvvmStructs.DisperseCaPayMetadata(
            _priorityFee_Evvm +
                (finalFee * (rewardPersentage.mateStaker / 10_000)),
            msg.sender
        );

        balancesOfContract[metadata.tokenB] +=
            finalFee *
            (rewardPersentage.service / 10_000);

        makeDisperseCaPay(toData, metadata.tokenB, fee);

        makeCaPay(
            user,
            metadata.tokenA,
            ordersInsideMarket[market][metadata.orderId].amountA
        );

        if (Evvm(evvmAddress).istakingStaker(msg.sender)) {
            makeCaPay(
                msg.sender,
                MATE_TOKEN_ADDRESS,
                metadata.amountOfTokenBToFill >
                    ordersInsideMarket[market][metadata.orderId].amountB + fee
                    ? Evvm(evvmAddress).getRewardAmount() * 5
                    : Evvm(evvmAddress).getRewardAmount() * 4
            );
        }

        ordersInsideMarket[market][metadata.orderId].seller = address(0);
        marketMetadata[market].ordersAvailable--;
        nonceP2PSwap[user][metadata.nonce] = true;
    }

    //devolver el 0.05% del monto de la orden
    function calculateFillPropotionalFee(
        uint256 amount
    ) internal view returns (uint256 fee) {
        ///@dev get the % of the amount
        fee = (amount * percentageFee) / 10_000;
    }

    function calculateFillFixedFee(
        address token,
        uint256 amount,
        uint256 _amountOut ///@dev for testing purposes
    ) internal view returns (uint256 fee, uint256 fee10) {
        if (token != ETH_ADDRESS) {
            if (
                Evvm(evvmAddress).getTokenUniswapPool(token) == address(0)
            ) {
                fee = calculateFillPropotionalFee(amount);
            } else {
                if (calculateFillPropotionalFee(amount) > _amountOut) {
                    fee = _amountOut;
                    fee10 = (fee * 1000) / 10_000;
                } else {
                    ///@dev if is less than 0.001 ETH use the fill propotional fee
                    fee = calculateFillPropotionalFee(amount);
                }
            }
        } else {
            if (calculateFillPropotionalFee(amount) > maxLimitFillFixedFee) {
                fee = maxLimitFillFixedFee;
                fee10 = (fee * 1000) / 10_000;
            } else {
                fee = calculateFillPropotionalFee(amount);
            }
        }
    }

    function createMarket(
        address tokenA,
        address tokenB
    ) internal returns (uint256) {
        marketCount++;
        marketId[tokenA][tokenB] = marketCount;
        marketMetadata[marketCount] = MarketInformation(tokenA, tokenB, 0, 0);
        return marketCount;
    }

    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢
    // Tools for Evvm
    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢

    function makePay(
        address _user_Evvm,
        address _token_Evvm,
        uint256 _nonce_Evvm,
        uint256 _ammount_Evvm,
        uint256 _priorityFee_Evvm,
        bool _priority_Evvm,
        bytes memory _signature_Evvm
    ) internal {
        if (_priority_Evvm) {
            Evvm(evvmAddress).payMateStaking_async(
                _user_Evvm,
                address(this),
                "",
                _token_Evvm,
                _ammount_Evvm,
                _priorityFee_Evvm,
                _nonce_Evvm,
                address(this),
                _signature_Evvm
            );
        } else {
            Evvm(evvmAddress).payMateStaking_sync(
                _user_Evvm,
                address(this),
                "",
                _token_Evvm,
                _ammount_Evvm,
                _priorityFee_Evvm,
                address(this),
                _signature_Evvm
            );
        }
    }

    function makeCaPay(
        address _user_Evvm,
        address _token_Evvm,
        uint256 _ammount_Evvm
    ) internal {
        Evvm(evvmAddress).caPay(_user_Evvm, _token_Evvm, _ammount_Evvm);
    }

    function makeDisperseCaPay(
        EvvmStructs.DisperseCaPayMetadata[] memory toData,
        address token,
        uint256 amount
    ) internal {
        Evvm(evvmAddress).disperseCaPay(toData, token, amount);
    }

    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢
    // Signature functions
    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢

    function verifyMessageSignedForMakeOrder(
        address signer,
        uint256 _nonce,
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            signer ==
            SignatureRecover.recoverSigner(
                string.concat(
                    "63b8896c",
                    ",",
                    Strings.toString(_nonce),
                    ",",
                    AdvancedStrings.addressToString(_tokenA),
                    ",",
                    AdvancedStrings.addressToString(_tokenB),
                    ",",
                    Strings.toString(_amountA),
                    ",",
                    Strings.toString(_amountB)
                ),
                signature
            );
    }

    function verifyMessageSignedForCancelOrder(
        address signer,
        uint256 _nonce,
        address _tokenA,
        address _tokenB,
        uint256 _orderId,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            signer ==
            SignatureRecover.recoverSigner(
                string.concat(
                    "215497c1",
                    ",",
                    Strings.toString(_nonce),
                    ",",
                    AdvancedStrings.addressToString(_tokenA),
                    ",",
                    AdvancedStrings.addressToString(_tokenB),
                    ",",
                    Strings.toString(_orderId)
                ),
                signature
            );
    }

    function verifyMessageSignedForDispatchOrder(
        address signer,
        uint256 _nonce,
        address _tokenA,
        address _tokenB,
        uint256 _orderId,
        bytes memory signature
    ) internal pure returns (bool) {
        return
            signer ==
            SignatureRecover.recoverSigner(
                string.concat(
                    "d3584696",
                    ",",
                    Strings.toString(_nonce),
                    ",",
                    AdvancedStrings.addressToString(_tokenA),
                    ",",
                    AdvancedStrings.addressToString(_tokenB),
                    ",",
                    Strings.toString(_orderId)
                ),
                signature
            );
    }

    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢
    // Admin tools
    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢

    function proposeOwner(address _owner) external {
        if (msg.sender != owner) {
            revert();
        }
        owner_proposal = _owner;
        owner_timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposeOwner() external {
        if (
            msg.sender != owner_proposal || block.timestamp > owner_timeToAccept
        ) {
            revert();
        }
        owner_proposal = address(0);
    }

    function acceptOwner() external {
        if (
            msg.sender != owner_proposal || block.timestamp > owner_timeToAccept
        ) {
            revert();
        }
        owner = owner_proposal;
    }

    function proposeFillFixedPercentage(
        uint256 _seller,
        uint256 _service,
        uint256 _mateStaker
    ) external {
        if (msg.sender != owner) {
            revert();
        }
        if (_seller + _service + _mateStaker != 10_000) {
            revert();
        }
        rewardPersentage_proposal = Percentage(_seller, _service, _mateStaker);
        rewardPersentage_timeToAcceptNewChange = block.timestamp + 1 days;
    }

    function rejectProposeFillFixedPercentage() external {
        if (
            msg.sender != owner ||
            block.timestamp > rewardPersentage_timeToAcceptNewChange
        ) {
            revert();
        }
        rewardPersentage_proposal = Percentage(0, 0, 0);
    }

    function acceptFillFixedPercentage() external {
        if (
            msg.sender != owner ||
            block.timestamp > rewardPersentage_timeToAcceptNewChange
        ) {
            revert();
        }
        rewardPersentage = rewardPersentage_proposal;
    }

    function proposeFillPropotionalPercentage(
        uint256 _seller,
        uint256 _service,
        uint256 _mateStaker
    ) external {
        if (msg.sender != owner && _seller + _service + _mateStaker != 10_000) {
            revert();
        }
        rewardPersentage_proposal = Percentage(_seller, _service, _mateStaker);
        rewardPersentage_timeToAcceptNewChange = block.timestamp + 1 days;
    }

    function rejectProposeFillPropotionalPercentage() external {
        if (
            msg.sender != owner ||
            block.timestamp > rewardPersentage_timeToAcceptNewChange
        ) {
            revert();
        }
        rewardPersentage_proposal = Percentage(0, 0, 0);
    }

    function acceptFillPropotionalPercentage() external {
        if (
            msg.sender != owner ||
            block.timestamp > rewardPersentage_timeToAcceptNewChange
        ) {
            revert();
        }
        rewardPersentage = rewardPersentage_proposal;
    }

    function proposePercentageFee(uint256 _percentageFee) external {
        if (msg.sender != owner) {
            revert();
        }
        percentageFee_proposal = _percentageFee;
        percentageFee_timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposePercentageFee() external {
        if (
            msg.sender != owner || block.timestamp > percentageFee_timeToAccept
        ) {
            revert();
        }
        percentageFee_proposal = 0;
    }

    function acceptPercentageFee() external {
        if (
            msg.sender != owner || block.timestamp > percentageFee_timeToAccept
        ) {
            revert();
        }
        percentageFee = percentageFee_proposal;
    }

    function proposeMaxLimitFillFixedFee(
        uint256 _maxLimitFillFixedFee
    ) external {
        if (msg.sender != owner) {
            revert();
        }
        maxLimitFillFixedFee_proposal = _maxLimitFillFixedFee;
        maxLimitFillFixedFee_timeToAccept = block.timestamp + 1 days;
    }

    function rejectProposeMaxLimitFillFixedFee() external {
        if (
            msg.sender != owner ||
            block.timestamp > maxLimitFillFixedFee_timeToAccept
        ) {
            revert();
        }
        maxLimitFillFixedFee_proposal = 0;
    }

    function acceptMaxLimitFillFixedFee() external {
        if (
            msg.sender != owner ||
            block.timestamp > maxLimitFillFixedFee_timeToAccept
        ) {
            revert();
        }
        maxLimitFillFixedFee = maxLimitFillFixedFee_proposal;
    }

    function proposeWithdrawal(
        address _tokenToWithdraw,
        uint256 _amountToWithdraw,
        address _to
    ) external {
        if (
            msg.sender != owner ||
            _amountToWithdraw > balancesOfContract[_tokenToWithdraw]
        ) {
            revert();
        }
        tokenToWithdraw = _tokenToWithdraw;
        amountToWithdraw = _amountToWithdraw;
        recipientToWithdraw = _to;
        timeToWithdrawal = block.timestamp + 1 days;
    }

    function rejectProposeWithdrawal() external {
        if (msg.sender != owner || block.timestamp > timeToWithdrawal) {
            revert();
        }
        tokenToWithdraw = address(0);
        amountToWithdraw = 0;
        recipientToWithdraw = address(0);
        timeToWithdrawal = 0;
    }

    function acceptWithdrawal() external {
        if (msg.sender != owner || block.timestamp > timeToWithdrawal) {
            revert();
        }
        makeCaPay(recipientToWithdraw, tokenToWithdraw, amountToWithdraw);
        tokenToWithdraw = address(0);
        amountToWithdraw = 0;
        recipientToWithdraw = address(0);
        timeToWithdrawal = 0;

        balancesOfContract[tokenToWithdraw] -= amountToWithdraw;
    }

    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢
    //getters
    //◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢
    function getAllMartetOrders(
        uint256 market
    ) public view returns (OrderForGetter[] memory orders) {
        orders = new OrderForGetter[](marketMetadata[market].maxSlot + 1);

        for (uint256 i = 1; i <= marketMetadata[market].maxSlot + 1; i++) {
            if (ordersInsideMarket[market][i].seller != address(0)) {
                orders[i - 1] = OrderForGetter(
                    market,
                    i,
                    ordersInsideMarket[market][i].seller,
                    ordersInsideMarket[market][i].amountA,
                    ordersInsideMarket[market][i].amountB
                );
            }
        }
        return orders;
    }

    function getMyOrdersInSpecificMarket(
        address user,
        uint256 market
    ) public view returns (OrderForGetter[] memory orders) {
        orders = new OrderForGetter[](marketMetadata[market].maxSlot + 1);

        for (uint256 i = 1; i <= marketMetadata[market].maxSlot + 1; i++) {
            if (ordersInsideMarket[market][i].seller == user) {
                orders[i - 1] = OrderForGetter(
                    market,
                    i,
                    ordersInsideMarket[market][i].seller,
                    ordersInsideMarket[market][i].amountA,
                    ordersInsideMarket[market][i].amountB
                );
            }
        }
        return orders;
    }

    function findMarket(
        address tokenA,
        address tokenB
    ) public view returns (uint256) {
        return marketId[tokenA][tokenB];
    }

    function getMarketMetadata(
        uint256 market
    ) public view returns (MarketInformation memory) {
        return marketMetadata[market];
    }

    function getAllMarketsMetadata()
        public
        view
        returns (MarketInformation[] memory)
    {
        MarketInformation[] memory markets = new MarketInformation[](
            marketCount + 1
        );
        for (uint256 i = 1; i <= marketCount; i++) {
            markets[i - 1] = marketMetadata[i];
        }
        return markets;
    }

    function checkIfANonceP2PSwapIsUsed(
        address user,
        uint256 nonce
    ) public view returns (bool) {
        return nonceP2PSwap[user][nonce];
    }
}
