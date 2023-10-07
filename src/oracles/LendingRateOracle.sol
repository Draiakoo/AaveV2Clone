// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

contract LendingRateOracle {

    address private owner;
    mapping(address asset => uint256 marketBorrowRate) private marketBorrowRates;

    constructor(){
        owner = msg.sender;
    }

    modifier onlyOwner {
        _onlyOwner(msg.sender);
        _;
    }

    function getMarketBorrowRate(address asset) external view returns (uint256){
        return marketBorrowRates[asset];
    }

    function setMarketBorrowRate(address asset, uint256 rate) external onlyOwner {
        marketBorrowRates[asset] = rate;
    }

    function _onlyOwner(address caller) private view {
        require(caller == owner, "not owner");
    }
}
