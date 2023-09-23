// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {LendingPoolStorage} from "./LendingPoolStorage.sol";
import {LendingPoolAddressesProvider} from "./LendingPoolAddressesProvider.sol";
import {DataTypes} from "../types/DataTypes.sol";

contract LendingPool is LendingPoolStorage {

    constructor(address addressesProviderAddress){
        _addressesProvider = LendingPoolAddressesProvider(addressesProviderAddress);
        _maxStableRateBorrowSizePercent = 2500;
        _flashLoandPremiumTotal = 9;
        
        // 128 because user asset configurations only support up to 128 assets
        _maxNumberOfReserves = 128;
    }

    // Main functions a user can interact with
    // - Deposit
    // - Borrow
    // - Repay
    // - Withdraw
    // - Flashloan
    // - Liquidate a position
    // - Swap loan interest rate between stable and variable
    // - Enable and disable their deposits as collateral rebalance stable rate borrow positions

    function requireNotPaused() internal view{
        require(!_paused);
    }

    modifier whenNotPaused() {
        requireNotPaused();
        _;
    }

    function deposit(address asset, uint256 amount, address onBehalfOf) external whenNotPaused{}

    function borrow(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external whenNotPaused{}

    function withdraw(address asset, uint256 amount, address receiver) external whenNotPaused returns(uint256){}

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external whenNotPaused returns(uint256){}

    function swapBorrowRateMode(address asset, uint256 rateMode) external whenNotPaused{}

    function rebalanceStableBorrowRate(address asset, address user) external whenNotPaused{}

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external whenNotPaused{}

    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external whenNotPaused{}

    function flashLoad(address receiverAddress, address[] calldata assets, uint256[] calldata amounts, uint256[] calldata modes, address onBehalfOf, bytes calldata params) external whenNotPaused{}
}