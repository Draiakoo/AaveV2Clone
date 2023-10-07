// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {MathUtils} from "../mathLibraries/MathUtils.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";
import {VariableDebtToken} from "../tokens/VariableDebtToken.sol";
import {StableDebtToken} from "../tokens/StableDebtToken.sol";
import {AToken} from "../tokens/AToken.sol";
import {DefaultReserveInterestRateStrategy} from "../lendingPool/DefaultReserveInterestRateStrategy.sol";
import {ReserveInformationLibrary} from "../informationLibraries/ReserveInformationLibrary.sol";
import {PercentageMath} from "../mathLibraries/PercentageMath.sol";

library ReserveLogic {

    using WadRayMath for uint256;
    using ReserveInformationLibrary for DataTypes.ReserveConfigurationMap;
    using PercentageMath for uint256;

    event ReserveDataUpdated(
        address indexed asset,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );

    function getNormalizedDebt(DataTypes.ReserveData storage reserve) internal view returns(uint256){
        uint40 lastTimestamp = reserve.lastUpdateTimestamp;
        
        // if no time passed since last update, return the last computation
        if(lastTimestamp == uint40(block.timestamp)){
            return reserve.variableBorrowIndex;
        }

        return MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, lastTimestamp, block.timestamp).rayMul(reserve.variableBorrowIndex);
    }

    function getNormalizedIncome(DataTypes.ReserveData storage reserve) internal view returns(uint256){
        uint40 lastTimestamp = reserve.lastUpdateTimestamp;
        
        // if no time passed since last update, return the last computation
        if(lastTimestamp == uint40(block.timestamp)){
            return reserve.liquidityIndex;
        }

        return MathUtils.calculateCompoundedInterest(reserve.currentLiquidityRate, lastTimestamp, block.timestamp).rayMul(reserve.liquidityIndex);
    }

    struct UpdateInterestRatesLocalVars {
        address stableDebtTokenAddress;
        uint256 availableLiquidity;
        uint256 totalStableDebt;
        uint256 newLiquidityRate;
        uint256 newStableRate;
        uint256 newVariableRate;
        uint256 avgStableRate;
        uint256 totalVariableDebt;
    }

    function updateInterestRates(
        DataTypes.ReserveData storage reserve,
        address reserveAddress,
        address aTokenAddress,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        UpdateInterestRatesLocalVars memory vars;

        // calculate total stable debt tracked in StableDebtToken contract
        vars.stableDebtTokenAddress = reserve.stableDebtTokenAddress;
        (vars.totalStableDebt, vars.avgStableRate) = StableDebtToken(vars.stableDebtTokenAddress).getTotalSupplyAndAvgRate();

        // calculate total variable debt tracked in StableDebtToken contract
        vars.totalVariableDebt = VariableDebtToken(reserve.variableDebtTokenAddress).principalTotalSupply().rayMul(reserve.variableBorrowIndex);

        (vars.newLiquidityRate, vars.newStableRate, vars.newVariableRate) = DefaultReserveInterestRateStrategy(reserve.interestRateStrategyAddress)
            .calculateInterestRates(
                reserveAddress,
                aTokenAddress,
                liquidityAdded,
                liquidityTaken,
                vars.totalStableDebt,
                vars.totalVariableDebt,
                vars.avgStableRate,
                reserve.configuration.getReserveFactor()
            );

        require(vars.newLiquidityRate <= type(uint128).max, "liquidity rate overflow");
        require(vars.newStableRate <= type(uint128).max, "stable rate overflow");
        require(vars.newVariableRate <= type(uint128).max, "variable rate overflow");

        reserve.currentLiquidityRate = uint128(vars.newLiquidityRate);
        reserve.currentStableBorrowRate = uint128(vars.newStableRate);
        reserve.currentVariableBorrowRate = uint128(vars.newVariableRate);

        emit ReserveDataUpdated(
            reserveAddress,
            vars.newLiquidityRate,
            vars.newStableRate,
            vars.newVariableRate,
            reserve.liquidityIndex,
            reserve.variableBorrowIndex
        );
    }

    function updateIndexes(DataTypes.ReserveData storage reserve) internal {
        uint256 principalVariableDebt = VariableDebtToken(reserve.variableDebtTokenAddress).principalTotalSupply();
        uint256 previousVariableBorrowIndex = reserve.variableBorrowIndex;
        uint256 previousLiquidityIndex = reserve.liquidityIndex;
        uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;

        uint256 currentLiquidityRate = reserve.currentLiquidityRate;

        uint256 newLiquidityIndex = previousLiquidityIndex;
        uint256 newVariableBorrowIndex = previousVariableBorrowIndex;

        if(currentLiquidityRate > 0){
            uint256 cumulatedLiquidityInterest = MathUtils.calculateLinearInterest(currentLiquidityRate, lastUpdatedTimestamp);
            newLiquidityIndex = cumulatedLiquidityInterest.rayMul(previousLiquidityIndex);

            require(newLiquidityIndex <= type(uint128).max, "liquidity index overflow");

            reserve.liquidityIndex = uint128(newLiquidityIndex);

            if(principalVariableDebt != 0){
                uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, lastUpdatedTimestamp, block.timestamp);
                newVariableBorrowIndex = cumulatedVariableBorrowInterest.rayMul(previousVariableBorrowIndex);

                require(newVariableBorrowIndex <= type(uint128).max, "variable borrow index overflow");
                reserve.variableBorrowIndex = uint128(newVariableBorrowIndex);
            }
        }

        reserve.lastUpdateTimestamp = uint40(block.timestamp);

        _mintToTreasury(reserve, principalVariableDebt, previousVariableBorrowIndex, newLiquidityIndex, newVariableBorrowIndex, lastUpdatedTimestamp);
    }

    function cumulateToLiquidityIndex(
        DataTypes.ReserveData storage reserve,
        uint256 totalLiquidity,
        uint256 amount
    ) internal {
        uint256 amountToLiquidityRatio = amount.wadToRay().rayDiv(totalLiquidity.wadToRay());

        uint256 result = amountToLiquidityRatio + WadRayMath.ray();

        result = result.rayMul(reserve.liquidityIndex);
        require(result <= type(uint128).max, "liquidity index overflow");

        reserve.liquidityIndex = uint128(result);
    }

    struct MintToTreasuryLocalVars {
        uint256 currentStableDebt;
        uint256 principalStableDebt;
        uint256 previousStableDebt;
        uint256 currentVariableDebt;
        uint256 previousVariableDebt;
        uint256 avgStableRate;
        uint256 cumulatedStableInterest;
        uint256 totalDebtAccrued;
        uint256 amountToMint;
        uint256 reserveFactor;
        uint40 stableSupplyUpdatedTimestamp;
    }

    function _mintToTreasury(
        DataTypes.ReserveData storage reserve,
        uint256 principalVariableDebt,
        uint256 previousVariableBorrowIndex,
        uint256 newLiquidityIndex,
        uint256 newVariableBorrowIndex,
        uint40 timestamp
    ) internal {
        MintToTreasuryLocalVars memory vars;

        vars.reserveFactor = reserve.configuration.getReserveFactor();

        if(vars.reserveFactor == 0){
            return;
        }

        (
            vars.principalStableDebt,
            vars.currentStableDebt,
            vars.avgStableRate,
            vars.stableSupplyUpdatedTimestamp
        ) = StableDebtToken(reserve.stableDebtTokenAddress).getSupplyData();

        vars.previousVariableDebt = principalVariableDebt.rayMul(previousVariableBorrowIndex);
        vars.currentVariableDebt = principalVariableDebt.rayMul(newVariableBorrowIndex);

        vars.cumulatedStableInterest = MathUtils.calculateCompoundedInterest(vars.avgStableRate, vars.stableSupplyUpdatedTimestamp, timestamp);
        vars.previousStableDebt = vars.principalStableDebt.rayMul(vars.cumulatedStableInterest);

        vars.totalDebtAccrued = vars.currentVariableDebt + vars.currentStableDebt - vars.previousVariableDebt - vars.previousStableDebt;

        vars.amountToMint = vars.totalDebtAccrued.percentMul(vars.reserveFactor);

        if(vars.amountToMint != 0){
            AToken(reserve.aTokenAddress).mintToTreasury(vars.amountToMint, newLiquidityIndex);
        }
    }
}