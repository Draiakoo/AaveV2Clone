// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract DebtTokenBase is ERC20("DebtToken", "DT"){

    event BorrowAllowanceDelegated(address indexed fromUser, address indexed toUser, address asset, uint256 amount);

    // Aave v2 implements a borrow allowance, so a user can allow an address to borrow tokens on his behalf
    mapping(address user => mapping(address allowedBorrower => uint256 amount)) internal _borrowAllowances;

    modifier onlyLendingPool {
        require(_msgSender() == _getLendingPool(), "only callable by lending pool");
        _;
    }

    function approveDelegation(address delegatee, uint256 amount) external {
        _borrowAllowances[msg.sender][delegatee] = amount;
        emit BorrowAllowanceDelegated(msg.sender, delegatee, _getUnderlyingAssetAddress(), amount);
    }

    function viewBorrowAllowance(address delegator, address delegatee) external view returns(uint256){
        return _borrowAllowances[delegator][delegatee];
    }

    function _decreaseBorrowAllowance(address delegator, address delegatee, uint256 substractedAmount) internal {
        uint256 newBorrowAllowance = _borrowAllowances[delegator][delegatee] - substractedAmount;
        _borrowAllowances[delegator][delegatee] = newBorrowAllowance;
        emit BorrowAllowanceDelegated(delegator, delegatee, _getUnderlyingAssetAddress(), newBorrowAllowance);
    }

    function _setName(string memory newName) internal {
        _name = newName;
    }

    function _setSymbol(string memory newSymbol) internal {
        _symbol = newSymbol;
    }

    function _setDecimals(uint8 newDecimals) internal {
        _decimals = newDecimals;
    }

    function _getUnderlyingAssetAddress() internal view virtual returns(address);

    function _getLendingPool() internal view virtual returns(address);
}