// SPDX-License-Identifier: MIT

// pragma solidity 0.8.20;

// import {console} from "forge-std/console.sol";
// import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
// import {LendingPoolAddressesProvider} from "../../src/lendingPool/LendingPoolAddressesProvider.sol";
// import {LendingRateOracle} from "../../src/oracles/LendingRateOracle.sol";
// import {PriceOracleGetterMock} from "../mocks/PriceOracleGetterMock.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/token/ERC20/ERC20Mock.sol";
// import {LendingPool, AssetInitializationParams} from "../../src/lendingPool/LendingPool.sol";
// import {AToken} from "../../src/tokens/AToken.sol";
// import {StableDebtToken} from "../../src/tokens/StableDebtToken.sol";
// import {VariableDebtToken} from "../../src/tokens/VariableDebtToken.sol";
// import {WadRayMath} from "../../src/mathLibraries/WadRayMath.sol";
// import {DefaultReserveInterestRateStrategy} from "../../src/lendingPool/DefaultReserveInterestRateStrategy.sol";
// import {ILendingPool} from "../../src/interfaces/ILendingPool.sol";

// contract Protocol is Test {

//     using WadRayMath for uint256;

//     address public owner = makeAddr("owner");
//     address public normalUser = makeAddr("normalUser");

//     ERC20Mock public tokenMock1;
//     // ERC20Mock public tokenMock2;
//     // ERC20Mock public tokenMock3;

//     AssetInitializationParams public token1Params;
//     // AssetInitializationParams public token2Params;
//     // AssetInitializationParams public token3Params;

//     LendingPoolAddressesProvider public addressesProvider;
//     LendingRateOracle public rateOracle;
//     PriceOracleGetterMock public priceOracle;
//     LendingPool public pool;

//     string public initialMarketName = "Market Test";


//     function setUp() public {
//         vm.startPrank(owner);

//         rateOracle = new LendingRateOracle();
//         priceOracle = new PriceOracleGetterMock();
//         addressesProvider = new LendingPoolAddressesProvider(initialMarketName);
//         addressesProvider.setAddress("LENDING_RATE_ORACLE", address(rateOracle));
//         addressesProvider.setAddress("PRICE_ORACLE", address(priceOracle));

//         pool = new LendingPool(address(addressesProvider));

//         addressesProvider.setAddress("LENDING_POOL", address(pool));

        
//         // Create 3 ERC20 mocks
//         tokenMock1 = new ERC20Mock("Token 1", "T1", 18);
//         // tokenMock2 = new ERC20Mock("Token 2", "T2", 18);
//         // tokenMock3 = new ERC20Mock("Token 3", "T3", 6);



//         // Token 1 params
//         token1Params.asset = address(tokenMock1);
//         token1Params.ltv = 8000;                      // 80%
//         token1Params.liquidationThreshold = 8750;     // 87.5%
//         token1Params.liquidationBonus = 10500;        // 105% => 5% bonus
//         token1Params.decimals = tokenMock1.decimals();
//         token1Params.active = true;
//         token1Params.frozen = false;
//         token1Params.borrowingEnabled = true;
//         token1Params.stableRateBorrowingEnabled = true;
//         token1Params.reserveFactor = 2000;            // 20%

//         token1Params.liquidityIndex = 1_0000000_0000000000_0000000000;
//         token1Params.variableBorrowIndex = 1_0000000_0000000000_0000000000;
//         token1Params.currentLiquidityRate = 700000_0000000000_0000000000;               // 7%  APR
//         token1Params.currentVariableBorrowRate = 1000000_0000000000_0000000000;         // 10% APR
//         token1Params.currentStableBorrowRate = 1600000_0000000000_0000000000;           // 16% APR
//         token1Params.aTokenAddress = address(new AToken(
//             ILendingPool(address(pool)),
//             address(tokenMock1),
//             address(0),             // TODO: change reasury address
//             tokenMock1.decimals(),
//             "AToken1",
//             "AT1"
//         ));
//         token1Params.stableDebtTokenAddress = address(new StableDebtToken(
//             ILendingPool(address(pool)),
//             address(tokenMock1),
//             tokenMock1.decimals(),
//             "StableDebtToken1",
//             "SDT1"
//         ));
//         token1Params.variableDebtTokenAddress = address(new VariableDebtToken(
//             ILendingPool(address(pool)),
//             address(tokenMock1),
//             tokenMock1.decimals(),
//             "VariableDebtToken1",
//             "VDT1"
//         ));

