// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

contract PriceOracleGetterMock {

    mapping(address asset => uint256 price) private prices;

    function getAssetPrice(address asset) external view returns (uint256){
        return prices[asset];
    }

    function artificiallyChangeAssetPrice(address asset, uint256 newPrice) external {
        prices[asset] = newPrice;
    }
  
}
