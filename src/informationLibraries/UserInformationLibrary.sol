// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";

library UserInformationLibrary{

    uint256 internal constant borrowingAnyMask = 0x5555555555555555555555555555555555555555555555555555555555555555;

    function requireValidIndex(uint256 assetIndex) internal pure {
        require(assetIndex < 128);
    }

    modifier validIndex(uint256 assetIndex){
        requireValidIndex(assetIndex);
        _;
    }

    function setBorrowing(DataTypes.UserConfigurationMap storage map, uint256 assetIndex, bool enableBorrow) internal validIndex(assetIndex) {
        map.data = (map.data & (~uint256(1) << assetIndex * 2)) | (uint256(enableBorrow ? 1 : 0) << assetIndex * 2);
    }

    function setUsingAsCollateral(DataTypes.UserConfigurationMap storage map, uint256 assetIndex, bool enableUseAsCollateral) internal validIndex(assetIndex) {
        map.data = (map.data & (~uint256(1) << (assetIndex * 2 + 1))) | (uint256(enableUseAsCollateral ? 1 : 0) << (assetIndex * 2 + 1));
    }

    function isUsingAsCollateralOrBorrowing(DataTypes.UserConfigurationMap memory map, uint256 assetIndex) internal pure validIndex(assetIndex) returns(bool){
        return (map.data >> (assetIndex * 2)) & 0x3 != 0;
    }

    function isBorrowing(DataTypes.UserConfigurationMap memory map, uint256 assetIndex) internal pure validIndex(assetIndex) returns(bool){
        return (map.data >> (assetIndex * 2)) & 0x1 != 0;
    }

    function isUsingAsCollateral(DataTypes.UserConfigurationMap memory map, uint256 assetIndex) internal pure validIndex(assetIndex) returns(bool){
        return (map.data >> (assetIndex * 2)) & 0x2 != 0;
    }

    function isBorrowingAny(DataTypes.UserConfigurationMap memory map) internal pure returns(bool){
        return map.data & borrowingAnyMask != 0;
    }

    function isEmpty(DataTypes.UserConfigurationMap memory map) internal pure returns(bool){
        return map.data == 0;
    }
}