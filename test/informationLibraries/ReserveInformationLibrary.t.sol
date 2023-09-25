// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {ReserveInformationLibrary} from "../../src/informationLibraries/ReserveInformationLibrary.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";

contract ReserveInformationLibraryTest is Test {

    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;

    DataTypes.ReserveConfigurationMap internal mapExample;

    uint8 constant internal thresholdByteOffset = 16;
    uint8 constant internal liquidationBonusByteOffset = 32;
    uint8 constant internal decimalsByteOffset = 48;
    uint8 constant internal activeBitByteOffset = 56;
    uint8 constant internal freezeBitByteOffset = 57;
    uint8 constant internal borrowingEnabledByteOffset = 58;
    uint8 constant internal stableRateBorrowingEnabledByteOffset = 59;
    uint8 constant internal reserveFactorByteOffset = 64;

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    //////////////////           LTV set/get function test           ////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetLtv(uint256 ltv) public {
        vm.assume(ltv <= type(uint16).max);
        mapExample.setLtv(ltv);
        assertEq(mapExample.getLtv(), ltv);
    }

    function testSetLtv(uint256 ltv) public {
        vm.assume(ltv <= type(uint16).max);
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000;
        mapExample.data = otherBits;
        mapExample.setLtv(ltv);
        assertEq(mapExample.getLtv(), ltv);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000 + ltv
        );
    }

    function testSetLtvTooLarge() public {
        // Does not revert with max uint16
        mapExample.setLtv(type(uint16).max);

        // But reverts with max uint16 + 1
        vm.expectRevert();
        mapExample.setLtv(type(uint16).max + 1);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    //////////           LiquidationThreshold set/get function test           ///////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetLiquidationThreshold(uint256 liquidityThreshold) public {
        vm.assume(liquidityThreshold <= type(uint16).max);
        mapExample.setLiquidationThreshold(liquidityThreshold);
        assertEq(mapExample.getLiquidationThreshold(), liquidityThreshold);
    }

    function testSetLiquidationThreshold(uint256 liquidityThreshold) public {
        vm.assume(liquidityThreshold <= type(uint16).max);
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000_0f0f;
        mapExample.data = otherBits;
        mapExample.setLiquidationThreshold(liquidityThreshold);
        assertEq(mapExample.getLiquidationThreshold(), liquidityThreshold);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000_0f0f + (liquidityThreshold << thresholdByteOffset)
        );
    }

    function testSetLiquidationThresholdTooLarge() public {
        // Does not revert with max uint16
        mapExample.setLiquidationThreshold(type(uint16).max);

        // But reverts with max uint16 + 1
        vm.expectRevert();
        mapExample.setLiquidationThreshold(type(uint16).max + 1);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////           LiquidationBonus set/get function test           /////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetLiquidationBonus(uint256 liquidationBonus) public {
        vm.assume(liquidationBonus <= type(uint16).max);
        mapExample.setLiquidationBonus(liquidationBonus);
        assertEq(mapExample.getLiquidationBonus(), liquidationBonus);
    }

    function testSetLiquidationBonus(uint256 liquidationBonus) public {
        vm.assume(liquidationBonus <= type(uint16).max);
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000_0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setLiquidationBonus(liquidationBonus);
        assertEq(mapExample.getLiquidationBonus(), liquidationBonus);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000_0f0f0f0f + (liquidationBonus << liquidationBonusByteOffset)
        );
    }

    function testSetLiquidationBonusTooLarge() public {
        // Does not revert with max uint16
        mapExample.setLiquidationBonus(type(uint16).max);

        // But reverts with max uint16 + 1
        vm.expectRevert();
        mapExample.setLiquidationBonus(type(uint16).max + 1);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////           Decimals set/get function test           /////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetDecimals(uint256 decimals) public {
        vm.assume(decimals <= type(uint8).max);
        mapExample.setDecimals(decimals);
        assertEq(mapExample.getDecimals(), decimals);
    }

    function testSetDecimals(uint256 decimals) public {
        vm.assume(decimals <= type(uint8).max);
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_00_0f0f0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setDecimals(decimals);
        assertEq(mapExample.getDecimals(), decimals);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_00_0f0f0f0f0f0f + (decimals << decimalsByteOffset)
        );
    }

    function testSetDecimalsTooLarge() public {
        // Does not revert with max uint16
        mapExample.setDecimals(type(uint8).max);

        // But reverts with max uint16 + 1
        vm.expectRevert();
        mapExample.setDecimals(type(uint8).max + 1);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////           Active bit set/get function test           ///////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetActive(bool active) public {
        mapExample.setActive(active);
        assertEq(mapExample.getActive(), active);
    }

    function testSetActive(bool active) public {
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setActive(active);
        assertEq(mapExample.getActive(), active);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f + (uint256(active ? 1 : 0) << activeBitByteOffset)
        );
    }

    
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////           Freeze bit set/get function test           ///////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetFreeze(bool frozen) public {
        mapExample.setFrozen(frozen);
        assertEq(mapExample.getFrozen(), frozen);
    }

    function testSetFreeze(bool frozen) public {
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setFrozen(frozen);
        assertEq(mapExample.getFrozen(), frozen);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f + (uint256(frozen ? 1 : 0) << freezeBitByteOffset)
        );
    }

    
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////           Borrowing enabled bit set/get function test           ///////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetBorrowingEnabled(bool enable) public {
        mapExample.setBorrowingEnabled(enable);
        assertEq(mapExample.getBorrowingEnabled(), enable);
    }

    function testSetBorrowingEnabled(bool enable) public {
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setBorrowingEnabled(enable);
        assertEq(mapExample.getBorrowingEnabled(), enable);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f + (uint256(enable ? 1 : 0) << borrowingEnabledByteOffset)
        );
    }

    
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////           Stable Rate Borrowing enabled bit set/get function test           ////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetStableRateBorrowingEnabled(bool enable) public {
        mapExample.setStableRateBorrowingEnabled(enable);
        assertEq(mapExample.getStableRateBorrowingEnabled(), enable);
    }

    function testSetStableRateBorrowingEnabled(bool enable) public {
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setStableRateBorrowingEnabled(enable);
        assertEq(mapExample.getStableRateBorrowingEnabled(), enable);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0_0_0f0f0f0f0f0f0f + (uint256(enable ? 1 : 0) << stableRateBorrowingEnabledByteOffset)
        );
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////           Reserve factor set/get function test           //////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetReserveFactor(uint256 reserveFactor) public {
        vm.assume(reserveFactor <= type(uint16).max);
        mapExample.setReserveFactor(reserveFactor);
        assertEq(mapExample.getReserveFactor(), reserveFactor);
    }

    function testSetReserveFactor(uint256 reserveFactor) public {
        vm.assume(reserveFactor <= type(uint16).max);
        uint256 otherBits = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000_0f0f0f0f0f0f0f0f;
        mapExample.data = otherBits;
        mapExample.setReserveFactor(reserveFactor);
        assertEq(mapExample.getReserveFactor(), reserveFactor);
        assertEq(
            mapExample.data,
            0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f_0000_0f0f0f0f0f0f0f0f + (reserveFactor << reserveFactorByteOffset)
        );
    }

    function testSetReserveFactorTooLarge() public {
        // Does not revert with max uint16
        mapExample.setReserveFactor(type(uint16).max);

        // But reverts with max uint16 + 1
        vm.expectRevert();
        mapExample.setReserveFactor(type(uint16).max + 1);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////           GetFlags function test           /////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetFlags(bool active, bool frozen, bool borrowingEnable, bool stableRateBorrowingEnable) public {
        mapExample.setActive(active);
        mapExample.setFrozen(frozen);
        mapExample.setBorrowingEnabled(borrowingEnable);
        mapExample.setStableRateBorrowingEnabled(stableRateBorrowingEnable);

        (bool activeRead, bool frozenRead, bool borrowingEnabledRead, bool stableRateBorrowingEnabledRead) = mapExample.getFlags();

        assertEq(active, activeRead);
        assertEq(frozen, frozenRead);
        assertEq(borrowingEnable, borrowingEnabledRead);
        assertEq(stableRateBorrowingEnable, stableRateBorrowingEnabledRead);
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////           GetParams function test           ////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetParams(uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 decimals, uint256 reserveFactor) public {
        vm.assume(ltv <= type(uint16).max);
        vm.assume(liquidationThreshold <= type(uint16).max);
        vm.assume(liquidationBonus <= type(uint16).max);
        vm.assume(decimals <= type(uint8).max);
        vm.assume(reserveFactor <= type(uint16).max);
        
        mapExample.setLtv(ltv);
        mapExample.setLiquidationThreshold(liquidationThreshold);
        mapExample.setLiquidationBonus(liquidationBonus);
        mapExample.setDecimals(decimals);
        mapExample.setReserveFactor(reserveFactor);

        (uint256 ltvRead, uint256 liquidationThresholdRead, uint256 liquidationBonusRead, uint256 decimalsRead, uint256 reserveFactorRead) = mapExample.getParams();

        assertEq(ltv, ltvRead);
        assertEq(liquidationThreshold, liquidationThresholdRead);
        assertEq(liquidationBonus, liquidationBonusRead);
        assertEq(decimals, decimalsRead);
        assertEq(reserveFactor, reserveFactorRead);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////           GetFlagsMemory function test           //////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetFlagsMemory(bool active, bool frozen, bool borrowingEnable, bool stableRateBorrowingEnable) public {
        mapExample.setActive(active);
        mapExample.setFrozen(frozen);
        mapExample.setBorrowingEnabled(borrowingEnable);
        mapExample.setStableRateBorrowingEnabled(stableRateBorrowingEnable);

        DataTypes.ReserveConfigurationMap memory memoryMap = mapExample;

        (bool activeRead, bool frozenRead, bool borrowingEnabledRead, bool stableRateBorrowingEnabledRead) = memoryMap.getFlagsMemory();

        assertEq(active, activeRead);
        assertEq(frozen, frozenRead);
        assertEq(borrowingEnable, borrowingEnabledRead);
        assertEq(stableRateBorrowingEnable, stableRateBorrowingEnabledRead);
    }


    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////           GetMemoryParams function test           /////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    function testGetMemoryParams(uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 decimals, uint256 reserveFactor) public {
        vm.assume(ltv <= type(uint16).max);
        vm.assume(liquidationThreshold <= type(uint16).max);
        vm.assume(liquidationBonus <= type(uint16).max);
        vm.assume(decimals <= type(uint8).max);
        vm.assume(reserveFactor <= type(uint16).max);
        
        mapExample.setLtv(ltv);
        mapExample.setLiquidationThreshold(liquidationThreshold);
        mapExample.setLiquidationBonus(liquidationBonus);
        mapExample.setDecimals(decimals);
        mapExample.setReserveFactor(reserveFactor);

        DataTypes.ReserveConfigurationMap memory memoryMap = mapExample;

        (uint256 ltvRead, uint256 liquidationThresholdRead, uint256 liquidationBonusRead, uint256 decimalsRead, uint256 reserveFactorRead) = memoryMap.getParamsMemory();

        assertEq(ltv, ltvRead);
        assertEq(liquidationThreshold, liquidationThresholdRead);
        assertEq(liquidationBonus, liquidationBonusRead);
        assertEq(decimals, decimalsRead);
        assertEq(reserveFactor, reserveFactorRead);
    }
}