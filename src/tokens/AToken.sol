// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {WadRayMath} from "../mathLibraries/WadRayMath.sol";

// @notice Permit functions are not implemented for simplicity
contract AToken is ERC20("AaveToken", "AT") {

    using WadRayMath for uint256;

    event Mint(
        address indexed from, 
        uint256 value,
        uint256 index
    );

    event Burn(
        address indexed from,
        address indexed target,
        uint256 value,
        uint256 index
    );

    event BalanceTransfer(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 index
    );

    ILendingPool internal immutable _pool;
    address internal immutable _treasury;
    address internal immutable _underlyingAsset;

    constructor(ILendingPool pool, address underlyingAsset, address treasury, uint8 decimals, string memory name, string memory symbol){
        _pool = pool;
        _underlyingAsset = underlyingAsset;
        _treasury = treasury;
        _decimals = decimals;
        _name = name;
        _symbol = symbol;
    }

    modifier onlyLendingPool {
        require(_msgSender() == _getLendingPool());
        _;
    }

    function mint(address user, uint256 amount, uint256 index) external onlyLendingPool returns(bool){

        uint256 previousBalance = super.balanceOf(user);
        uint256 amountToMint = amount.rayDiv(index);
        require(amountToMint != 0);

        _mint(user, amountToMint);

        emit Mint(user, amount, index);
        emit Transfer(address(0), user, amount);

        return previousBalance == 0;
    }

    function burn(address user, address receiver, uint256 amount, uint256 index) external onlyLendingPool {

        uint256 amountToBurn = amount.rayDiv(index);
        require(amountToBurn != 0);

        _burn(user, amountToBurn);
        IERC20(_underlyingAsset).transfer(receiver, amount);

        emit Burn(user, receiver, amount, index);
        emit Transfer(user, address(0), amount);
    }

    function transferUnderlyingTo(address receiver, uint256 amount) external onlyLendingPool returns(uint256){
        IERC20(_underlyingAsset).transfer(receiver, amount);
        return amount;
    }

    // Functions for liquidation
    function transferOnLiquidation(address userLiquidated, address assetReceiver, uint256 amount) external onlyLendingPool {
        _transfer(userLiquidated, assetReceiver, amount);

        emit Transfer(userLiquidated, assetReceiver, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override{
        address underlyingAsset = _underlyingAsset;
        ILendingPool pool = _pool;

        uint256 index = pool.getReserveNormalizedIncome(underlyingAsset);

        uint256 fromBalanceBefore = super.balanceOf(from).rayMul(index);
        uint256 toBalanceBefore = super.balanceOf(to).rayMul(index);

        super._transfer(from, to, amount.rayDiv(index));

        pool.finalizeTransfer(underlyingAsset, from, to, amount, fromBalanceBefore, toBalanceBefore);

        emit BalanceTransfer(from, to, amount, index);
    }

    // accumulated aToken by a user
    function balanceOf(address user) public view override returns(uint256){
        
        // gas saving to not execute the getReserveNormalizedIncome calculation if the balance is 0
        uint256 principalBalance = super.balanceOf(user);
        if(principalBalance == 0){
            return 0;
        }

        return super.balanceOf(user).rayMul(_pool.getReserveNormalizedIncome(_underlyingAsset));
    }

    function mintToTreasury(uint256 amount, uint256 index) external onlyLendingPool {
        address treasury = _treasury;

        _mint(treasury, amount.rayDiv(index));

        emit Transfer(address(0), treasury, amount);
        emit Mint(treasury, amount, index);
    }

    // initial amount of aToken minted
    function principalBalanceOf(address user) public view returns(uint256){
        return super.balanceOf(user);
    }

    // accumulated variable debt of the pool
    function totalSupply() public view override returns(uint256){
        return super.totalSupply().rayMul(_pool.getReserveNormalizedIncome(_underlyingAsset));
    }

    function principalTotalSupply() public view returns(uint256){
        return super.totalSupply();
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////         Internal functions        ////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _getUnderlyingAssetAddress() internal view returns(address underlyingAsset){
        underlyingAsset = _underlyingAsset;
    }

    function _getLendingPool() internal view returns(address lendingPool){
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