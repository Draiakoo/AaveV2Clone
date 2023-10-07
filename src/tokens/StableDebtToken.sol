// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DebtTokenBase} from "./DebtTokenBase.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {MathUtils} from "../mathLibraries/MathUtils.sol";

contract StableDebtToken is DebtTokenBase{
    using WadRayMath for uint256;
    using MathUtils for uint256;

    event Mint(
        address indexed user,
        address indexed onBehalfOf,
        uint256 amount,
        uint256 currentBalance,
        uint256 balanceIncrease,
        uint256 newRate,
        uint256 avgStableRate,
        uint256 newTotalSupply
    );

    event Burn(
        address indexed user,
        uint256 amount,
        uint256 currentBalance,
        uint256 balanceIncrease,
        uint256 avgStableRate,
        uint256 newTotalSupply
    );

    uint256 internal _avgStableRate;
    mapping(address user => uint40 lastUpdatedTimeStamp) internal _timestamps;
    mapping(address user => uint256 stableRate) internal _usersStableRate;
    uint40 internal _totalSupplyTimestamp;

    ILendingPool internal immutable _pool;
    address internal immutable _underlyingAsset;

    constructor(ILendingPool pool, address underlyingAsset, uint8 decimals, string memory name, string memory symbol){
        _pool = pool;
        _underlyingAsset = underlyingAsset;

        _setName(name);
        _setSymbol(symbol);
        _setDecimals(decimals);
    }

    // Gas saving savig vars in memory
    struct MintVars {
        uint256 previousSupply;
        uint256 nextSupply;
        uint256 amountInRay;
        uint256 newStableRate;
        uint256 currentAvgStableRate;
    }

    function mint(address user, address onBehalfOf, uint256 amount, uint256 rate) external onlyLendingPool returns(bool){
        MintVars memory vars;

        if(user != onBehalfOf){
            _decreaseBorrowAllowance(onBehalfOf, user, amount);
        }

        (, uint256 currentUserAccumulatedDebt, uint256 accumulatedUserDebtIncrease) = _calculateBalanceIncrease(onBehalfOf);

        vars.currentAvgStableRate = _avgStableRate;
        vars.previousSupply = accumulatedTotalSupply(vars.currentAvgStableRate);
        vars.nextSupply = _totalSupply = vars.previousSupply + amount;
        vars.amountInRay = amount.wadToRay();

        // (currentStableRate * currentAccumulatedDebt + newRate * newDebtAmount)
        // ----------------------------------------------------------------------
		//          currentAccumulatedDebt + newDebtAmount

        vars.newStableRate = 
            (_usersStableRate[onBehalfOf].rayMul(currentUserAccumulatedDebt.wadToRay()) 
            + 
            (rate.rayMul(vars.amountInRay)))
            .rayDiv(currentUserAccumulatedDebt.wadToRay() + vars.amountInRay);

        require(vars.newStableRate <= type(uint128).max, "stabel rate overflow");
        _usersStableRate[onBehalfOf] = vars.newStableRate;
        _timestamps[onBehalfOf] = _totalSupplyTimestamp = uint40(block.timestamp);

        _avgStableRate = 
            (_avgStableRate.rayMul(vars.previousSupply.wadToRay()) 
            + 
            (rate.rayMul(vars.amountInRay)))
            .rayDiv(vars.previousSupply.wadToRay() + vars.amountInRay);

        _mint(onBehalfOf, amount);

        emit Transfer(address(0), onBehalfOf, amount);

        emit Mint(
            user,
            onBehalfOf,
            amount,
            currentUserAccumulatedDebt,
            accumulatedUserDebtIncrease,
            rate,
            vars.newStableRate,
            vars.nextSupply
        );

        return (currentUserAccumulatedDebt == 0);
    }

    function burn(address user, uint256 amount) external onlyLendingPool{
        (, uint256 currentUserAccumulatedDebt, uint256 accumulatedUserDebtIncrease) = _calculateBalanceIncrease(user);

        uint256 previousAccumulatedSupply = totalSupply();
        uint256 newAverageStableRate;
        uint256 nextSupply;
        uint256 userStableRate = _usersStableRate[user];

        if(previousAccumulatedSupply <= amount) {
            _avgStableRate = 0;
            _totalSupply = 0;
        } else {
            nextSupply = _totalSupply = previousAccumulatedSupply - amount;
            
            uint256 firstTerm = _avgStableRate.rayMul(previousAccumulatedSupply.wadToRay());
            uint256 secondTerm = userStableRate.rayMul(amount.wadToRay());

            if(secondTerm >= firstTerm){
                newAverageStableRate = _avgStableRate = _totalSupply = 0;
            } else {
                // avgStableRate * previousSupply - userStableRate * amount
                // --------------------------------------------------------
	            //               initialDebtSupply - amount
                newAverageStableRate = _avgStableRate = (firstTerm - secondTerm).rayDiv(nextSupply.wadToRay());
            }
        }

        if(amount == currentUserAccumulatedDebt){
            _usersStableRate[user] = _timestamps[user] = 0;
        } else {
            _timestamps[user] = uint40(block.timestamp);
        }

        _totalSupplyTimestamp = uint40(block.timestamp);

        if(accumulatedUserDebtIncrease > amount){
            uint256 amountToMint = accumulatedUserDebtIncrease - amount;
            _mint(user, amountToMint);
            emit Mint(
                user,
                user,
                amountToMint,
                currentUserAccumulatedDebt,
                accumulatedUserDebtIncrease,
                userStableRate,
                newAverageStableRate,
                nextSupply
            );
        } else {
            uint256 amountToBurn = amount - accumulatedUserDebtIncrease;
            _burn(user, amountToBurn);
            emit Burn(
                user,
                amountToBurn,
                currentUserAccumulatedDebt,
                accumulatedUserDebtIncrease,
                newAverageStableRate,
                nextSupply
            );
        }

        emit Transfer(user, address(0), amount);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////         Getter functions        //////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // function to calculate the accumulated debt
    function balanceOf(address user) public view override returns(uint256){
        uint256 initialDebt = super.balanceOf(user);
        if(initialDebt == 0){
            return 0;
        }

        uint256 acumulatedRate = _usersStableRate[user].calculateCompoundedInterest(_timestamps[user], block.timestamp);
        return acumulatedRate.rayMul(initialDebt);
    }

    function principalBalanceOf(address user) external view returns (uint256 userPrinciplBalance) {
        userPrinciplBalance = super.balanceOf(user);
    }

    function getAverageStableRate() external view returns(uint256 avgStableDebt){
        avgStableDebt = _avgStableRate;
    }

    function getUserLastUpdated(address user) external view returns(uint40 lastTimestamp){
        lastTimestamp = _timestamps[user];
    }

    function getUserStableRate(address user) external view returns(uint256 stableRate){
        stableRate = _usersStableRate[user];
    }

    function getSupplyData() public view
        returns (
        uint256 principalTotalSupply,
        uint256 accumTotalSupply,
        uint256 currentAverageStableRate,
        uint40 lastTotalSupplyTimestampUpdate
        )
    {
        uint256 avgRate = _avgStableRate;

        principalTotalSupply = super.totalSupply();
        accumTotalSupply = accumulatedTotalSupply(avgRate);
        currentAverageStableRate = avgRate;
        lastTotalSupplyTimestampUpdate = _totalSupplyTimestamp;
    }

    function totalSupply() public view override returns(uint256 result){
        result = accumulatedTotalSupply(_avgStableRate);
    }

    function accumulatedTotalSupply(uint256 avgRate) public view returns(uint256 accumulatedSupply){
        uint256 principalTotalSupply = super.totalSupply();

        accumulatedSupply = (avgRate.calculateCompoundedInterest(_totalSupplyTimestamp, block.timestamp)).rayMul(principalTotalSupply);
    }

    function getTotalSupplyAndAvgRate() public view returns(uint256 accumTotalSupply, uint256 avgStableRate){
        avgStableRate = _avgStableRate;
        accumTotalSupply = accumulatedTotalSupply(avgStableRate);
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////         Internal functions        ////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _calculateBalanceIncrease(address user) internal view 
        returns(
            uint256 initialUserDebt,
            uint256 currentAccumulatedDebt,
            uint256 accumulatedDebtIncrease
        )
    {
        initialUserDebt = super.balanceOf(user);
        currentAccumulatedDebt = balanceOf(user);
        accumulatedDebtIncrease = currentAccumulatedDebt - initialUserDebt;
    }

    function _mint(address user, uint256 amount) internal override{
        _balances[user] += amount;
    }

    function _burn(address user, uint256 amount) internal override{
        _balances[user] -= amount;
    }

    function _getUnderlyingAssetAddress() internal view override returns(address underlyingAsset){
        underlyingAsset = _underlyingAsset;
    }

    function _getLendingPool() internal view override returns(address lendingPool){
        lendingPool = address(_pool);
    }
}