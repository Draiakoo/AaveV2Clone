// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {LendingPoolStorage} from "./LendingPoolStorage.sol";
import {LendingPoolAddressesProvider} from "./LendingPoolAddressesProvider.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "../logicLibraries/ReserveLogic.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ValidationLogic} from "../logicLibraries/ValidationLogic.sol";
import {GenericLogic} from "../logicLibraries/GenericLogic.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AToken} from "../tokens/AToken.sol";
import {StableDebtToken} from "../tokens/StableDebtToken.sol";
import {VariableDebtToken} from "../tokens/VariableDebtToken.sol";
import {AToken} from "../tokens/AToken.sol";
import {UserInformationLibrary} from "../informationLibraries/UserInformationLibrary.sol";
import {ReserveInformationLibrary} from "../informationLibraries/ReserveInformationLibrary.sol";
import {IPriceOracleGetter} from "../interfaces/IPriceOracleGetter.sol";
import {IFlashLoanReceiver} from "../interfaces/IFlashLoanReceiver.sol";
import {PercentageMath} from "../mathLibraries/PercentageMath.sol";


contract LendingPool is LendingPoolStorage {

    using ReserveLogic for DataTypes.ReserveData;
    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using UserInformationLibrary for DataTypes.UserConfigurationMap;
    using PercentageMath for uint256;

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
        _flashLoanPremiumTotal = 9;
        
        // 128 because user asset configurations only support up to 128 assets
        _maxNumberOfReserves = 128;

        _owner = msg.sender;
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
        require(!_paused, "protocol paused");
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

        _executeBorrow(
            ExecuteBorrowParams(
                asset,
                msg.sender,
                onBehalfOf,
                amount,
                interestRateMode,
                reserve.aTokenAddress,
                true
            )
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

    // Steps to perform a repay:
    //      1-Validate if the repay can be executed (see validation repay)
    //      2-Update indexes
    //      3-Burn the debt tokens
    //      4-Update the reserve rates
    //      5-Transfer the tokens from user to the aToken address
    //      6-Emit the event
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external whenNotPaused returns(uint256){
        DataTypes.ReserveData storage reserve = _reserves[asset];

        uint256 stableDebt = StableDebtToken(reserve.stableDebtTokenAddress).balanceOf(onBehalfOf);
        uint256 variableDebt = VariableDebtToken(reserve.variableDebtTokenAddress).balanceOf(onBehalfOf);

        DataTypes.InterestRateMode interestRateMode = DataTypes.InterestRateMode(rateMode);

        ValidationLogic.validateRepay(
            reserve,
            amount,
            interestRateMode,
            onBehalfOf,
            stableDebt,
            variableDebt
        );

        uint256 debtToRepay = interestRateMode == DataTypes.InterestRateMode.STABLE ? stableDebt : variableDebt;

        if(amount < debtToRepay){
            debtToRepay = amount;
        }

        reserve.updateIndexes();

        if(interestRateMode == DataTypes.InterestRateMode.STABLE){
            StableDebtToken(reserve.stableDebtTokenAddress).burn(onBehalfOf, debtToRepay);
        } else {
            VariableDebtToken(reserve.variableDebtTokenAddress).burn(onBehalfOf, debtToRepay, reserve.variableBorrowIndex);
        }

        address aToken = reserve.aTokenAddress;

        reserve.updateInterestRates(asset, aToken, debtToRepay, 0);

        if(stableDebt + variableDebt - debtToRepay == 0){
            _usersConfig[onBehalfOf].setBorrowing(reserve.id, false);
        }

        IERC20(asset).transferFrom(msg.sender, aToken, debtToRepay);
        
        emit Repay(asset, onBehalfOf, msg.sender, debtToRepay);

        return debtToRepay;
    }

    // Steps to perform a swap borrow rate mode:
    //      1-Validate if the rate swap can be executed (see validation swap borrow rate mode)
    //      2-Update indexes
    //      3-Burn all the current debt and immediately mint the same amount of the other debt type
    //      4-Update the reserve rates
    //      6-Emit the event
    function swapBorrowRateMode(address asset, uint256 rateMode) external whenNotPaused{
        DataTypes.ReserveData storage reserve = _reserves[asset];

        uint256 stableDebt = StableDebtToken(reserve.stableDebtTokenAddress).balanceOf(msg.sender);
        uint256 variableDebt = VariableDebtToken(reserve.variableDebtTokenAddress).balanceOf(msg.sender);

        DataTypes.InterestRateMode interestRateMode = DataTypes.InterestRateMode(rateMode);

        ValidationLogic.validateSwapRateMode(
            reserve,
            _usersConfig[msg.sender],
            stableDebt,
            variableDebt,
            interestRateMode
        );

        reserve.updateIndexes();

        if(interestRateMode == DataTypes.InterestRateMode.STABLE){
            StableDebtToken(reserve.stableDebtTokenAddress).burn(msg.sender, stableDebt);
            VariableDebtToken(reserve.variableDebtTokenAddress).mint(msg.sender, msg.sender, stableDebt, reserve.variableBorrowIndex);
        } else {
            StableDebtToken(reserve.stableDebtTokenAddress).mint(msg.sender, msg.sender, variableDebt, reserve.currentStableBorrowRate);
            VariableDebtToken(reserve.variableDebtTokenAddress).burn(msg.sender, variableDebt, reserve.variableBorrowIndex);   
        }

        reserve.updateInterestRates(asset, reserve.aTokenAddress, 0, 0);

        emit Swap(asset, msg.sender, rateMode);
    }

    // Steps to perform a swap stable debt mode:
    //      1-Validate if the swap can be executed (see validation swap stable rate mode)
    //      2-Update indexes
    //      3-Burn all the stable debt and immediately mint the same amount
    //      4-Update the reserve rates
    //      6-Emit the event
    function rebalanceStableBorrowRate(address asset, address user) external whenNotPaused {
        DataTypes.ReserveData storage reserve = _reserves[asset];

        uint256 userStableDebt = StableDebtToken(reserve.stableDebtTokenAddress).balanceOf(user);

        ValidationLogic.validateRebalanceStableBorrowRate(
            reserve,
            asset,
            IERC20(reserve.stableDebtTokenAddress),
            IERC20(reserve.variableDebtTokenAddress),
            reserve.aTokenAddress
        );

        reserve.updateIndexes();

        StableDebtToken(reserve.stableDebtTokenAddress).burn(user, userStableDebt);
        StableDebtToken(reserve.stableDebtTokenAddress).mint(user, user, userStableDebt, reserve.currentStableBorrowRate);

        reserve.updateInterestRates(asset, reserve.aTokenAddress, 0, 0);

        emit RebalanceStableBorrowRate(asset, user);
    }

    // Steps to perform a use reserve as collateral change:
    //      1-Validate if the change can be executed
    //      2-Change the parameter
    //      3-Emit the event
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external whenNotPaused {
        DataTypes.ReserveData storage reserve = _reserves[asset];
        DataTypes.UserConfigurationMap storage userConfig = _usersConfig[msg.sender];
        
        ValidationLogic.validateSetUseReserveAsCollateral(
            reserve,
            asset,
            useAsCollateral,
            _reserves,
            userConfig,
            _reserveList,
            _reservesCount,
            _addressesProvider.getAddress("PRICE_ORACLE")
        );

        userConfig.setUsingAsCollateral(reserve.id, useAsCollateral);

        if(useAsCollateral){
            emit ReserveUsedAsCollateralEnabled(asset, msg.sender);
        } else {
            emit ReserveUsedAsCollateralDisabled(asset, msg.sender);
        }
    }


    struct LiquidationCallLocalVars {
        uint256 userCollateralBalance;
        uint256 userStableDebt;
        uint256 userVariableDebt;
        uint256 maxLiquidatableDebt;
        uint256 actualDebtToLiquidate;
        uint256 liquidationRatio;
        uint256 maxAmountCollateralToLiquidate;
        uint256 userStableRate;
        uint256 maxCollateralToLiquidate;
        uint256 debtAmountNeeded;
        uint256 healthFactor;
        uint256 liquidatorPreviousATokenBalance;
        AToken collateralAtoken;
        bool isCollateralEnabled;
        DataTypes.InterestRateMode borrowRateMode;
    }


    // Steps to perform a liquidation call
    //      1-Validate the liquidation call in the current context
    //      2-Compute the maximum debt that the user can cover (50% of the total user debt)
    //      3-Compute the collateral that the user will liquidate and how much debt will he cover
    //      4-Check if there is enough collateral in the reserves to pay in case the liquidator wants the underlying asset
    //      5-Update the indexes
    //      6-Burn variable debt in first instance and stable debt as a secondary debt
    //      7-Update interest rates
    //      8-Transfer either the aToken or the underlying asset to the liquidator
    //      9-Transfer the debt to the aToken
    //      10-Emit the event
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external whenNotPaused {

        DataTypes.ReserveData storage collateral = _reserves[collateralAsset];
        DataTypes.ReserveData storage debt = _reserves[debtAsset];
        DataTypes.UserConfigurationMap storage userConfig = _usersConfig[user];

        LiquidationCallLocalVars memory vars;

        address oracle = _addressesProvider.getAddress("PRICE_ORACLE");

        ( , , , , vars.healthFactor) = GenericLogic.calculateUserAccountData(
            user,
            _reserves,
            userConfig,
            _reserveList,
            _reservesCount,
            oracle
        );

        vars.userStableDebt = IERC20(debt.stableDebtTokenAddress).balanceOf(user);
        vars.userVariableDebt = IERC20(debt.variableDebtTokenAddress).balanceOf(user);

        ValidationLogic.validateLiquidationCall(
            collateral,
            debt,
            userConfig,
            vars.healthFactor,
            vars.userStableDebt,
            vars.userVariableDebt
        );

        vars.maxLiquidatableDebt = (vars.userStableDebt + vars.userVariableDebt).percentMul(LIQUIDATION_CLOSE_FACTOR_PERCENT);

        vars.actualDebtToLiquidate = debtToCover > vars.maxLiquidatableDebt ? vars.maxLiquidatableDebt : debtToCover;

        (vars.maxCollateralToLiquidate, vars.debtAmountNeeded) = _calculateAvailableCollateralToLiquidate(
            collateral,
            debt,
            collateralAsset,
            debtAsset,
            vars.actualDebtToLiquidate,
            vars.userCollateralBalance
        );

        if(vars.debtAmountNeeded < vars.actualDebtToLiquidate){
            vars.actualDebtToLiquidate = vars.debtAmountNeeded;
        }

        if(!receiveAToken){
            uint256 currentAvailableCollateral = IERC20(collateralAsset).balanceOf(address(vars.collateralAtoken));
            require(currentAvailableCollateral > vars.maxCollateralToLiquidate);
        }

        debt.updateIndexes();

        if(vars.userVariableDebt >= vars.actualDebtToLiquidate){
            VariableDebtToken(debt.variableDebtTokenAddress).burn(
                user,
                vars.actualDebtToLiquidate,
                debt.variableBorrowIndex
            );
        } else {
            if(vars.userVariableDebt > 0){
                VariableDebtToken(debt.variableDebtTokenAddress).burn(
                    user,
                    vars.userVariableDebt,
                    debt.variableBorrowIndex
                );
            }
            StableDebtToken(debt.stableDebtTokenAddress).burn(
                user,
                vars.actualDebtToLiquidate - vars.userVariableDebt
            );
        }

        debt.updateInterestRates(
            debtAsset,
            debt.aTokenAddress,
            vars.actualDebtToLiquidate,
            0
        );

        if(receiveAToken){
            vars.liquidatorPreviousATokenBalance = IERC20(vars.collateralAtoken).balanceOf(msg.sender);
            vars.collateralAtoken.transferOnLiquidation(user, msg.sender, vars.maxCollateralToLiquidate);

            if(vars.liquidatorPreviousATokenBalance == 0){
                DataTypes.UserConfigurationMap storage liquidatorConfig = _usersConfig[msg.sender];
                liquidatorConfig.setUsingAsCollateral(collateral.id, true);

                emit ReserveUsedAsCollateralEnabled(collateralAsset, msg.sender);
            }
        } else {
            collateral.updateIndexes();
            collateral.updateInterestRates(
                collateralAsset,
                address(vars.collateralAtoken),
                0,
                vars.maxCollateralToLiquidate
            );

            vars.collateralAtoken.burn(
                user,
                msg.sender,
                vars.maxCollateralToLiquidate,
                collateral.liquidityIndex
            );
        }

        if(vars.maxCollateralToLiquidate == vars.userCollateralBalance){
            userConfig.setUsingAsCollateral(collateral.id, false);

            emit ReserveUsedAsCollateralDisabled(collateralAsset, user);
        }

        IERC20(debtAsset).transferFrom(
            msg.sender,
            debt.aTokenAddress,
            vars.actualDebtToLiquidate
        );

        emit LiquidationCall(
            collateralAsset,
            debtAsset,
            user,
            vars.actualDebtToLiquidate,
            vars.maxCollateralToLiquidate,
            msg.sender,
            receiveAToken
        );
    }


    struct FlashLoanLocalVars {
        IFlashLoanReceiver receiver;
        address oracle;
        uint256 i;
        address currentAsset;
        address currentATokenAddress;
        uint256 currentAmount;
        uint256 currentPremium;
        uint256 currentAmountPlusPremium;
        address debtToken;
    }


    // Steps to perform a flash loan:
    //      1-Validate if the arguments are valid to execute the flashloan
    //      2-Calculate the premium to pay for every requested asset
    //      3-Send the amount of each asset requested
    //      4-Call the function on the receiver contract
    //      5-Check if enough assets are allowed to move or open stable or 
    //        variable debt position correspondingly to the mode
    //      6-Emit an event for each asset
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params
    ) external whenNotPaused {
        FlashLoanLocalVars memory vars;

        ValidationLogic.validateFlashLoan(assets, amounts);

        vars.receiver = IFlashLoanReceiver(receiverAddress);

        uint256 length = assets.length;

        address[] memory aTokenAddress = new address[](length);
        uint256[] memory premiums = new uint256[](length);

        for(vars.i; vars.i < length; ){
            aTokenAddress[vars.i] = _reserves[assets[vars.i]].aTokenAddress;
            premiums[vars.i] = amounts[vars.i].percentMul(_flashLoanPremiumTotal);

            AToken(aTokenAddress[vars.i]).transferUnderlyingTo(receiverAddress, amounts[vars.i]);

            unchecked{
                ++vars.i;
            }
        }

        require(vars.receiver.executeOperation(assets, amounts, premiums, msg.sender, params), "Flash loan wrong return");

        for(vars.i = 0; vars.i < length; ){
            vars.currentAsset = assets[vars.i];
            vars.currentATokenAddress = aTokenAddress[vars.i];
            vars.currentAmount = amounts[vars.i];
            vars.currentPremium = premiums[vars.i];
            vars.currentAmountPlusPremium = vars.currentAmount + vars.currentPremium;

            if(DataTypes.InterestRateMode(modes[vars.i]) == DataTypes.InterestRateMode.NONE){
                _reserves[vars.currentAsset].updateIndexes();
                _reserves[vars.currentAsset].cumulateToLiquidityIndex(AToken(vars.currentATokenAddress).totalSupply(), vars.currentPremium);
                _reserves[vars.currentAsset].updateInterestRates(
                    vars.currentAsset,
                    vars.currentATokenAddress,
                    vars.currentAmountPlusPremium,
                    0
                );

                IERC20(vars.currentAsset).transferFrom(receiverAddress, vars.currentATokenAddress, vars.currentAmountPlusPremium);
            } else {
                _executeBorrow(
                    ExecuteBorrowParams(
                        vars.currentAsset,
                        msg.sender,
                        onBehalfOf,
                        vars.currentAmount,
                        modes[vars.i],
                        vars.currentATokenAddress,
                        false
                    )
                );
            }

            emit FlashLoan(
                receiverAddress,
                msg.sender,
                vars.currentAsset,
                vars.currentAmount,
                vars.currentPremium
            );
            
            unchecked{
                ++vars.i;
            }
        }
    }

    function getReserveNormalizedVariableDebt(address asset) external view returns(uint256){
        return _reserves[asset].getNormalizedDebt();
    }

    function getReserveNormalizedIncome(address asset) external view returns(uint256){
        return _reserves[asset].getNormalizedIncome();
    }

    struct ExecuteBorrowParams {
        address asset;
        address user;
        address onBehalfOf;
        uint256 amount;
        uint256 interestRateMode;
        address aTokenAddress;
        bool releaseUnderlying;
    }

    function _executeBorrow(ExecuteBorrowParams memory vars) internal {
        DataTypes.ReserveData storage reserve = _reserves[vars.asset];
        DataTypes.UserConfigurationMap storage userConfig = _usersConfig[vars.onBehalfOf];

        address oracle = _addressesProvider.getAddress("PRICE_ORACLE");

        uint256 amountInETH = IPriceOracleGetter(oracle).getAssetPrice(vars.asset) * vars.amount / (10**reserve.configuration.getDecimals());

        ValidationLogic.validateBorrow(
            vars.asset,
            reserve,
            vars.onBehalfOf,
            vars.amount,
            amountInETH,
            vars.interestRateMode,
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

        if(DataTypes.InterestRateMode(vars.interestRateMode) == DataTypes.InterestRateMode.STABLE){
            currentStableRate = reserve.currentStableBorrowRate;

            isFirstBorrowing = StableDebtToken(reserve.stableDebtTokenAddress).mint(
                vars.user,
                vars.onBehalfOf,
                vars.amount,
                currentStableRate
            );
        } else {
            isFirstBorrowing = VariableDebtToken(reserve.variableDebtTokenAddress).mint(
                vars.user,
                vars.onBehalfOf,
                vars.amount,
                reserve.variableBorrowIndex
            );
        }

        if(isFirstBorrowing){
            userConfig.setBorrowing(reserve.id, true);
        }

        reserve.updateInterestRates(
            vars.asset,
            vars.aTokenAddress,
            0,
            vars.releaseUnderlying ? vars.amount : 0
        );

        if(vars.releaseUnderlying){
            AToken(vars.aTokenAddress).transferUnderlyingTo(vars.user, vars.amount);
        }

        emit Borrow(
            vars.asset,
            vars.user,
            vars.onBehalfOf,
            vars.amount,
            vars.interestRateMode,
            DataTypes.InterestRateMode(vars.interestRateMode) == DataTypes.InterestRateMode.STABLE
                ? currentStableRate
                : reserve.currentVariableBorrowRate
        );
    }

    struct AvailableCollateralToLiquidateLocalVars {
        uint256 userCompoundedBorrowBalance;
        uint256 liquidationBonus;
        uint256 collateralPrice;
        uint256 debtAssetPrice;
        uint256 maxAmountCollateralToLiquidate;
        uint256 debtAssetDecimals;
        uint256 collateralDecimals;
    }
    function _calculateAvailableCollateralToLiquidate(
        DataTypes.ReserveData storage collateralReserve,
        DataTypes.ReserveData storage debtReserve,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover,
        uint256 userCollateralBalance
    ) internal view returns(uint256, uint256) {
        uint256 collateralAmount;
        uint256 debtAmountNeeded;

        IPriceOracleGetter oracle = IPriceOracleGetter(_addressesProvider.getAddress("PRICE_ORACLE"));

        AvailableCollateralToLiquidateLocalVars memory vars;

        vars.collateralPrice = oracle.getAssetPrice(collateralAsset);
        vars.debtAssetPrice = oracle.getAssetPrice(debtAsset);

        ( , , vars.liquidationBonus, vars.collateralDecimals, ) = collateralReserve.configuration.getParams();
        vars.debtAssetDecimals = debtReserve.configuration.getDecimals();

        vars.maxAmountCollateralToLiquidate = (vars.debtAssetPrice * debtToCover * (10**vars.collateralDecimals)).percentMul(vars.liquidationBonus) /
                                              (vars.collateralPrice * (10**vars.debtAssetDecimals));

        if(vars.maxAmountCollateralToLiquidate > userCollateralBalance) {
            collateralAmount = userCollateralBalance;
            debtAmountNeeded = ((vars.collateralPrice * collateralAmount * (10**vars.debtAssetPrice)) / 
                               (vars.debtAssetPrice * (10**vars.collateralDecimals)))
                               .percentDiv(vars.liquidationBonus);
        } else {
            collateralAmount = vars.maxAmountCollateralToLiquidate;
            debtAmountNeeded = debtToCover;
        }

        return(collateralAmount, debtAmountNeeded);
    }

    function batchAddReserves(AssetInitializationParams[] calldata assetsParams) public onlyOwner {
        uint256 length = assetsParams.length;
        for(uint i; i < length; ){
            _addReserveToList(assetsParams[i]);
            unchecked{
                ++i;
            }
        }
    }

    function _addReserveToList(
        AssetInitializationParams calldata params
    ) internal {
        uint256 reservesCount = _reservesCount;

        require(reservesCount < _maxNumberOfReserves, "max asset limit reached");

        bool reserveAlreadyAdded = _reserves[params.asset].id != 0 || _reserveList[0] == params.asset;

        if(!reserveAlreadyAdded) {
            _reserves[params.asset].id = uint8(reservesCount);
            _reserveList[reservesCount] = params.asset;

            _reserves[params.asset].configuration.setLtv(params.ltv);
            _reserves[params.asset].configuration.setLiquidationThreshold(params.liquidationThreshold);
            _reserves[params.asset].configuration.setLiquidationBonus(params.liquidationBonus);
            _reserves[params.asset].configuration.setDecimals(params.decimals);
            _reserves[params.asset].configuration.setActive(params.active);
            _reserves[params.asset].configuration.setFrozen(params.frozen);
            _reserves[params.asset].configuration.setBorrowingEnabled(params.borrowingEnabled);
            _reserves[params.asset].configuration.setStableRateBorrowingEnabled(params.stableRateBorrowingEnabled);
            _reserves[params.asset].configuration.setReserveFactor(params.reserveFactor);

            _reserves[params.asset].liquidityIndex = params.liquidityIndex;
            _reserves[params.asset].variableBorrowIndex = params.variableBorrowIndex;
            _reserves[params.asset].currentLiquidityRate = params.currentLiquidityRate;
            _reserves[params.asset].currentVariableBorrowRate = params.currentVariableBorrowRate;
            _reserves[params.asset].currentStableBorrowRate = params.currentStableBorrowRate;

            _reserves[params.asset].aTokenAddress = params.aTokenAddress;
            _reserves[params.asset].stableDebtTokenAddress = params.stableDebtTokenAddress;
            _reserves[params.asset].variableDebtTokenAddress = params.variableDebtTokenAddress;

            _reserves[params.asset].lastUpdateTimestamp = uint40(block.timestamp);
            _reserves[params.asset].interestRateStrategyAddress = params.interestRateStrategyAddress;

            _reservesCount++;
        }   
    }

    modifier onlyOwner {
       require(msg.sender == _owner, "not authorized");
        _;
    }
}

struct AssetInitializationParams {
        address asset;
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        uint8 decimals;
        bool active;
        bool frozen;
        bool borrowingEnabled;
        bool stableRateBorrowingEnabled;
        uint16 reserveFactor;

        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;

        address interestRateStrategyAddress;
}