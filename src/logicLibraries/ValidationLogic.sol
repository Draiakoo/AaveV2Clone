// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {ReserveInformationLibrary} from "../informationLibraries/ReserveInformationLibrary.sol";
import {UserInformationLibrary} from "../informationLibraries/UserInformationLibrary.sol";
import {GenericLogic} from "../logicLibraries/GenericLogic.sol";
import {PercentageMath} from "../mathLibraries/PercentageMath.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";
import {AToken} from "../tokens/AToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DefaultReserveInterestRateStrategy} from "../lendingPool/DefaultReserveInterestRateStrategy.sol";

library ValidationLogic {

    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using UserInformationLibrary for DataTypes.UserConfigurationMap;
    using PercentageMath for uint256;
    using WadRayMath for uint256;

    uint256 public constant REBALANCE_UP_LIQUIDITY_RATE_THRESHOLD = 4000;
    uint256 public constant REBALANCE_UP_UTILIZATION_RATE_THRESHOLD = 1e27 * 0.95;

    // function to check if a deposit of assets is valid
    // for a deposit to be valid needs to:
    //      1-The amount deposited can not be 0
    //      2-The reserve is active
    //      3-The reserve is not frozen
    function validateDeposit(DataTypes.ReserveData storage reserve, uint256 amount) external view {
        (bool isActive, bool isFrozen, , ) = reserve.configuration.getFlags();

        require(amount != 0, "zero amount");
        require(isActive, "reserve not active");
        require(!isFrozen, "reserve frozen");
    }

    // function to check if a withdraw of assets is valid
    // the following checks are made:
    //      1-Amount to withdraw is greater than 0
    //      2-The amount to withdraw is actually available from the deposited amount from the user
    //      3-The specific asset is in active state
    //      4-With the current user state, ensure that the health factor does not drop from 1
    function validateWithdraw(
        address reserveAddress,
        uint256 amount,
        uint256 userBalance,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view {
        require(amount != 0, "zero amount");
        require(amount <= userBalance, "not enough balance available");

        (bool isActive, , , ) = reservesData[reserveAddress].configuration.getFlags();
        require(isActive, "reserve not active");

        require(GenericLogic.balanceDecreaseAllowed(
            reserveAddress,
            msg.sender,
            amount,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        ), "decrease balance not allowed");
    }

    struct ValidateBorrowLocalVars {
        uint256 currentLtv;
        uint256 currentLiquidationThreshold;
        uint256 amountOfCollateralNeededETH;
        uint256 userCollateralBalanceETH;
        uint256 userBorrowBalanceETH;
        uint256 availableLiquidity;
        uint256 healthFactor;
        bool isActive;
        bool isFrozen;
        bool borrowingEnabled;
        bool stableRateBorrowingEnabled;
    }

    // function to check if a borrow of assets is valid
    // the following checks are made:
    //      1-The specific asset is in active state
    //      2-The specific asset is not frozen
    //      3-Amount to borrow is greater than 0
    //      4-The specific asset is enabled for borrowing
    //      5-The interest rate selected is valid
    //      6-The user has some value in collateral
    //      7-User's health factor is in good state
    //      8-Amount of collateral needed to cover the new debt is lower than the current one
    //      In case of borrowing in stable rate:
    //          1-Check if the asset has the stable rate enabled
    //          2-The amount to borrow is less than a maximum percentage of the total asset reserve
    function validateBorrow(
        address asset,
        DataTypes.ReserveData storage reserve,
        address userAddress,
        uint256 amount,
        uint256 amountInETH,
        uint256 interestRateMode,
        uint256 maxStableLoanPercent,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view {
        ValidateBorrowLocalVars memory vars;

        (vars.isActive, vars.isFrozen, vars.borrowingEnabled, vars.stableRateBorrowingEnabled) = reserve.configuration.getFlags();

        require(vars.isActive, "reserve not active");
        require(!vars.isFrozen, "reserve frozen");
        require(amount != 0, "zero amount");
        require(vars.borrowingEnabled, "asset borrowing not enabled");
        require(uint256(DataTypes.InterestRateMode.STABLE) == interestRateMode || uint256(DataTypes.InterestRateMode.VARIABLE) == interestRateMode, "invalid interest rate");

        (
            vars.userCollateralBalanceETH,
            vars.userBorrowBalanceETH,
            vars.currentLtv,
            vars.currentLiquidationThreshold,
            vars.healthFactor
        ) = GenericLogic.calculateUserAccountData(
            userAddress,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        );

        require(vars.userCollateralBalanceETH > 0, "no collateral to back the borrow");
        require(vars.healthFactor > GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD, "health factor not in good shape");

        vars.amountOfCollateralNeededETH = (vars.userBorrowBalanceETH + amountInETH).percentDiv(vars.currentLtv);

        require(vars.amountOfCollateralNeededETH <= vars.userCollateralBalanceETH, "not enough collateral to back the borrow");

        // Specific checks for stable rate
        if(interestRateMode == uint256(DataTypes.InterestRateMode.STABLE)){

            require(vars.stableRateBorrowingEnabled, "stable rate borrowing not enabled");

            require(!userConfig.isUsingAsCollateral(reserve.id) || reserve.configuration.getLtv() == 0 || amount > AToken(reserve.aTokenAddress).balanceOf(userAddress), "edge case triggered");

            vars.availableLiquidity = IERC20(asset).balanceOf(reserve.aTokenAddress);

            uint256 maxLoanSizeStable = vars.availableLiquidity.percentMul(maxStableLoanPercent);
            require(amount <= maxLoanSizeStable, "amount to borrow exceed the maximum");
        }

    }

    // function to check if a repay of debt is valid
    // the following checks are made:
    //      1-The specific asset is in active state
    //      2-Amount to repay is greater than 0
    //      3-The interest rate selected is valid and checking if the user has debt
    //        accordingly to the selected interest rate
    //      4-A users can pay all his debt by passing the uint256 maximum number as
    //        amount to repay. It is also allowed to repay a debt on behalf of someone
    //        however, it is not allowed to repay the whole debt.
    function validateRepay(
        DataTypes.ReserveData storage reserve,
        uint256 amountSent,
        DataTypes.InterestRateMode rateMode,
        address onBehalfOf,
        uint256 stableDebt,
        uint256 variableDebt
    ) external view {
        bool isActive = reserve.configuration.getActive();

        require(isActive, "reserve not active");

        require(amountSent != 0, "zero amount");

        require((stableDebt > 0 && rateMode == DataTypes.InterestRateMode.STABLE) || (variableDebt > 0 && rateMode == DataTypes.InterestRateMode.VARIABLE), "no debt to repay");

        require(amountSent != type(uint256).max || msg.sender == onBehalfOf, "select a specific amount to repay");
    }

    // function to check if swapping interest rate mode is valid
    // the following checks are made:
    //      1-The specific asset is in active state
    //      2-The specific asset is not in frozen state
    //      3-Check if the active interest rate selected has indeed a debt
    //      In case of changing from variable to stable:
    //          1-The specific asset has the stable rate enabled
    //          2-Exploit avoidance:
    //              user can abuse the reserve by depositing
    //              more collateral than he is borrowing, artificially lowering
    //              the interest rate, borrowing at variable, and switching to stable
    function validateSwapRateMode(
        DataTypes.ReserveData storage reserve,
        DataTypes.UserConfigurationMap storage userConfig,
        uint256 stableDebt,
        uint256 variableDebt,
        DataTypes.InterestRateMode currentRateMode
    ) external view {
        (bool isActive, bool isFrozen, , bool stableRateEnabled) = reserve.configuration.getFlags();

        require(isActive, "reserve not active");
        require(!isFrozen, "reserve frozen");

        if(currentRateMode == DataTypes.InterestRateMode.STABLE){
            require(stableDebt > 0, "no stable debt to swap");
        } else if(currentRateMode == DataTypes.InterestRateMode.VARIABLE){
            require(variableDebt > 0, "no variable debt to swap");

            require(stableRateEnabled, "stable rate not enabled for this asset");

            require(!userConfig.isUsingAsCollateral(reserve.id) || reserve.configuration.getLtv() == 0 || (stableDebt + variableDebt) > AToken(reserve.aTokenAddress).balanceOf(msg.sender), "edge case triggered");
        } else {
            revert();
        }
    }

    // function to check if changing the stable rate by the current one is valid
    // the following checks are made:
    //      1-The specific asset is in active state
    //      2-If the utilization rate is above or equal to 95% and the liquidity rate is below or equal
    //        to the 4% of the maximum variable borrow rate the change of stable rate is allowed
    function validateRebalanceStableBorrowRate(
        DataTypes.ReserveData storage reserve,
        address reserveAddress,
        IERC20 stableDebtToken,
        IERC20 variableDebtToken,
        address aTokenAddress
    ) external view {
        bool isActive = reserve.configuration.getActive();

        require(isActive, "reserve not active");

        uint256 totalDebt = (stableDebtToken.totalSupply() + variableDebtToken.totalSupply()).wadToRay();
        uint256 availableLiquidity = IERC20(reserveAddress).balanceOf(aTokenAddress).wadToRay();
        uint256 utilizationRate = totalDebt == 0 
                                    ? 0
                                    : totalDebt.rayDiv(availableLiquidity + totalDebt);

        // if the liquidity rate is below

        uint256 currentLiquidityRate = reserve.currentLiquidityRate;
        uint256 maxVariableBorrowRate = DefaultReserveInterestRateStrategy(reserve.interestRateStrategyAddress).getMaxVariableBorrowRate();

        require(utilizationRate >= REBALANCE_UP_UTILIZATION_RATE_THRESHOLD && currentLiquidityRate <= maxVariableBorrowRate.percentMul(REBALANCE_UP_LIQUIDITY_RATE_THRESHOLD), "market coditions do not accept stable rate rebalancing");
    }

    // function to check if changing the balance of aToken to enable or disable as collateral is valid
    // the following checks are made:
    //      1-The user has indeed a positive balance of aToken
    //      2-If the user is enabling his funds to use them as collateral is valid always,
    //        however, disabling the funds to not use them as collateral it is mandatory to
    //        ensure that user has still his health factor in good shape 
    function validateSetUseReserveAsCollateral(
        DataTypes.ReserveData storage reserve,
        address reserveAddress,
        bool useAsCollateral,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view {
        uint256 underlyingBalance = AToken(reserve.aTokenAddress).balanceOf(msg.sender);

        require(underlyingBalance != 0, "no balance to switch collateral mode");

        require(useAsCollateral || GenericLogic.balanceDecreaseAllowed(
            reserveAddress,
            msg.sender,
            underlyingBalance,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        ), "not possible to switch collateral mode");
    }

    // functino to check if initiating a flash loan is valid
    // it only checks if the array of assets and the array of amounts have the same length
    function validateFlashLoan(address[] memory assets, uint256[] memory amounts) internal pure {
        require(assets.length == amounts.length, "wrong array lengths");
    }

    // function to check if liquidating a user's position is valid
    // the following checks are made:
    //      1-Both collateral and debt assets must be active
    //      2-The user being liquidated must have a health factor below 1
    //      3-The user being liquidated is using as collateral the asset that the liquidator wants as return
    //      4-The user being liquidated has indeed any debt to liquidate


    function validateLiquidationCall(
        DataTypes.ReserveData storage collateralReserve,
        DataTypes.ReserveData storage principalReserve,
        DataTypes.UserConfigurationMap storage userConfig,
        uint256 userHealthFactor,
        uint256 userStableDebt,
        uint256 userVariableDebt
    ) internal view {
        require(collateralReserve.configuration.getActive() && principalReserve.configuration.getActive(), "principal reserve or collateral reserve not active");
        require(userHealthFactor < GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD, "health factor in good shape");

        bool isCollateralEnabled = collateralReserve.configuration.getLiquidationThreshold() > 0 &&  userConfig.isUsingAsCollateral(collateralReserve.id);
        require(isCollateralEnabled, "asset not used as collateral");
        require(userStableDebt > 0 || userVariableDebt > 0, "no debt to liquidate");
    }

    // function to check if a user is allowed to transfer aToken
    // check only if user's health factor is in good shape
    function validateTransfer(
        address from,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) internal view {
        ( , , , , uint256 healthFactor) = GenericLogic.calculateUserAccountData(
            from,
            reservesData,
            userConfig,
            reserves,
            reservesCount,
            oracle
        );

        require(healthFactor >= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD, "health factor out of shape");
    }
}