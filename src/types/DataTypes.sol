// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library DataTypes {
  struct ReserveData {
    ReserveConfigurationMap configuration;

    uint128 liquidityIndex;             // in ray
    uint128 variableBorrowIndex;        // in ray
    uint128 currentLiquidityRate;       // in ray
    uint128 currentVariableBorrowRate;  // in ray
    uint128 currentStableBorrowRate;    // in ray

    uint40 lastUpdateTimestamp;

    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;

    address interestRateStrategyAddress;
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    // every 2 bits represent user asset configuration. Here can be stored up to 128 asset configurations
    // First bit indicates if the asset is used as collateral
    // Second bit indicates if the asset is borrowed
    // Examples:
    // 0b10   ->  asset used as collateral and not borrowed
    // 0b11   ->  asset used as collateral and borrowed
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}
