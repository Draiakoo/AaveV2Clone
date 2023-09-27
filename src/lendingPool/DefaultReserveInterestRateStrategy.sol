// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {LendingPoolAddressesProvider} from "./LendingPoolAddressesProvider.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingRateOracle} from "../interfaces/ILendingRateOracle.sol";
import {PercentageMath} from "../mathLibraries/PercentageMath.sol";

contract DefaultReserveInterestRateStrategy {

    using WadRayMath for uint256;
    using PercentageMath for uint256;

    uint256 public immutable OPTIMAL_UTILIZATION_RATE;
    uint256 public immutable EXCESS_UTILIZATION_RATE;

    LendingPoolAddressesProvider public immutable addressesProvider;

    uint256 internal immutable _baseVariableBorrowRate;

    uint256 internal immutable _variableRateSlope1;
    uint256 internal immutable _variableRateSlope2;

    uint256 internal immutable _stableRateSlope1;
    uint256 internal immutable _stableRateSlope2;

    constructor(
        LendingPoolAddressesProvider provider,
        uint256 optimalUtilizationRate,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2,
        uint256 stableRateSlope1,
        uint256 stableRateSlope2
    ) {
        OPTIMAL_UTILIZATION_RATE = optimalUtilizationRate;
        EXCESS_UTILIZATION_RATE = WadRayMath.ray() - optimalUtilizationRate;
        addressesProvider = provider;
        _baseVariableBorrowRate = baseVariableBorrowRate;
        _variableRateSlope1 = variableRateSlope1;
        _variableRateSlope2 = variableRateSlope2;
        _stableRateSlope1 = stableRateSlope1;
        _stableRateSlope2 = stableRateSlope2;
    }

    struct CalcInterestRatesLocalVars {
        uint256 totalDebt;
        uint256 currentVariableBorrowRate;
        uint256 currentStableBorrowRate;
        uint256 currentLiquidityRate;
        uint256 utilizationRate;
    }

    function calculateInterestRates(
        address reserve,
        address aTokenAddress,
        uint256 liquidityAdded,
        uint256 liquidityTaken,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 averageStableBorrowRate,
        uint256 reserveFactor
    ) public view 
    returns(
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate
    ){
        CalcInterestRatesLocalVars memory vars;

        vars.totalDebt = totalStableDebt + totalVariableDebt;
        uint256 availableLiquidity = IERC20(reserve).balanceOf(aTokenAddress) + liquidityAdded - liquidityTaken;
        
        vars.utilizationRate = vars.totalDebt == 0
            ? 0
            : vars.totalDebt.rayDiv(availableLiquidity + vars.totalDebt);

        vars.currentStableBorrowRate = ILendingRateOracle(addressesProvider.getAddress("LENDING_RATE_ORACLE")).getMarketBorrowRate(reserve);

        if(vars.utilizationRate > OPTIMAL_UTILIZATION_RATE){
            uint256 excessUtilizatoinRateRatio = (vars.utilizationRate - OPTIMAL_UTILIZATION_RATE).rayDiv(EXCESS_UTILIZATION_RATE);

            vars.currentStableBorrowRate = vars.currentStableBorrowRate + _stableRateSlope1 + excessUtilizatoinRateRatio.rayMul(_stableRateSlope2);

            vars.currentVariableBorrowRate = _baseVariableBorrowRate + _variableRateSlope1 + excessUtilizatoinRateRatio.rayMul(_variableRateSlope2);
        } else {
            vars.currentStableBorrowRate = vars.currentStableBorrowRate + _stableRateSlope1.rayMul(vars.utilizationRate.rayDiv(OPTIMAL_UTILIZATION_RATE));
            
            vars.currentVariableBorrowRate = _baseVariableBorrowRate + _variableRateSlope1.rayMul(vars.utilizationRate.rayDiv(OPTIMAL_UTILIZATION_RATE));
        }

        vars.currentLiquidityRate = 
            _getOverallBorrowRate(totalStableDebt, totalVariableDebt, averageStableBorrowRate, vars.currentVariableBorrowRate)
            .rayMul(vars.utilizationRate)
            .percentMul(PercentageMath.PERCENTAGE_FACTOR - reserveFactor);


        liquidityRate = vars.currentLiquidityRate;
        stableBorrowRate = vars.currentStableBorrowRate;
        variableBorrowRate = vars.currentVariableBorrowRate;
    }


    function _getOverallBorrowRate(
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 averageStableBorrowRate,
        uint256 variableBorrowRate
    ) internal pure returns(uint256){

        uint256 totalDebt = totalStableDebt + totalVariableDebt;

        if(totalDebt == 0){
            return 0;
        }

        // Weighted average:
        // totalStableDebt * averageStableDebtRate + totalVariableDebt * variableDebtRate
        // ------------------------------------------------------------------------------
		//                       			totalDebt
        uint256 overallBorrowRate = (totalStableDebt.wadToRay().rayMul(averageStableBorrowRate) + totalVariableDebt.wadToRay().rayMul(variableBorrowRate)).rayDiv(totalDebt.wadToRay());
        return overallBorrowRate;
    }

    function getMaxVariableBorrowRate() external view returns (uint256) {
        return _baseVariableBorrowRate + _variableRateSlope1 + _variableRateSlope2;
    }

}