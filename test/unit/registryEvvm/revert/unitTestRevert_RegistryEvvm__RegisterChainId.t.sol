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

contract unitTestRevert_RegistryEvvm__RegisterChainId is Test, Constants {
    RegistryEvvm registryEvvm;
    RegistryEvvmTestTwo registryEvvmTestTwo;
    ERC1967Proxy proxyRegistryEvvm;

    AccountData USER = WILDCARD_USER;

    function setUp() public {
        registryEvvm = new RegistryEvvm();
        proxyRegistryEvvm = new ERC1967Proxy(address(registryEvvm), "");

        RegistryEvvm(address(proxyRegistryEvvm)).initialize(ADMIN.Address);
    }

    function test__unit_revert__registerChainId__InvalidUser() external {
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = 111555111;
        chainIds[1] = 222555222;
        chainIds[2] = 333555333;

        vm.startPrank(USER.Address);
        vm.expectRevert(RegistryEvvm.InvalidUser.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).registerChainId(chainIds);
        vm.stopPrank();
    }

    function test__unit_revert__registerChainId__InvalidInput() external {
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = 0;
        chainIds[1] = 222555222;
        chainIds[2] = 333555333;

        vm.startPrank(ADMIN.Address);
        vm.expectRevert(RegistryEvvm.InvalidInput.selector);
        RegistryEvvm(address(proxyRegistryEvvm)).registerChainId(chainIds);
        vm.stopPrank();
    }
}
