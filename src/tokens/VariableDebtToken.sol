// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DebtTokenBase} from "./DebtTokenBase.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";

contract VariableDebtToken is DebtTokenBase {

    using WadRayMath for uint256;

    event Mint(
        address indexed from,
        address indexed onBehalfOf,
        uint256 value,
        uint256 index
    );

    event Burn(
        address indexed user,
        uint256 amount,
        uint256 index
    );

    ILendingPool internal immutable _pool;
    address internal immutable _underlyingAsset;

    constructor(ILendingPool pool, address underlyingAsset, uint8 decimals, string memory name, string memory symbol){
        _pool = pool;
        _underlyingAsset = underlyingAsset;
        _setDecimals(decimals);
        _setName(name);
        _setSymbol(symbol);
    }

    function mint(address user, address onBehalfOf, uint256 amount, uint256 index) external onlyLendingPool returns(bool){
        
        if(user != onBehalfOf){
            _decreaseBorrowAllowance(onBehalfOf, user, amount);
        }

        uint256 previousBalance = super.balanceOf(onBehalfOf);
        uint256 amountToMint = amount.rayDiv(index);
        require(amountToMint != 0);

        _mint(onBehalfOf, amountToMint);

        emit Mint(user, onBehalfOf, amount, index);
        emit Transfer(address(0), onBehalfOf, amount);

        return previousBalance == 0;
    }

    function burn(address user, uint256 amount, uint256 index) external onlyLendingPool {

        uint256 amountToBurn = amount.rayDiv(index);
        require(amountToBurn != 0);

        _burn(user, amountToBurn);

        emit Burn(user, amount, index);
        emit Transfer(user, address(0), amount);
    }

    // accumulated variable debt by a user
    function balanceOf(address user) public view override returns(uint256){
        
        // gas saving to not execute the getReserveNormalizedVariableDebt calculation if the balance is 0
        uint256 principalBalance = super.balanceOf(user);
        if(principalBalance == 0){
            return 0;
        }

        return super.balanceOf(user).rayMul(_pool.getReserveNormalizedVariableDebt(_underlyingAsset));
    }

    // initial amount of debt minted
    function principalBalanceOf(address user) public view returns(uint256){
        return super.balanceOf(user);
    }

    // accumulated variable debt of the pool
    function totalSupply() public view override returns(uint256){
        return super.totalSupply().rayMul(_pool.getReserveNormalizedVariableDebt(_underlyingAsset));
    }

    function principalTotalSupply() public view returns(uint256){
        return super.totalSupply();
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////         Internal functions        ////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _getUnderlyingAssetAddress() internal view override returns(address underlyingAsset){
        underlyingAsset = _underlyingAsset;
    }

    function _getLendingPool() internal view override returns(address lendingPool){
        lendingPool = address(_pool);
    }

    function _mint(address user, uint256 amount) internal override{
        require(user != address(0));

        _totalSupply += amount;
        _balances[user] += amount;
    }

    function _burn(address user, uint256 amount) internal override{
        require(user != address(0));

        _totalSupply -= amount;
        _balances[user] -= amount;
    }
}