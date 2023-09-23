// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {LendingPoolAddressesProvider} from "../../src/lendingPool/LendingPoolAddressesProvider.sol";

contract LendingPoolAddressesProviderTest is Test {

    address public owner = makeAddr("owner");
    address public normalUser = makeAddr("normalUser");

    LendingPoolAddressesProvider public addressesProvider;

    string public initialMarketName = "Market name example";

    function setUp() public {
        vm.prank(owner);
        addressesProvider = new LendingPoolAddressesProvider(initialMarketName);
    }

    function testGetMarketName() public {
        // A normal user can get the market name
        vm.prank(normalUser);
        assertEq(addressesProvider.getMarketName(), initialMarketName);

        // Owner can get the market name
        vm.prank(owner);
        assertEq(addressesProvider.getMarketName(), initialMarketName);
    }

    function testSetMarketName(string memory _marketName) public {
        // Owner can set the market name
        vm.prank(owner);
        addressesProvider.setMarketName(_marketName);
        assertEq(addressesProvider.getMarketName(), _marketName);

        // Normal user can NOT set the market name
        vm.prank(normalUser);
        vm.expectRevert();
        addressesProvider.setMarketName(_marketName);
    }

    function testGetAddress(bytes32 key) public {
        // A normal user can get any address
        vm.prank(normalUser);
        addressesProvider.getAddress(key);

        // Owner can get any address
        vm.prank(owner);
        addressesProvider.getAddress(key);
    }

    function testSetAddress(bytes32 key, address newAddress) public {
        // Owner can set any address
        vm.prank(owner);
        addressesProvider.setAddress(key, newAddress);
        assertEq(addressesProvider.getAddress(key), newAddress);

        // Normal user can NOT set any address
        vm.expectRevert();
        vm.prank(normalUser);
        addressesProvider.setAddress(key, newAddress);
    }

}