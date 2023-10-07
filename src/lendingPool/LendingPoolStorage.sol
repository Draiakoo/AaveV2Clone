// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {LendingPoolAddressesProvider} from "./LendingPoolAddressesProvider.sol";
import {ReserveInformationLibrary} from "../informationLibraries/ReserveInformationLibrary.sol";
import {UserInformationLibrary} from "../informationLibraries/UserInformationLibrary.sol";

contract LendingPoolStorage{
    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using UserInformationLibrary for DataTypes.UserConfigurationMap;

    LendingPoolAddressesProvider internal _addressesProvider;

    mapping(address => DataTypes.ReserveData) internal _reserves;
    mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

    mapping(uint256 => address) internal _reserveList;

    uint256 internal _reservesCount;

    bool internal _paused;

    uint256 internal _maxStableRateBorrowSizePercent;

    uint256 internal _flashLoanPremiumTotal;

    uint256 internal _maxNumberOfReserves;

    address internal _owner;

    // Maximum percentage of debt to cover 50%
    uint256 internal constant LIQUIDATION_CLOSE_FACTOR_PERCENT = 5000;
}