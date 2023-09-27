// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {LendingPoolStorage} from "./LendingPoolStorage.sol";
import {LendingPoolAddressesProvider} from "./LendingPoolAddressesProvider.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "../logicLibraries/ReserveLogic.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ValidationLogic} from "../logicLibraries/ValidationLogic.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AToken} from "../tokens/AToken.sol";
import {StableDebtToken} from "../tokens/StableDebtToken.sol";
import {VariableDebtToken} from "../tokens/VariableDebtToken.sol";
import {AToken} from "../tokens/AToken.sol";
import {UserInformationLibrary} from "../informationLibraries/UserInformationLibrary.sol";
import {ReserveInformationLibrary} from "../informationLibraries/ReserveInformationLibrary.sol";
import {IPriceOracleGetter} from "../interfaces/IPriceOracleGetter.sol";

contract LendingPool is LendingPoolStorage {

    using ReserveLogic for DataTypes.ReserveData;
    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using UserInformationLibrary for DataTypes.UserConfigurationMap;

    event Deposit(address indexed reserve, address user, address indexed onBehalfOf, uint256 amount);
    event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);
    event Borrow(address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint256 borrowRateMode, uint256 borrowRate);
    event Repay(address indexed reserve, address indexed user, address indexed repayer, uint256 amount);
    event Swap(address indexed reserve, address indexed user, uint256 rateMode);
    event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);
    event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);
    event RebalanceStableBorrowRate(address indexed reserve, address indexed user);
    event FlashLoan(address indexed target, address indexed initiator, address indexed asset, uint256 amount, uint256 premium);
    event LiquidationCall( address indexed collateralAsset, address indexed debtAsset, address indexed user, uint256 debtToCover, uint256 liquidatedCollateralAmount, address liquidator, bool receiveAToken);
    event Paused();
    event Unpaused();

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

    // Steps to perform a deposit:
    //      1-Validate if the deposit can be executed (see validation logic)
    //      2-Update indexes
    //      3-Update interest rates
    //      4-Transfer the assets to the aToken address
    //      5-Mint aToken for the onBehalfOf corresponding to the amount deposited
    //      6-Emit the event
    function deposit(address asset, uint256 amount, address onBehalfOf) external whenNotPaused{
        DataTypes.ReserveData storage reserve = _reserves[asset];

        ValidationLogic.validateDeposit(reserve, amount);

        address aTokenAddress = reserve.aTokenAddress;

        reserve.updateIndexes();
        reserve.updateInterestRates(asset, aTokenAddress, amount, 0);

        IERC20(asset).transferFrom(msg.sender, aTokenAddress, amount);

        bool isFirstDeposit = AToken(aTokenAddress).mint(onBehalfOf, amount, reserve.liquidityIndex);

        if(isFirstDeposit){
            _usersConfig[onBehalfOf].setUsingAsCollateral(reserve.id, true);
            emit ReserveUsedAsCollateralEnabled(asset, onBehalfOf);
        }

        emit Deposit(asset, msg.sender, onBehalfOf, amount);
    }

    // Steps to perform a borrow:
    //      1-Validate if the borrow can be executed (see validation borrow)
    //      2-Update indexes
    //      3-Mint the amount of specified debt
    //      4-Update the reserve rates
    //      5-Transfer the borrowed tokens to the user
    //      6-Emit the event
    function borrow(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external whenNotPaused{
        DataTypes.ReserveData storage reserve = _reserves[asset];
        DataTypes.UserConfigurationMap storage userConfig = _usersConfig[onBehalfOf];

        address oracle = _addressesProvider.getAddress("PRICE_ORACLE");

        uint256 amountInETH = IPriceOracleGetter(oracle).getAssetPrice(asset) * amount / (10**reserve.configuration.getDecimals());

        ValidationLogic.validateBorrow(
            asset,
            reserve,
            onBehalfOf,
            amount,
            amountInETH,
            interestRateMode,
            _maxStableRateBorrowSizePercent,
            _reserves,
            userConfig,
            _reserveList,
            _reservesCount,
            oracle
        );

        reserve.updateIndexes();

        uint256 currentStableRate;
        bool isFirstBorrowing;

        if(DataTypes.InterestRateMode(interestRateMode) == DataTypes.InterestRateMode.STABLE){
            currentStableRate = reserve.currentStableBorrowRate;

            isFirstBorrowing = StableDebtToken(reserve.stableDebtTokenAddress).mint(
                msg.sender,
                onBehalfOf,
                amount,
                currentStableRate
            );
        } else {
            isFirstBorrowing = VariableDebtToken(reserve.variableDebtTokenAddress).mint(
                msg.sender,
                onBehalfOf,
                amount,
                reserve.variableBorrowIndex
            );
        }

        if(isFirstBorrowing){
            userConfig.setBorrowing(reserve.id, true);
        }

        reserve.updateInterestRates(
            asset,
            reserve.aTokenAddress,
            0,
            amount
        );

        AToken(reserve.aTokenAddress).transferUnderlyingTo(msg.sender, amount);

        emit Borrow(
            asset,
            msg.sender,
            onBehalfOf,
            amount,
            interestRateMode,
            DataTypes.InterestRateMode(interestRateMode) == DataTypes.InterestRateMode.STABLE
                ? currentStableRate
                : reserve.currentVariableBorrowRate
        );
    }

    // Steps to perform a withdraw:
    //      1-Validate if the withdraw can be executed (see validation withdraw)
    //      2-Update indexes
    //      3-Update the reserve rates
    //      4-Burn aTokens and send the underlying amount to receiver
    //      5-If the user burnt all his aTokens disable the asset borrowing
    //      6-Emit the event
    function withdraw(address asset, uint256 amount, address receiver) external whenNotPaused returns(uint256){
        DataTypes.ReserveData storage reserve = _reserves[asset];

        address aTokenAddress = reserve.aTokenAddress;
        uint256 userBalance = AToken(aTokenAddress).balanceOf(msg.sender);

        uint256 amountToWithdraw = amount == type(uint256).max
                                        ? userBalance
                                        : amount;
        
        ValidationLogic.validateWithdraw(
            asset,
            amountToWithdraw,
            userBalance,
            _reserves,
            _usersConfig[msg.sender],
            _reserveList,
            _reservesCount,
            _addressesProvider.getAddress("PRICE_ORACLE")
        );

        reserve.updateIndexes();

        reserve.updateInterestRates(asset, aTokenAddress, 0, amountToWithdraw);

        if(amountToWithdraw == userBalance){
            _usersConfig[msg.sender].setUsingAsCollateral(reserve.id, false);
            emit ReserveUsedAsCollateralDisabled(asset, msg.sender);
        }

        AToken(aTokenAddress).burn(msg.sender, receiver, amountToWithdraw, reserve.liquidityIndex);

        emit Withdraw(asset, msg.sender, receiver, amountToWithdraw);

        return amountToWithdraw;
    }

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external whenNotPaused returns(uint256){}

    function swapBorrowRateMode(address asset, uint256 rateMode) external whenNotPaused{}

    function rebalanceStableBorrowRate(address asset, address user) external whenNotPaused{}

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external whenNotPaused{}

    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external whenNotPaused{}

    function flashLoan(address receiverAddress, address[] calldata assets, uint256[] calldata amounts, uint256[] calldata modes, address onBehalfOf, bytes calldata params) external whenNotPaused{}

    function getReserveNormalizedVariableDebt(address asset) external view returns(uint256){
        return _reserves[asset].getNormalizedDebt();
    }

    function getReserveNormalizedIncome(address asset) external view returns(uint256){
        return _reserves[asset].getNormalizedIncome();
    }
}