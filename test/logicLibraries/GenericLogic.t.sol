// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {GenericLogic} from "../../src/logicLibraries/GenericLogic.sol";
import {DataTypes} from "../../src/types/DataTypes.sol";
import {ReserveInformationLibrary} from "../../src/informationLibraries/ReserveInformationLibrary.sol";
import {UserInformationLibrary} from "../../src/informationLibraries/UserInformationLibrary.sol";

contract GenericLogicTest is Test {

    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using UserInformationLibrary for DataTypes.UserConfigurationMap;

    mapping(address => DataTypes.ReserveData) public reserves;

    function setUp() public {

    }
}