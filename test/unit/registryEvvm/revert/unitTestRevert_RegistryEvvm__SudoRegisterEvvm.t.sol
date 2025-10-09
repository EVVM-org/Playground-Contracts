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

contract unitTestRevert_RegistryEvvm__SudoRegisterEvvm is Test, Constants {
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

    function test__unit_revert__CorrectDeployment() external {
        assertEq(RegistryEvvm(address(proxyRegistryEvvm)).getVersion(), 1);
    }

    function test__unit_revert__SudoRegisterEvvm__InvalidInput()
        external
        prepareRegisterChainId
    {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert(RegistryEvvm.InvalidInput.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).sudoRegisterEvvm(
            0,
            111555111,
            address(234)
        );
        vm.stopPrank();

        RegistryEvvm.Metadata memory metadataOne = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(0);
        assertEq(metadataOne.chainId, 0);
        assertEq(metadataOne.evvmAddress, address(0));

        ////////////////////////////////////////////////////////////////////

        vm.startPrank(ADMIN.Address);
        vm.expectRevert(RegistryEvvm.InvalidInput.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).sudoRegisterEvvm(
            1000,
            111555111,
            address(234)
        );
        vm.stopPrank();

        RegistryEvvm.Metadata memory metadataTwo = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(1000);
        assertEq(metadataTwo.chainId, 0);
        assertEq(metadataTwo.evvmAddress, address(0));

        ////////////////////////////////////////////////////////////////////

        vm.startPrank(ADMIN.Address);
        vm.expectRevert(RegistryEvvm.InvalidInput.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).sudoRegisterEvvm(
            69,
            0,
            address(234)
        );
        vm.stopPrank();

        RegistryEvvm.Metadata memory metadataThree = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(69);
        assertEq(metadataThree.chainId, 0);
        assertEq(metadataThree.evvmAddress, address(0));

        ////////////////////////////////////////////////////////////////////

        vm.startPrank(ADMIN.Address);
        vm.expectRevert(RegistryEvvm.InvalidInput.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).sudoRegisterEvvm(
            69,
            111555111,
            address(0)
        );
        vm.stopPrank();

        RegistryEvvm.Metadata memory metadataFour = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(69);
        assertEq(metadataFour.chainId, 0);
        assertEq(metadataFour.evvmAddress, address(0));
    }

    function test__unit_revert__SudoRegisterEvvm__AlreadyRegistered()
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
        vm.expectRevert(RegistryEvvm.AlreadyRegistered.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).sudoRegisterEvvm(
            420,
            111555111,
            address(234)
        );
        vm.stopPrank();

        RegistryEvvm.Metadata memory metadataTwo = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(420);
        assertEq(metadataTwo.chainId, 0);
        assertEq(metadataTwo.evvmAddress, address(0));
    }

    function test__unit_revert__SudoRegisterEvvm__ChainIdNotRegistered()
        external
        prepareRegisterChainId
    {
        vm.startPrank(ADMIN.Address);
        vm.expectRevert(RegistryEvvm.ChainIdNotRegistered.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).sudoRegisterEvvm(
            69,
            777,
            address(234)
        );
        vm.stopPrank();

        RegistryEvvm.Metadata memory metadataOne = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(69);
        assertEq(metadataOne.chainId, 0);
        assertEq(metadataOne.evvmAddress, address(0));
    }

    function test__unit_revert__SudoRegisterEvvm__InvalidUser()
        external
        prepareRegisterChainId
    {
        vm.startPrank(USER.Address);
        vm.expectRevert(RegistryEvvm.InvalidUser.selector);
        RegistryEvvm(address(proxyRegistryEvvm))
            .sudoRegisterEvvm(69, 111555111, address(234));
        vm.stopPrank();


        RegistryEvvm.Metadata memory metadataOne = RegistryEvvm(
            address(proxyRegistryEvvm)
        ).getEvvmIdMetadata(69);
        assertEq(metadataOne.chainId, 0);
        assertEq(metadataOne.evvmAddress, address(0));
    }
}
