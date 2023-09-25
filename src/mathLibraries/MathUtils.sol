// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {WadRayMath} from "./WadRayMath.sol";

library MathUtils {

    using WadRayMath for uint256;

    uint256 internal constant YEARSECONDS = 365 days;

    // function to calculate the interest accumulated using a linear rate formula
    // NOTE: rate in ray units
    function calculateLinearInterest(uint256 rate, uint40 lastUpdateTimestamp) internal view returns(uint256 result){
        uint256 secondsElapsed = block.timestamp - lastUpdateTimestamp;
        result = rate * secondsElapsed / YEARSECONDS + WadRayMath.ray();
    }

    // function to calculate the interest using a compounded rate formula
    // NOTE: It is computed using binomial approximation
    // (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3
    // where:
    //      n are the seconds elapsed
    //      x is the rate/second
    function calculateCompoundedInterest(uint256 rate, uint256 lastUpdateTimestamp, uint256 currentTimestamp) internal pure returns(uint256){
        uint256 n = currentTimestamp - lastUpdateTimestamp;

        if (n == 0) {
            return WadRayMath.ray();
        }

        uint256 nMinusOne = n - 1;

        uint256 nMinusTwo = n > 2 ? n - 2 : 0;

        uint256 ratePerSecond = rate / YEARSECONDS;

        uint256 basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
        uint256 basePowerThree = basePowerTwo.rayMul(ratePerSecond);

        uint256 secondTerm = n * nMinusOne * basePowerTwo / 2;
        uint256 thirdTerm = n * nMinusOne * nMinusTwo * basePowerThree / 6;

        return WadRayMath.ray() + ratePerSecond * n + secondTerm + thirdTerm;
    }
}