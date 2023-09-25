// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {StableDebtToken} from "../../src/tokens/StableDebtToken.sol";
import {ILendingPool} from "../../src/interfaces/ILendingPool.sol";
import {MathUtils} from "../../src/mathLibraries/MathUtils.sol";
import {WadRayMath} from "../../src/mathLibraries/WadRayMath.sol";

contract StableDebtTokenTest is Test {
    using MathUtils for uint256;
    using WadRayMath for uint256;

    StableDebtToken public stableDebt;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public pool = makeAddr("lendingPool");

    function setUp() public {
        ILendingPool lendingPool = ILendingPool(pool);
        stableDebt = new StableDebtToken(lendingPool, address(0), 18, "StableTokenDebt", "STD");
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////                Mint tests                /////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testMintDirectUser() public {
        assertEq(stableDebt.principalBalanceOf(user1), 0);
        assertEq(stableDebt.balanceOf(user1), 0);

        (uint256 principalTotalSupply, uint256 accumulatedTotalSupply, uint256 currentAverageStableRate, ) = stableDebt.getSupplyData();
        assertEq(principalTotalSupply, 0);
        assertEq(accumulatedTotalSupply, 0);
        assertEq(currentAverageStableRate, 0);

        uint256 amount = 100 ether;
        uint256 rate = 1000000_0000000000_0000000000;

        vm.prank(pool);
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        stableDebt.mint(user1, user1, amount, rate);
        
        assertEq(stableDebt.getUserStableRate(user1), rate);
        (principalTotalSupply, accumulatedTotalSupply, currentAverageStableRate, ) = stableDebt.getSupplyData();
        assertEq(principalTotalSupply, 100 ether);
        assertEq(accumulatedTotalSupply, 100 ether);
        assertEq(currentAverageStableRate, rate);

        // a year passes
        skip(365 days);
        (principalTotalSupply, accumulatedTotalSupply, , ) = stableDebt.getSupplyData();
        assertEq(principalTotalSupply, 100 ether);
        // accumulated totalSupply must be greater than 110 ether, since had a rate of a 10%
        // I assume a max error of 1 %
        assertGt(accumulatedTotalSupply, amount * 110 / 100);
        assertLt(accumulatedTotalSupply, amount * 111 / 100);
    }

    function testMultipleDebtsAverageStableRate(uint40 timeElapsed) public {
        uint256 amount1 = 100 ether;
        uint256 rate1 = 1000000_0000000000_0000000000;
        uint256 amount2 = 100 ether;
        uint256 rate2 = 500000_0000000000_0000000000;

        vm.startPrank(pool);
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        stableDebt.mint(user1, user1, amount1, rate1);

        // Some time passes
        skip(timeElapsed);

        uint256 currentUserAccumulatedDebt = stableDebt.balanceOf(user1);
        // user2 mints 100e18 tokens at rate 0.05 = 5%
        stableDebt.mint(user1, user1, amount2, rate2);

        // (currentStableRate * currentAccumulatedDebt + newRate * newDebtAmount)
        // ----------------------------------------------------------------------
		//          currentAccumulatedDebt + newDebtAmount
        uint256 newUserStableRate = 
            (rate1.rayMul(currentUserAccumulatedDebt.wadToRay())
            +
            rate2.rayMul(amount2.wadToRay()))
            .rayDiv(currentUserAccumulatedDebt.wadToRay() + amount2.wadToRay());

        assertEq(stableDebt.getUserStableRate(user1), newUserStableRate);
    }

    function testMultipleUserDebts(uint40 timeElapsed) public {
        uint256 amount1 = 100 ether;
        uint256 rate1 = 1000000_0000000000_0000000000;
        uint256 amount2 = 100 ether;
        uint256 rate2 = 500000_0000000000_0000000000;

        vm.startPrank(pool);
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        stableDebt.mint(user1, user1, amount1, rate1);

        // Some time passes
        skip(timeElapsed);

        ( , uint256 accumulatedTotalSupply, , ) = stableDebt.getSupplyData();
        // user2 mints 100e18 tokens at rate 0.05 = 5%
        stableDebt.mint(user2, user2, amount2, rate2);

        // (currentStableRate * currentAccumulatedDebt + newRate * newDebtAmount)
        // ----------------------------------------------------------------------
		//          currentAccumulatedDebt + newDebtAmount
        uint256 newAverageStableRate = 
            (rate1.rayMul(accumulatedTotalSupply.wadToRay())
            +
            rate2.rayMul(amount2.wadToRay()))
            .rayDiv(accumulatedTotalSupply.wadToRay() + amount2.wadToRay());

        assertEq(stableDebt.getAverageStableRate(), newAverageStableRate);
    }

    function testMintDebtOnBehalfOfNotAllowed() public {
        uint256 amount = 100 ether;
        uint256 rate = 1000000_0000000000_0000000000;

        vm.prank(pool);
        vm.expectRevert();
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        stableDebt.mint(user1, user2, amount, rate);
    }

    function testMintDebtOnBehalfOfSuccess() public {
        uint256 amount = 100 ether;
        uint256 rate = 1000000_0000000000_0000000000;

        vm.prank(user2);
        stableDebt.approveDelegation(user1, amount);

        vm.prank(pool);
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        (bool success) = stableDebt.mint(user1, user2, amount, rate);

        assertTrue(success);
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////                Burn tests                /////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    modifier user1DebtSetup(uint40 timeElapsed){
        uint256 amount = 100 ether;
        uint256 rate = 1000000_0000000000_0000000000;

        vm.prank(pool);
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        stableDebt.mint(user1, user1, amount, rate);
        skip(timeElapsed);
        _;
    }

    modifier user1And2DebtSetup(uint40 timeElapsed){
        uint256 amount1 = 100 ether;
        uint256 rate1 = 1000000_0000000000_0000000000;
        uint256 amount2 = 100 ether;
        uint256 rate2 = 500000_0000000000_0000000000;

        vm.startPrank(pool);
        // user1 mints 100e18 tokens at rate 0.1 = 10%
        stableDebt.mint(user1, user1, amount1, rate1);
        // user2 mints 100e18 tokens at rate 0.05 = 5%
        stableDebt.mint(user2, user2, amount2, rate2);

        skip(365 days);
        _;
    }

    function testBurnSingleUser1DebtFullDebt(uint40 timeElapsed) public user1DebtSetup(timeElapsed){
        vm.assume(timeElapsed > 0);

        uint256 accumulatedStableDebt = stableDebt.balanceOf(user1);
        
        vm.prank(pool);
        // user1 burns all his debt
        stableDebt.burn(user1, accumulatedStableDebt);

        (uint256 principalTotalSupply, uint256 accumulatedTotalSupply, uint256 currentAverageStableRate, ) = stableDebt.getSupplyData();
        assertEq(principalTotalSupply, 0);
        assertEq(accumulatedTotalSupply, 0);
        assertEq(currentAverageStableRate, 0);
    }

    function testBurnSingleUser1PartialDebt(uint40 timeElapsed) public user1DebtSetup(timeElapsed){
        vm.assume(timeElapsed > 0);

        uint256 debtAccumulatedByUser = stableDebt.balanceOf(user1);
        uint256 debtToPay = 100 ether;
        uint256 userStableRateBefore = stableDebt.getUserStableRate(user1);
        
        vm.prank(pool);
        // user1 burns all his debt
        stableDebt.burn(user1, debtToPay);

        uint256 userStableRateAfter = stableDebt.getUserStableRate(user1);

        assertEq(stableDebt.principalBalanceOf(user1), debtAccumulatedByUser - debtToPay);
        assertEq(userStableRateBefore, userStableRateAfter);
    }

    function testMultipleUserDebtsUser1PaysFullDebt(uint40 timeElapsed) public user1And2DebtSetup(timeElapsed){
        vm.assume(timeElapsed > 0);

        uint256 accumulatedStableDebtUser1 = stableDebt.balanceOf(user1);
        uint256 accumulatedStableDebtUser2 = stableDebt.balanceOf(user2);
        uint256 averageStableRateBefore = stableDebt.getAverageStableRate();
        
        vm.prank(pool);
        // user1 burns all his debt
        stableDebt.burn(user1, accumulatedStableDebtUser1);

        uint256 averageStableRateAfter = stableDebt.getAverageStableRate();

        assertEq(stableDebt.balanceOf(user1), 0);
        assertEq(stableDebt.balanceOf(user2), accumulatedStableDebtUser2);
        assertGt(averageStableRateBefore, averageStableRateAfter);
    }

    function testMultipleUserDebtsUser1PaysPartialDebt(uint40 timeElapsed) public user1And2DebtSetup(timeElapsed){
        vm.assume(timeElapsed > 0);

        uint256 accumulatedStableDebtUser1 = stableDebt.balanceOf(user1);
        uint256 accumulatedStableDebtUser2 = stableDebt.balanceOf(user2);
        uint256 averageStableRateBefore = stableDebt.getAverageStableRate();
        
        vm.prank(pool);
        // user1 burns all his debt
        stableDebt.burn(user1, 100 ether);

        uint256 averageStableRateAfter = stableDebt.getAverageStableRate();

        assertEq(stableDebt.balanceOf(user1), accumulatedStableDebtUser1 - 100 ether);
        assertEq(stableDebt.balanceOf(user2), accumulatedStableDebtUser2);
        assertGt(averageStableRateBefore, averageStableRateAfter);
    }
}