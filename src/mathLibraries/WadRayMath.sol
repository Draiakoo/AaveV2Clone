// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library WadRayMath {

    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;

    uint256 internal constant halfWAD = WAD/2;
    uint256 internal constant halfRAY = RAY/2;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    function ray() internal pure returns(uint256 oneRay){
        oneRay = RAY;
    }

    function wad() internal pure returns(uint256 oneWad){
        oneWad = WAD;
    }

    function halfRay() internal pure returns(uint256 halfRayNum){
        halfRayNum = halfRAY;
    }

    function halfWad() internal pure returns(uint256 halfWadNum){
        halfWadNum = halfWAD;
    }

    // Multiplication between 2 wad numbers rounding half up
    function wadMul(uint256 a, uint256 b) internal pure returns(uint256){
        if(a == 0 || b == 0){
            return 0;
        }

        require(a <= (type(uint256).max - halfWAD) / b);

        return (a * b + halfWAD) / WAD;
    }

    function wadDiv(uint256 a, uint256 b) internal pure returns(uint256){
        require(b != 0);
        uint256 halfB = b / 2;

        require(a <= (type(uint256).max - halfB) / WAD);

        return (a * WAD + halfB) / b;
    }

    function rayMul(uint256 a, uint256 b) internal pure returns(uint256){
        if(a == 0 || b == 0){
            return 0;
        }

        require(a <= (type(uint256).max - halfRAY) / b);

        return (a * b + halfRAY) / RAY;
    }

    function rayDiv(uint256 a, uint256 b) internal pure returns(uint256){
        require(b != 0);
        uint256 halfB = b / 2;

        require(a <= (type(uint256).max - halfB) / RAY);

        return (a * RAY + halfB) / b;
    }

    function rayToWad(uint256 number) internal pure returns(uint256){
        uint256 halfRatio = WAD_RAY_RATIO / 2;
        uint256 result = halfRatio + number;
        require(result >= halfRatio);

        return result / WAD_RAY_RATIO;
    }

    function wadToRay(uint256 number) internal pure returns(uint256){
        uint256 result = number * WAD_RAY_RATIO;
        require(result / WAD_RAY_RATIO == number);
        return result;
    }
}