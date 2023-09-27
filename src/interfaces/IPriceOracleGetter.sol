// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IPriceOracleGetter {

  function getAssetPrice(address asset) external view returns (uint256);
  
}
