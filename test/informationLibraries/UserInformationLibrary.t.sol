// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {UserInformationLibrary} from "../../src/informationLibraries/UserInformationLibrary.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";

contract ReserveInformationLibraryTest is Test {

    using UserInformationLibrary for DataTypes.UserConfigurationMap;

    DataTypes.UserConfigurationMap internal mapExample;

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ///////////////           Borrowing set/get function test           /////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testSetBorrowing(uint256 assetIndex, bool enableBorrow) public {
        vm.assume(assetIndex < 128);
        mapExample.setBorrowing(assetIndex, enableBorrow);
        DataTypes.UserConfigurationMap memory memoryMap = mapExample;
        assertEq(memoryMap.isBorrowing(assetIndex), enableBorrow);
    }

    function testSetBorrowingRevertAssetGreaterThan128() public {
        vm.expectRevert();
        mapExample.setBorrowing(128, true);
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    //////////           IsUsingAsCollateral set/get function test           ////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testSetIsUsingAsCollateral(uint256 assetIndex, bool enableUsingAsCollateral) public {
        vm.assume(assetIndex < 128);
        mapExample.setUsingAsCollateral(assetIndex, enableUsingAsCollateral);
        DataTypes.UserConfigurationMap memory memoryMap = mapExample;
        assertEq(memoryMap.isUsingAsCollateral(assetIndex), enableUsingAsCollateral);
    }

    function testSetIsUsingAsCollateralRevertAssetGreaterThan128() public {
        vm.expectRevert();
        mapExample.setUsingAsCollateral(128, true);
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////           isUsingAsCollateralOrBorrowing function test           //////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testIsUsingAsCollateralOrBorrowing(uint256 assetIndex) public {
        vm.assume(assetIndex < 128);

        // test for the 4 possible scenarios

        // Not using as collateral nor borrowing
        mapExample.setUsingAsCollateral(assetIndex, false);
        mapExample.setBorrowing(assetIndex, false);
        DataTypes.UserConfigurationMap memory memoryMap = mapExample;
        assertEq(memoryMap.isUsingAsCollateralOrBorrowing(assetIndex), false);

        // Not using as collateral but borrowing
        mapExample.setUsingAsCollateral(assetIndex, false);
        mapExample.setBorrowing(assetIndex, true);
        memoryMap = mapExample;
        assertEq(memoryMap.isUsingAsCollateralOrBorrowing(assetIndex), true);

        // Using as collateral but not borrowing
        mapExample.setUsingAsCollateral(assetIndex, true);
        mapExample.setBorrowing(assetIndex, false);
        memoryMap = mapExample;
        assertEq(memoryMap.isUsingAsCollateralOrBorrowing(assetIndex), true);

        // Both using as collateral and borrowing
        mapExample.setUsingAsCollateral(assetIndex, true);
        mapExample.setBorrowing(assetIndex, true);
        memoryMap = mapExample;
        assertEq(memoryMap.isUsingAsCollateralOrBorrowing(assetIndex), true);
    }

    function testIsUsingAsCollateralOrBorrowingRevertAssetGreaterThan128() public {
        DataTypes.UserConfigurationMap memory memoryMap = mapExample;
        vm.expectRevert();
        memoryMap.isUsingAsCollateralOrBorrowing(128);
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////           isBorrowingAny function test           //////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testIsBorrowingAny(uint256 assetIndex) public {
        vm.assume(assetIndex < 128);

        DataTypes.UserConfigurationMap memory memoryMap = mapExample;
        assertEq(memoryMap.isBorrowingAny(), false);

        mapExample.setUsingAsCollateral(assetIndex, true);
        memoryMap = mapExample;
        assertEq(memoryMap.isBorrowingAny(), false);

        mapExample.setBorrowing(assetIndex, true);
        memoryMap = mapExample;
        assertEq(memoryMap.isBorrowingAny(), true);
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////           isEmpty function test           //////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testIsEmpty(uint256 assetIndex) public {
        vm.assume(assetIndex < 128);

        DataTypes.UserConfigurationMap memory memoryMap = mapExample;
        assertEq(memoryMap.isEmpty(), true);

        mapExample.setBorrowing(assetIndex, true);
        memoryMap = mapExample;
        assertEq(memoryMap.isEmpty(), false);
    }

}