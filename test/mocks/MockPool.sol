// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';

import { PoolLike, PoolConfiguratorLike } from "src/CapAutomator.sol";

import { MockToken } from "./MockToken.sol";

contract MockPool is PoolLike, PoolConfiguratorLike {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    MockToken public aToken;
    MockToken public debtToken;

    mapping(address => uint256) public supplyCap;
    mapping(address => uint256) public borrowCap;

    constructor() {
        aToken = new MockToken();
        debtToken = new MockToken();
    }

    /**********************************************************************************************/
    /*** PoolLike functions                                                                     ***/
    /**********************************************************************************************/

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) {
        DataTypes.ReserveConfigurationMap memory configuration = DataTypes.ReserveConfigurationMap(0);
        configuration.setBorrowCap(borrowCap[asset]);
        configuration.setSupplyCap(supplyCap[asset]);

        return DataTypes.ReserveData({
            configuration:                      configuration,
            liquidityIndex:             uint128(0),
            currentLiquidityRate:       uint128(0),
            variableBorrowIndex:        uint128(0),
            currentVariableBorrowRate:  uint128(0),
            currentStableBorrowRate:    uint128(0),
            lastUpdateTimestamp:         uint40(0),
            id:                          uint16(0),
            aTokenAddress:              address(aToken),
            stableDebtTokenAddress:     address(0),
            variableDebtTokenAddress:   address(debtToken),
            interestRateStrategyAddress:address(0),
            accruedToTreasury:          uint128(0),
            unbacked:                   uint128(0),
            isolationModeTotalDebt:     uint128(0)
        });
    }


    /**********************************************************************************************/
    /*** PoolConfiguratorLike functions                                                         ***/
    /**********************************************************************************************/

    function setSupplyCap(address asset, uint256 newSupplyCap) external {
        supplyCap[asset] = newSupplyCap;
    }

    function setBorrowCap(address asset, uint256 newBorrowCap) external {
        borrowCap[asset] = newBorrowCap;
    }

    /**********************************************************************************************/
    /*** Mock functions                                                                         ***/
    /**********************************************************************************************/

    function setATokenTotalSupply(uint256 newATokenTotalSupply) external {
        aToken.setTotalSupply(newATokenTotalSupply);
    }

    function setTotalDebt(uint256 newTotalDebt) external {
        debtToken.setTotalSupply(newTotalDebt);
    }
}