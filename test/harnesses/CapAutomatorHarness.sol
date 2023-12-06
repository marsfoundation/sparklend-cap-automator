// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IPool }                from 'aave-v3-core/contracts/interfaces/IPool.sol';
import { IPoolConfigurator }    from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';

import { CapAutomator } from "src/CapAutomator.sol";

contract CapAutomatorHarness is CapAutomator {

    constructor(address poolAddressesProvider)
        CapAutomator(poolAddressesProvider) {}

    function _calculateNewCapExternal(
        CapConfig memory capConfig,
        uint256 currentState,
        uint256 currentCap,
        uint256 decimals
    ) public view returns (uint256) {
        return super._calculateNewCap(
            capConfig,
            currentState,
            currentCap,
            decimals
        );
    }

    function _updateSupplyCapConfigExternal(address asset) public returns (uint256) {
        return super._updateSupplyCapConfig(asset);
    }

    function _updateBorrowCapConfigExternal(address asset) public returns (uint256) {
        return super._updateBorrowCapConfig(asset);
    }

}
