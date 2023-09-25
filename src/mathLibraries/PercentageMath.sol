// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library PercentageMath {
    uint256 constant PERCENTAGE_FACTOR = 1e4;                 // 10000 means 100%
    uint256 constant HALF_PERCENT = PERCENTAGE_FACTOR / 2;

    // Perform the multiplication of the value * percentage
    // Eg: 5 ether              *   20%     =       1 ether
    //     5000000000000000000  *   2000    =       1000000000000000000
    function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        if (value == 0 || percentage == 0) {
        result = 0;
        }

        require(value <= (type(uint256).max - HALF_PERCENT) / percentage);

        result = (value * percentage + HALF_PERCENT) / PERCENTAGE_FACTOR;
    }

    // Perform the division of the value * percentage
    // Eg: 5 ether              /   20%     =       25 ether
    //     5000000000000000000  /   2000    =       25000000000000000000
    function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        require(percentage != 0);
        uint256 halfPercentage = percentage / 2;

        require(value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR);

        result = (value * PERCENTAGE_FACTOR + halfPercentage) / percentage;
    }
}
