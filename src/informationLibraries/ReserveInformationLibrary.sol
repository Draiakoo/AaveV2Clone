// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";

library ReserveInformationLibrary {

    // X & F = X
    // X & 0 = 0
    // X | F = F
    // X | 0 = X

    uint256 constant internal ltvMask =                             0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000;
    uint256 constant internal thresholdMask =                       0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000ffff;
    uint256 constant internal liquidationBonusMask =                0xffffffffffffffffffffffffffffffffffffffffffffffffffff0000ffffffff;
    uint256 constant internal decimalsMask =                        0xffffffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffff;
    uint256 constant internal activeBitMask =                       0xfffffffffffffffffffffffffffffffffffffffffffffffffeffffffffffffff;
    uint256 constant internal freezeBitMask =                       0xfffffffffffffffffffffffffffffffffffffffffffffffffdffffffffffffff;
    uint256 constant internal borrowingEnabledMask =                0xfffffffffffffffffffffffffffffffffffffffffffffffffbffffffffffffff;
    uint256 constant internal stableRateBorrowingEnabledMask =      0xfffffffffffffffffffffffffffffffffffffffffffffffff7ffffffffffffff;
    uint256 constant internal reserveFactorMask =                   0xffffffffffffffffffffffffffffffffffffffffffff0000ffffffffffffffff;

    uint8 constant internal thresholdByteOffset = 16;
    uint8 constant internal liquidationBonusByteOffset = 32;
    uint8 constant internal decimalsByteOffset = 48;
    uint8 constant internal activeBitByteOffset = 56;
    uint8 constant internal freezeBitByteOffset = 57;
    uint8 constant internal borrowingEnabledByteOffset = 58;
    uint8 constant internal stableRateBorrowingEnabledByteOffset = 59;
    uint8 constant internal reserveFactorByteOffset = 64;

    // function to set the ltv value in the reserve configuration
    function setLtv(DataTypes.ReserveConfigurationMap storage map, uint256 ltv) internal
    {
        require(ltv <= type(uint16).max);
        map.data = (map.data & ltvMask) | ltv;
    }

    // function to obtain the ltv value in the reserve configuration
    function getLtv(DataTypes.ReserveConfigurationMap storage map) internal view returns (uint256 ltv)
    {
        ltv = map.data & ~ltvMask;
    }




    // function to set the liquidation threshold value in the reserve configuration
    function setLiquidationThreshold(DataTypes.ReserveConfigurationMap storage map, uint256 liquidityThreshold) internal
    {
        require(liquidityThreshold <= type(uint16).max);
        map.data = (map.data & thresholdMask) | (liquidityThreshold << thresholdByteOffset);
    }

    // function to set the liquidation threshold value in the reserve configuration
    function getLiquidationThreshold(DataTypes.ReserveConfigurationMap storage map) internal view returns (uint256 liquidationThreshold)
    {
        liquidationThreshold = (map.data & ~thresholdMask) >> thresholdByteOffset;
    }




    // function to set the liquidation bonus value in the reserve configuration
    function setLiquidationBonus(DataTypes.ReserveConfigurationMap storage map, uint256 liquidationBonus) internal
    {
        require(liquidationBonus <= type(uint16).max);
        map.data = (map.data & liquidationBonusMask) | (liquidationBonus << liquidationBonusByteOffset);
    }

    // function to get the liquidation bonus value in the reserve configuration
    function getLiquidationBonus(DataTypes.ReserveConfigurationMap storage map) internal view returns (uint256 liquidationBonus)
    {
        liquidationBonus = (map.data & ~liquidationBonusMask) >> liquidationBonusByteOffset;
    }




    // function to set the decimals value in the reserve configuration
    function setDecimals(DataTypes.ReserveConfigurationMap storage map, uint256 decimals) internal
    {
        require(decimals <= type(uint8).max);
        map.data = (map.data & decimalsMask) | (decimals << decimalsByteOffset);
    }

    // function to get the decimals value in the reserve configuration
    function getDecimals(DataTypes.ReserveConfigurationMap storage map) internal view returns (uint256 decimals)
    {
        decimals = (map.data & ~decimalsMask) >> decimalsByteOffset;
    }




    // function to set the active bit in the reserve configuration
    function setActive(DataTypes.ReserveConfigurationMap storage map, bool active) internal {
        map.data = (map.data & activeBitMask) | (uint256(active ? 1 : 0) << activeBitByteOffset);
    }

    // function to get the active bit in the reserve configuration
    function getActive(DataTypes.ReserveConfigurationMap storage map) internal view returns (bool active) {
        active = (map.data & ~activeBitMask) != 0;
    }




    // function to set the frozen bit in the reserve configuration
    function setFrozen(DataTypes.ReserveConfigurationMap storage map, bool frozen) internal {
        map.data = (map.data & freezeBitMask) | (uint256(frozen ? 1 : 0) << freezeBitByteOffset);
    }

    // function to get the active bit in the reserve configuration
    function getFrozen(DataTypes.ReserveConfigurationMap storage map) internal view returns (bool frozen) {
        frozen = (map.data & ~freezeBitMask) != 0;
    }




    // function to set the borrowingEnabled bit in the reserve configuration
    function setBorrowingEnabled(DataTypes.ReserveConfigurationMap storage map, bool enabled) internal
    {
        map.data = (map.data & borrowingEnabledMask) | (uint256(enabled ? 1 : 0) << borrowingEnabledByteOffset);
    }

    // function to get the borrowingEnabled bit in the reserve configuration
    function getBorrowingEnabled(DataTypes.ReserveConfigurationMap storage map) internal view returns (bool enabled)
    {
        enabled = (map.data & ~borrowingEnabledMask) != 0;
    }




    // function to set the stableRateBorrowingEnabled bit in the reserve configuration
    function setStableRateBorrowingEnabled(DataTypes.ReserveConfigurationMap storage map, bool enabled) internal 
    {
        map.data = (map.data & stableRateBorrowingEnabledMask) | (uint256(enabled ? 1 : 0) << stableRateBorrowingEnabledByteOffset);
    }

    // function to get the stableRateBorrowingEnabled bit in the reserve configuration
    function getStableRateBorrowingEnabled(DataTypes.ReserveConfigurationMap storage map) internal view returns (bool enabled)
    {
        enabled = (map.data & ~stableRateBorrowingEnabledMask) != 0;
    }




    // function to set the reserveFactor value in the reserve configuration
    function setReserveFactor(DataTypes.ReserveConfigurationMap storage map, uint256 reserveFactor) internal
    {
        require(reserveFactor <= type(uint16).max);
        map.data = (map.data & reserveFactorMask) | (reserveFactor << reserveFactorByteOffset);
    }

    // function to get the reserveFactor value in the reserve configuration
    function getReserveFactor(DataTypes.ReserveConfigurationMap storage map) internal view returns (uint256 reserveFactor)
    {
        reserveFactor = (map.data & ~reserveFactorMask) >> reserveFactorByteOffset;
    }







    // function to get the 4 single bits isActive, isFrozen, borrowingEnabled and stableRateBorrowingEnabled
    function getFlags(DataTypes.ReserveConfigurationMap storage map) internal pure 
    returns (
        bool isActive,
        bool isFrozen,
        bool borrowingEnabled,
        bool stableRateBorrowingEnabled
    )
    {
        DataTypes.ReserveConfigurationMap memory memoryMap = map;

        isActive = (memoryMap.data & ~activeBitMask) != 0;
        isFrozen = (memoryMap.data & ~freezeBitMask) != 0;
        borrowingEnabled = (memoryMap.data & ~borrowingEnabledMask) != 0;
        stableRateBorrowingEnabled = (memoryMap.data & ~stableRateBorrowingEnabledMask) != 0;
    }

    // function to get the other 5 parameters ltv, liquidationThreshold, liquidationBonus, decimals and reserveFactor
    function getParams(DataTypes.ReserveConfigurationMap storage map) internal pure
    returns (
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 decimals,
        uint256 reserveFactor
        )
    {
        DataTypes.ReserveConfigurationMap memory memoryMap = map;

        ltv = memoryMap.data & ~ltvMask;
        liquidationThreshold = (memoryMap.data & ~thresholdMask) >> thresholdByteOffset;
        liquidationBonus = (memoryMap.data & ~liquidationBonusMask) >> liquidationBonusByteOffset;
        decimals = (memoryMap.data & ~decimalsMask) >> decimalsByteOffset;
        reserveFactor = (memoryMap.data & ~reserveFactorMask) >> reserveFactorByteOffset;
    }

    
    // same function as getFlags but getting the configuration map in a memory object
    function getFlagsMemory(DataTypes.ReserveConfigurationMap memory map) internal pure
    returns (
        bool isActive,
        bool isFrozen,
        bool borrowingEnabled,
        bool stableRateBorrowingEnabled
    )
    {
        isActive = (map.data & ~activeBitMask) != 0;
        isFrozen = (map.data & ~freezeBitMask) != 0;
        borrowingEnabled = (map.data & ~borrowingEnabledMask) != 0;
        stableRateBorrowingEnabled = (map.data & ~stableRateBorrowingEnabledMask) != 0;
    }

    // same function as getParams but getting the configuration map in a memory object
    function getParamsMemory(DataTypes.ReserveConfigurationMap memory map) internal pure
    returns (
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 decimals,
        uint256 reserveFactor
        )
    {
        ltv = map.data & ~ltvMask;
        liquidationThreshold = (map.data & ~thresholdMask) >> thresholdByteOffset;
        liquidationBonus = (map.data & ~liquidationBonusMask) >> liquidationBonusByteOffset;
        decimals = (map.data & ~decimalsMask) >> decimalsByteOffset;
        reserveFactor = (map.data & ~reserveFactorMask) >> reserveFactorByteOffset;
    }
}