//         token1Params.interestRateStrategyAddress = address(new DefaultReserveInterestRateStrategy(
//             addressesProvider,
//             900000000000000000000000000,            // 90% optimal utilization
//             0,
//             40000000000000000000000000,             // variable slope 1
//             600000000000000000000000000,            // variable slope 2
//             10000000000000000000000000,             // stable slope 1
//             600000000000000000000000000             // stable slope 2
//         ));




        // // Token 2 params
        // token2Params.asset = address(tokenMock2);
        // token2Params.ltv = 8000;                      // 80%
        // token2Params.liquidationThreshold = 8750;     // 87.5%
        // token2Params.liquidationBonus = 10500;        // 105% => 5% bonus
        // token2Params.decimals = tokenMock2.decimals();
        // token2Params.active = true;
        // token2Params.frozen = false;
        // token2Params.borrowingEnabled = true;
        // token2Params.stableRateBorrowingEnabled = true;
        // token2Params.reserveFactor = 2000;            // 20%

        // token2Params.liquidityIndex = 1_0000000_0000000000_0000000000;
        // token2Params.variableBorrowIndex = 1_0000000_0000000000_0000000000;
        // token2Params.currentLiquidityRate = 700000_0000000000_0000000000;               // 7%  APR
        // token2Params.currentVariableBorrowRate = 1000000_0000000000_0000000000;         // 10% APR
        // token2Params.currentStableBorrowRate = 1600000_0000000000_0000000000;           // 16% APR
        // token2Params.aTokenAddress = address(new AToken(
        //     ILendingPool(address(pool)),
        //     address(tokenMock2),
        //     address(0),             // TODO: change reasury address
        //     tokenMock2.decimals(),
        //     "AToken2",
        //     "AT2"
        // ));
        // token2Params.stableDebtTokenAddress = address(new StableDebtToken(
        //     ILendingPool(address(pool)),
        //     address(tokenMock2),
        //     tokenMock2.decimals(),
        //     "StableDebtToken2",
        //     "SDT2"
        // ));
        // token2Params.variableDebtTokenAddress = address(new VariableDebtToken(
        //     ILendingPool(address(pool)),
        //     address(tokenMock2),
        //     tokenMock2.decimals(),
        //     "VariableDebtToken2",
        //     "VDT2"
        // ));

        // token2Params.interestRateStrategyAddress = address(new DefaultReserveInterestRateStrategy(
        //     addressesProvider,
        //     900000000000000000000000000,            // 90% optimal utilization
        //     0,
        //     40000000000000000000000000,             // variable slope 1
        //     600000000000000000000000000,            // variable slope 2
        //     10000000000000000000000000,             // stable slope 1
        //     600000000000000000000000000             // stable slope 2
        // ));



        // // Token 3 params
        // token3Params.asset = address(tokenMock3);
        // token3Params.ltv = 8000;                      // 80%
        // token3Params.liquidationThreshold = 8750;     // 87.5%
        // token3Params.liquidationBonus = 10500;        // 105% => 5% bonus
        // token3Params.decimals = tokenMock3.decimals();
        // token3Params.active = true;
        // token3Params.frozen = false;
        // token3Params.borrowingEnabled = true;
        // token3Params.stableRateBorrowingEnabled = true;
        // token3Params.reserveFactor = 2000;            // 20%

        // token3Params.liquidityIndex = 1_0000000_0000000000_0000000000;
        // token3Params.variableBorrowIndex = 1_0000000_0000000000_0000000000;
        // token3Params.currentLiquidityRate = 700000_0000000000_0000000000;               // 7%  APR
        // token3Params.currentVariableBorrowRate = 1000000_0000000000_0000000000;         // 10% APR
        // token3Params.currentStableBorrowRate = 1600000_0000000000_0000000000;           // 16% APR
        // token3Params.aTokenAddress = address(new AToken(
        //     ILendingPool(address(pool)),
        //     address(tokenMock3),
        //     address(0),             // TODO: change reasury address
        //     tokenMock3.decimals(),
        //     "AToken3",
        //     "AT3"
        // ));
        // token3Params.stableDebtTokenAddress = address(new StableDebtToken(
        //     ILendingPool(address(pool)),
        //     address(tokenMock3),
        //     tokenMock3.decimals(),
        //     "StableDebtToken3",
        //     "SDT3"
        // ));
        // token3Params.variableDebtTokenAddress = address(new VariableDebtToken(
        //     ILendingPool(address(pool)),
        //     address(tokenMock3),
        //     tokenMock3.decimals(),
        //     "VariableDebtToken3",
        //     "VDT3"
        // ));

        // token3Params.interestRateStrategyAddress = address(new DefaultReserveInterestRateStrategy(
        //     addressesProvider,
        //     900000000000000000000000000,            // 90% optimal utilization
        //     0,
        //     40000000000000000000000000,             // variable slope 1
        //     600000000000000000000000000,            // variable slope 2
        //     10000000000000000000000000,             // stable slope 1
        //     600000000000000000000000000             // stable slope 2
        // ));

//         // Add all the reserves to the lending pool
//         AssetInitializationParams[] memory assetsParams = new AssetInitializationParams[](1);
//         assetsParams[0] = token1Params;
//         // assetsParams[1] = token2Params;
//         // assetsParams[2] = token3Params;
//         pool.batchAddReserves(assetsParams);

//         // Set token prices
//         priceOracle.artificiallyChangeAssetPrice(token1Params.asset, 10 * 10 ** 18);
//         // priceOracle.artificiallyChangeAssetPrice(token2Params.asset, 100 * 10 ** 18);
//         // priceOracle.artificiallyChangeAssetPrice(token3Params.asset, 1000 * 10 ** 18);

//         deal(address(tokenMock1), address(token1Params.aTokenAddress), 100_000 * 10 ** tokenMock1.decimals());
//         // deal(address(tokenMock2), address(token2Params.aTokenAddress), 10_000 * 10 ** tokenMock2.decimals());
//         // deal(address(tokenMock3), address(token3Params.aTokenAddress), 1_000 * 10 ** tokenMock3.decimals());

//         // Successfull asset setup assertions
        
//     }

//     function testUserDepositAndBorrow() public {
//         uint256 amountToDeposit = 1 * 10 ** tokenMock1.decimals();

//         deal(address(tokenMock1), address(normalUser), amountToDeposit);
//         vm.startPrank(normalUser);
//         tokenMock1.approve(address(pool), amountToDeposit);
//         pool.deposit(address(tokenMock1), amountToDeposit, msg.sender);

//         assertEq(AToken(token1Params.aTokenAddress).balanceOf(address(normalUser)), amountToDeposit);
//     }
// }