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

import {Constants} from "test/Constants.sol";

import {Staking} from "@EVVM/playground/contracts/staking/Staking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RegistryEvvm} from "@EVVM/playground/contracts/registryEvvm/RegistryEvvm.sol";

contract unitTestCorrect_RegistryEvvm is Test, Constants {
    RegistryEvvm registryEvvm;
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

    function test__unit_correct__registerChainId()
        external
    {
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
}
