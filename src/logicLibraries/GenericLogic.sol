// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {UserInformationLibrary} from "../informationLibraries/UserInformationLibrary.sol";
import {ReserveInformationLibrary} from "../informationLibraries/ReserveInformationLibrary.sol";
import {IPriceOracleGetter} from "../interfaces/IPriceOracleGetter.sol";
import {AToken} from "../tokens/AToken.sol";
import {StableDebtToken} from "../tokens/StableDebtToken.sol";
import {VariableDebtToken} from "../tokens/VariableDebtToken.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";
import {PercentageMath} from "../mathLibraries/PercentageMath.sol";

library GenericLogic {

    using UserInformationLibrary for DataTypes.UserConfigurationMap;
    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;

    struct balanceDecreaseAllowedLocalVars {
        uint256 decimals;
        uint256 liquidationThreshold;
        uint256 totalCollateralInETH;
        uint256 totalDebtInETH;
        uint256 avgLiquidationThreshold;
        uint256 amountToDecreaseInETH;
        uint256 collateralBalanceAfterDecrease;
        uint256 liquidationThresholdAfterDecrease;
        uint256 healthFactorAfterDecrease;
        bool reserveUsageAsCollateralEnabled;
    }

    // function to check if a user can decrease his balance without getting his health factor under the minimum
    function balanceDecreaseAllowed(
        address asset,
        address user,
        uint256 amount,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap calldata userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) external view returns(bool){

        // if the user has not borrowed any token or the asset wanted to decrease its balance is not
        // being used as collateral, the user is allowed to decrease the balance for this specific asset
        if(!userConfig.isBorrowingAny() || !userConfig.isUsingAsCollateral(reservesData[asset].id)){
            return true;
        }

        balanceDecreaseAllowedLocalVars memory vars;

        ( , vars.liquidationThreshold, , vars.decimals, ) = reservesData[asset].configuration.getParams();

        // if there is no liquidation setup for this specific asset, the user is allowed to decrease its balance
        if(vars.liquidationThreshold == 0){
            return true;
        }

        (
            vars.totalCollateralInETH,
            vars.totalDebtInETH,
            ,
            vars.avgLiquidationThreshold,
        ) = calculateUserAccountData(user, reservesData, userConfig, reserves, reservesCount, oracle);

        if(vars.totalDebtInETH == 0){
            return true;
        }

        vars.amountToDecreaseInETH = IPriceOracleGetter(oracle).getAssetPrice(asset) * amount / (10**vars.decimals);

        vars.collateralBalanceAfterDecrease = vars.totalCollateralInETH - vars.amountToDecreaseInETH;

        // it has been checked previously that there is actual debt, if the new collateral value is 0, of course the health factor will be 0
        if(vars.collateralBalanceAfterDecrease == 0){
            return false;
        }

        // compute the new liquidation threshold after decrease
        //                            totalCollateralValue * averageLiquidationThreshold - amountToDecreaseValue * assetLiquidationThreshold
        // newLiquidationThreshold = --------------------------------------------------------------------------------------------------------
        //                                                              collateralValueAfterDecrease
        vars.liquidationThresholdAfterDecrease = (vars.totalCollateralInETH * vars.avgLiquidationThreshold - vars.amountToDecreaseInETH * vars.liquidationThreshold) / vars.collateralBalanceAfterDecrease;

        uint256 healthFactorAfterDecrease = calculateHealthFactorFromBalances(vars.collateralBalanceAfterDecrease, vars.totalDebtInETH, vars.liquidationThresholdAfterDecrease);

        return healthFactorAfterDecrease >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    }

    struct CalculateUserAccountDataVars {
        uint256 reserveUnitPrice;
        uint256 tokenUnit;
        uint256 compoundedLiquidityBalance;
        uint256 compoundedBorrowBalance;
        uint256 decimals;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 i;
        uint256 healthFactor;
        uint256 totalCollateralInETH;
        uint256 totalDebtInETH;
        uint256 avgLtv;
        uint256 avgLiquidationThreshold;
        uint256 reservesLength;
        bool healthFactorBelowThreshold;
        address currentReserveAddress;
        bool usageAsCollateralEnabled;
        bool userUsesReserveAsCollateral;
    }

    // function to calculate all the data of a user for all the reserves
    function calculateUserAccountData(
        address user,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap memory userConfig,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount,
        address oracle
    ) internal view returns(uint256, uint256, uint256, uint256, uint256){
        CalculateUserAccountDataVars memory vars;

        // notice that if a user has no borrows, his health factor is set to uint256.max due to division by 0 would revert
        if(userConfig.isEmpty()){
            return(0, 0, 0, 0, type(uint256).max);
        }

        // loop through all assets
        // Steps:
        //      1-Calculate collateral balance value
        //      2-Calculate borrow balance value (Stable + Variable)
        //      3-Accumulate the LTV and the liquidationThreshold to later calculate the average
        for(vars.i; vars.i < reservesCount; ){
            
            // if the asset is not either used as collateral or borrowed, pass to next iteration
            if(!userConfig.isUsingAsCollateralOrBorrowing(vars.i)){
                continue;
            }

            vars.currentReserveAddress = reserves[vars.i];
            DataTypes.ReserveData storage currentReserve = reservesData[vars.currentReserveAddress];

            (vars.ltv, vars.liquidationThreshold, , vars.decimals, ) = currentReserve.configuration.getParams();
            vars.tokenUnit = 10**vars.decimals;
            vars.reserveUnitPrice = IPriceOracleGetter(oracle).getAssetPrice(vars.currentReserveAddress);

            if(vars.liquidationThreshold != 0 && userConfig.isUsingAsCollateral(vars.i)){
                vars.compoundedLiquidityBalance = AToken(currentReserve.aTokenAddress).balanceOf(user);

                uint256 liquidityBalanceETH = vars.reserveUnitPrice * vars.compoundedLiquidityBalance / vars.tokenUnit;

                vars.totalCollateralInETH += liquidityBalanceETH;

                vars.avgLtv += liquidityBalanceETH * vars.ltv;
                vars.avgLiquidationThreshold += liquidityBalanceETH * vars.liquidationThreshold;
            }

            if(userConfig.isBorrowing(vars.i)){
                // Accumulated stable debt
                vars.compoundedBorrowBalance = StableDebtToken(currentReserve.stableDebtTokenAddress).balanceOf(user);

                // Accumulated variable debt
                vars.compoundedBorrowBalance += VariableDebtToken(currentReserve.variableDebtTokenAddress).balanceOf(user);

                vars.totalDebtInETH += vars.reserveUnitPrice * vars.compoundedBorrowBalance / vars.tokenUnit;
            }

            unchecked{
                ++vars.i;
            }
        }

        //                 SUM(assetValueInETH * assetLTV)
        // Average LTV = -----------------------------------
        //                      totalCollateralInETH
        vars.avgLtv = vars.totalCollateralInETH > 0 
                            ? vars.avgLtv / vars.totalCollateralInETH
                            : 0;

        //                                  SUM(assetValueInETH * assetLiquidationThreshold)
        // Average Liquidation threshold = --------------------------------------------------
        //                                                  totalCollateralInETH
        vars.avgLiquidationThreshold = vars.totalCollateralInETH > 0 
                            ? vars.avgLiquidationThreshold / vars.totalCollateralInETH
                            : 0;

        vars.healthFactor = calculateHealthFactorFromBalances(vars.totalCollateralInETH, vars.totalDebtInETH, vars.avgLiquidationThreshold);

        return(
            vars.totalCollateralInETH,
            vars.totalDebtInETH,
            vars.avgLtv,
            vars.avgLiquidationThreshold,
            vars.healthFactor
        );
    }

     function calculateHealthFactorFromBalances(
        uint256 totalCollateralInETH,
        uint256 totalDebtInETH,
        uint256 liquidationThreshold
    ) internal pure returns (uint256) {

        //                  totalCollateralValue * averageLiquidationThreshold
        // Health factor = ----------------------------------------------------
        //                                  totalDebtValue
        if(totalDebtInETH == 0){
            return type(uint256).max;
        }
        
        return totalCollateralInETH.percentMul(liquidationThreshold).wadDiv(totalDebtInETH);
    }
}