// Copyright (c) 2025 GERMAN MARIA ABAL BAZZANO
// License: EVVM Noncommercial License v1.0 (see LICENSE file)

pragma solidity ^0.8.0;
/**
MM""""""""`M            dP   oo                       dP                     
MM  mmmmmmmM            88                            88                     
M`      MMMM .d8888b. d8888P dP 88d8b.d8b. .d8888b. d8888P .d8888b. 88d888b. 
MM  MMMMMMMM Y8ooooo.   88   88 88'`88'`88 88'  `88   88   88'  `88 88'  `88 
MM  MMMMMMMM       88   88   88 88  88  88 88.  .88   88   88.  .88 88       
MM        .M `88888P'   dP   dP dP  dP  dP `88888P8   dP   `88888P' dP       
MMMMMMMMMMMM                                                                 
                                                                            
 * @title Staking Mate contract for Roll A Mate Protocol 
 * @author jistro.eth ariutokintumi.eth
 */

import {SMateMock} from "@EVVM/playground/SMateMock.sol";
import {EvvmMock} from "@EVVM/playground/EvvmMock.sol";
import "forge-std/console2.sol";

contract EstimatorMock {
    struct AddressTypeProposal {
        address actual;
        address proposal;
        uint256 timeToAccept;
    }

    struct UintTypeProposal {
        uint256 actual;
        uint256 proposal;
        uint256 timeToAccept;
    }

    struct EpochMetadata {
        address tokenPool;
        uint256 totalPool;
        uint256 totalStaked;
        uint256 tFinal;
        uint256 tStart;
    }

    EpochMetadata private epoch;
    AddressTypeProposal private activator;
    AddressTypeProposal private evvmAddress;
    AddressTypeProposal private addressSMate;
    AddressTypeProposal private admin;

    bytes32 constant DEPOSIT_IDENTIFIER = bytes32(uint256(1));
    bytes32 constant WITHDRAW_IDENTIFIER = bytes32(uint256(2));
    bytes32 constant BEGUIN_IDENTIFIER = WITHDRAW_IDENTIFIER;

    bytes32 epochId = bytes32(uint256(3));

    modifier onlySMate() {
        if (msg.sender != addressSMate.actual) revert();
        _;
    }

    modifier onlyActivator() {
        if (msg.sender != activator.actual) revert();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin.actual) revert();
        _;
    }

    constructor(
        address _activator,
        address _evvmAddress,
        address _addressSMate,
        address _admin
    ) {
        activator.actual = _activator;
        evvmAddress.actual = _evvmAddress;
        addressSMate.actual = _addressSMate;
        admin.actual = _admin;
    }

    function notifyNewEpoch(
        address tokenPool,
        uint256 totalPool,
        uint256 totalStaked,
        uint256 tStart
    ) public onlyActivator {
        epoch = EpochMetadata({
            tokenPool: tokenPool,
            totalPool: totalPool,
            totalStaked: totalStaked,
            tFinal: block.timestamp,
            tStart: tStart
        });
    }

    function makeEstimation(
        address _user
    )
        external
        onlySMate
        returns (
            bytes32 epochAnswer,
            address tokenAddress,
            uint256 amountTotalToBeRewarded,
            uint256 idToOverwrite,
            uint256 timestampToOverwrite
        )
    {
        //! solo lo usamos una vez y los nombres de las variables son muy descriptivos
        /*tokenAddress
        uint256 tStart = epoch.tStart;
        uint256 tFinal = epoch.tFinal;

        uint256 ratio = epoch.totalPool / epoch.totalStaked;
        */
        uint256 totSmLast;
        uint256 sumSmT;
        //! solo lo usamos una vez y los nombres de las variables son muy descriptivos
        //uint256 tTotal = epoch.tFinal - epoch.tStart;

        uint256 tLast = epoch.tStart;
        SMateMock.HistoryMetadata memory h;
        uint256 size = SMateMock(addressSMate.actual).getSizeOfAddressHistory(
            _user
        );

        for (uint256 i = 0; i < size; i++) {
            h = SMateMock(addressSMate.actual).getAddressHistoryByIndex(
                _user,
                i
            );

            if (size == 1) totSmLast = h.totalStaked;

            console2.log("totSmLast", totSmLast);

            if (h.timestamp > epoch.tFinal) {
                if (totSmLast > 0) sumSmT += (epoch.tFinal - tLast) * totSmLast;

                idToOverwrite = i;
                console2.log("h.timestamp > epoch.tFinal happened");
                console2.log(h.timestamp, ">", epoch.tFinal);
                console2.log("i", i);

                console2.log("sumSmT", sumSmT);
                break;
            }

            if (h.transactionType == epochId) return (0, address(0), 0, 0, 0); // alv!!!!

            if (totSmLast > 0) sumSmT += (h.timestamp - tLast) * totSmLast;

            console2.log("i", i);

            console2.log("sumSmT", sumSmT);
            tLast = h.timestamp;
            totSmLast = h.totalStaked;
            idToOverwrite = i;
        }

        console2.log("for loop ended ---");
        /**
         * @notice to get averageSm the formula is
         *              __ n
         *              \
         *              /       [(ti -ti-1) * Si-1] x 10**18
         *              --i=1
         * averageSm = --------------------------------------
         *                       tFinal - tStart
         *
         * where
         *          ti   ----- timestamp of current iteration
         *          ti-1 ----- timestamp of previus iteration
         *          t final -- epoch end
         *          t zero  -- start of epoch
         */

        //! si al fin y al cabo tTotal siempre es mayor a 0 no es necesario hacer la validacion
        // uint256 averageSm = tTotal > 0 ? (sumSmT * 1e18) / tTotal : 0;

        uint256 averageSm = (sumSmT * 1e18) / (epoch.tFinal - epoch.tStart);

        amountTotalToBeRewarded =
            (averageSm * (epoch.totalPool / epoch.totalStaked)) /
            1e18;

        timestampToOverwrite = epoch.tFinal;

        console2.log("sumSmT", sumSmT);
        console2.log("Average SM", averageSm);
        console2.log("Estimation", amountTotalToBeRewarded);

        epoch.totalPool -= amountTotalToBeRewarded;
        epoch.totalStaked -= h.totalStaked;
    }

    //⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻
    // Admin functions
    //⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻

    function setActivatorProposal(
        address _proposal
    ) external onlyActivator {
        activator.proposal = _proposal;
        activator.timeToAccept = block.timestamp + 1 days;
    }

    function cancelActivatorProposal() external onlyActivator {
        activator.proposal = address(0);
        activator.timeToAccept = 0;
    }

    function acceptActivatorProposal() external {
        if (block.timestamp < activator.timeToAccept) revert();

        activator.actual = activator.proposal;
        activator.proposal = address(0);
        activator.timeToAccept = 0;
    }

    function setEvvmAddressProposal(
        address _proposal
    ) external onlyAdmin {
        evvmAddress.proposal = _proposal;
        evvmAddress.timeToAccept = block.timestamp + 1 days;
    }

    function cancelEvvmAddressProposal() external onlyAdmin {
        evvmAddress.proposal = address(0);
        evvmAddress.timeToAccept = 0;
    }

    function acceptEvvmAddressProposal() external onlyAdmin {
        if (block.timestamp < evvmAddress.timeToAccept) revert();

        evvmAddress.actual = evvmAddress.proposal;
        evvmAddress.proposal = address(0);
        evvmAddress.timeToAccept = 0;
    }

    function setAddressSMateProposal(
        address _proposal
    ) external onlyAdmin {
        addressSMate.proposal = _proposal;
        addressSMate.timeToAccept = block.timestamp + 1 days;
    }

    function cancelAddressSMateProposal() external onlyAdmin {
        addressSMate.proposal = address(0);
        addressSMate.timeToAccept = 0;
    }

    function acceptAddressSMateProposal() external onlyAdmin {
        if (block.timestamp < addressSMate.timeToAccept) revert();

        addressSMate.actual = addressSMate.proposal;
        addressSMate.proposal = address(0);
        addressSMate.timeToAccept = 0;
    }

    function setAdminProposal(
        address _proposal
    ) external onlyAdmin {
        admin.proposal = _proposal;
        admin.timeToAccept = block.timestamp + 1 days;
    }

    function cancelAdminProposal() external onlyAdmin {
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    function acceptAdminProposal() external {
        if (block.timestamp < admin.timeToAccept) revert();

        admin.actual = admin.proposal;
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    //⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻
    // Getters
    //⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎽⎼⎻⎺⎺⎻⎼⎽⎼⎻⎺⎺⎻

    function getEpochMetadata() external view returns (EpochMetadata memory) {
        return epoch;
    }

    function getActualEpochInUint() external view returns (uint256) {
        return uint256(epochId) - 2;
    }

    function getActualEpochInFormat() external view returns (bytes32) {
        return epochId;
    }

    function getActivatorMetadata() external view returns (AddressTypeProposal memory) {
        return activator;
    }

    function getEvvmAddressMetadata()
        external
        view
        returns (AddressTypeProposal memory)
    {
        return evvmAddress;
    }

    function getAddressSMateMetadata()
        external
        view
        returns (AddressTypeProposal memory)
    {
        return addressSMate;
    }

    function getAdminMetadata() external view returns (AddressTypeProposal memory) {
        return admin;
    }



    function simulteEstimation(
        address _user
    )
        external
        view
        returns (
            bytes32 epochAnswer,
            address tokenAddress,
            uint256 amountTotalToBeRewarded,
            uint256 idToOverwrite,
            uint256 timestampToOverwrite
        )
    {
        uint256 totSmLast;
        uint256 sumSmT;

        uint256 tLast = epoch.tStart;
        SMateMock.HistoryMetadata memory h;
        uint256 size = SMateMock(addressSMate.actual).getSizeOfAddressHistory(
            _user
        );

        for (uint256 i = 0; i < size; i++) {
            h = SMateMock(addressSMate.actual).getAddressHistoryByIndex(
                _user,
                i
            );

            if (h.timestamp > epoch.tFinal) {
                if (size == 1) totSmLast = h.totalStaked;

                if (totSmLast > 0) sumSmT += (epoch.tFinal - tLast) * totSmLast;

                idToOverwrite = i;

                break;
            }

            if (h.transactionType == epochId) return (0, address(0), 0, 0, 0); // alv!!!!

            if (totSmLast > 0) sumSmT += (h.timestamp - tLast) * totSmLast;

            tLast = h.timestamp;
            totSmLast = h.totalStaked;
            idToOverwrite = i;
        }

        uint256 averageSm = (sumSmT * 1e18) / (epoch.tFinal - epoch.tStart);

        amountTotalToBeRewarded =
            (averageSm * (epoch.totalPool / epoch.totalStaked)) /
            1e18;

        timestampToOverwrite = epoch.tFinal;
    }


}
