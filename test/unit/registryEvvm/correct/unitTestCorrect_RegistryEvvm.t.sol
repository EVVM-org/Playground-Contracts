// SPDX-License-Identifier: MIT

/**
 ____ ____ ____ ____ _________ ____ ____ ____ ____ 
||U |||N |||I |||T |||       |||T |||E |||S |||T ||
||__|||__|||__|||__|||_______|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/_______\|/__\|/__\|/__\|/__\|

 * @title unit test for EVVM function correct behavior
 * @notice some functions has evvm functions that are implemented
 *         for payment and dosent need to be tested here
 */

pragma solidity ^0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Constants, RegistryEvvmTestTwo} from "test/Constants.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RegistryEvvm} from "@EVVM/playground/contracts/registryEvvm/RegistryEvvm.sol";

contract unitTestCorrect_RegistryEvvm is Test, Constants {
    RegistryEvvm registryEvvm;
    RegistryEvvmTestTwo registryEvvmTestTwo;
    ERC1967Proxy proxyRegistryEvvm;

    AccountData USER = WILDCARD_USER;

    function setUp() public {
        registryEvvm = new RegistryEvvm();
        proxyRegistryEvvm = new ERC1967Proxy(address(registryEvvm), "");

        RegistryEvvm(address(proxyRegistryEvvm)).initialize(ADMIN.Address);
    }

    modifier prepareRegisterChainId() {
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = 111555111;
        chainIds[1] = 222555222;
        chainIds[2] = 333555333;

        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).registerChainId(chainIds);
        vm.stopPrank();
        _;
    }

    function test__unit_correct__CorrectDeployment() external {
        assertEq(RegistryEvvm(address(proxyRegistryEvvm)).getVersion(), 1);
    }

    function test__unit_correct__RegisterEvvm()
        external
        prepareRegisterChainId
    {
        vm.startPrank(USER.Address);
        uint256 evvmIdOne = RegistryEvvm(address(proxyRegistryEvvm))
            .registerEvvm(111555111, address(234));
        vm.stopPrank();

        assertEq(evvmIdOne, 1000);

        RegistryEvvm.Metadata memory metadataOne = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(evvmIdOne);
        assertEq(metadataOne.chainId, 111555111);
        assertEq(metadataOne.evvmAddress, address(234));

        vm.startPrank(USER.Address);
        uint256 evvmIdTwo = RegistryEvvm(address(proxyRegistryEvvm))
            .registerEvvm(222555222, address(23456));
        vm.stopPrank();

        assertEq(evvmIdTwo, 1001);
        RegistryEvvm.Metadata memory metadataTwo = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(evvmIdTwo);
        assertEq(metadataTwo.chainId, 222555222);
        assertEq(metadataTwo.evvmAddress, address(23456));
    }

    function test__unit_correct__SudoRegisterEvvm()
        external
        prepareRegisterChainId
    {
        vm.startPrank(ADMIN.Address);
        uint256 evvmIdOne = RegistryEvvm(address(proxyRegistryEvvm))
            .sudoRegisterEvvm(69, 111555111, address(234));
        vm.stopPrank();

        assertEq(evvmIdOne, 69);

        RegistryEvvm.Metadata memory metadataOne = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(evvmIdOne);
        assertEq(metadataOne.chainId, 111555111);
        assertEq(metadataOne.evvmAddress, address(234));

        vm.startPrank(ADMIN.Address);
        uint256 evvmIdTwo = RegistryEvvm(address(proxyRegistryEvvm))
            .sudoRegisterEvvm(420, 222555222, address(23456));
        vm.stopPrank();

        assertEq(evvmIdTwo, 420);
        RegistryEvvm.Metadata memory metadataTwo = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(evvmIdTwo);
        assertEq(metadataTwo.chainId, 222555222);
        assertEq(metadataTwo.evvmAddress, address(23456));
    }

    function test__unit_correct__registerChainId() external {
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = 111555111;
        chainIds[1] = 222555222;
        chainIds[2] = 333555333;

        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).registerChainId(chainIds);
        vm.stopPrank();

        assertEq(
            RegistryEvvm(address(proxyRegistryEvvm)).isChainIdRegistered(
                111555111
            ),
            true
        );
        assertEq(
            RegistryEvvm(address(proxyRegistryEvvm)).isChainIdRegistered(
                222555222
            ),
            true
        );
        assertEq(
            RegistryEvvm(address(proxyRegistryEvvm)).isChainIdRegistered(
                333555333
            ),
            true
        );
    }

    function test__unit_correct__proposeSuperUser() external {
        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).proposeSuperUser(USER.Address);
        vm.stopPrank();

        RegistryEvvm.AddressTypeProposal memory superUser = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getSuperUserData();

        assertEq(superUser.current, ADMIN.Address);
        assertEq(superUser.proposal, USER.Address);
        assertEq(superUser.timeToAccept, block.timestamp + 7 days);
    }

    function test__unit_correct__rejectProposalSuperUser() external {
        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).proposeSuperUser(USER.Address);
        skip(3 days);
        RegistryEvvm(address(proxyRegistryEvvm)).rejectProposalSuperUser();
        vm.stopPrank();

        RegistryEvvm.AddressTypeProposal memory superUser = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getSuperUserData();

        assertEq(superUser.current, ADMIN.Address);
        assertEq(superUser.proposal, address(0));
        assertEq(superUser.timeToAccept, 0);
    }

    function test__unit_correct__acceptSuperUser() external {
        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).proposeSuperUser(USER.Address);
        vm.stopPrank();
        vm.startPrank(USER.Address);
        skip(8 days);
        RegistryEvvm(address(proxyRegistryEvvm)).acceptSuperUser();
        vm.stopPrank();
        RegistryEvvm.AddressTypeProposal memory superUser = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getSuperUserData();
        assertEq(superUser.current, USER.Address);
        assertEq(superUser.proposal, address(0));
        assertEq(superUser.timeToAccept, 0);
    }

    function test__unit_correct__proposeUpgrade() external {
        registryEvvmTestTwo = new RegistryEvvmTestTwo();
        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).proposeUpgrade(
            address(registryEvvmTestTwo)
        );
        vm.stopPrank();

        RegistryEvvm.AddressTypeProposal memory upgrade = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getUpgradeProposalData();

        assertEq(upgrade.current, address(0));
        assertEq(upgrade.proposal, address(registryEvvmTestTwo));
        assertEq(upgrade.timeToAccept, block.timestamp + 7 days);
    }

    function test__unit_correct__rejectProposalUpgrade() external {
        registryEvvmTestTwo = new RegistryEvvmTestTwo();
        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).proposeUpgrade(
            address(registryEvvmTestTwo)
        );
        skip(3 days);
        RegistryEvvm(address(proxyRegistryEvvm)).rejectProposalUpgrade();
        vm.stopPrank();

        RegistryEvvm.AddressTypeProposal memory upgrade = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getUpgradeProposalData();

        assertEq(upgrade.current, address(0));
        assertEq(upgrade.proposal, address(0));
        assertEq(upgrade.timeToAccept, 0);
    }

    function test__unit_correct__acceptUpgrade() external {
        registryEvvmTestTwo = new RegistryEvvmTestTwo();
        vm.startPrank(ADMIN.Address);
        RegistryEvvm(address(proxyRegistryEvvm)).proposeUpgrade(
            address(registryEvvmTestTwo)
        );
        vm.stopPrank();
        vm.startPrank(ADMIN.Address);
        skip(8 days);
        RegistryEvvm(address(proxyRegistryEvvm)).acceptProposalUpgrade();
        vm.stopPrank();
        RegistryEvvm.AddressTypeProposal memory upgrade = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getUpgradeProposalData();
        assertEq(upgrade.current, address(0));
        assertEq(upgrade.proposal, address(0));
        assertEq(upgrade.timeToAccept, 0);
        assertEq(RegistryEvvm(address(proxyRegistryEvvm)).getVersion(), 2);
    }
}
