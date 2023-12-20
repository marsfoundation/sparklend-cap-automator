// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { WadRayMath }           from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import { IACLManager }          from "aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IPool }                from "aave-v3-core/contracts/interfaces/IPool.sol";
import { IPoolConfigurator }    from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import { IScaledBalanceToken }  from "aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract CapAutomatorIntegrationTestsBase is Test {

    using WadRayMath for uint256;

    address public constant POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address public constant POOL                    = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address public constant POOL_CONFIG             = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;
    address public constant DATA_PROVIDER           = 0xFc21d6d146E6086B8359705C8b28512a983db0cb;
    address public constant ACL_MANAGER             = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address public constant SPARK_PROXY             = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant WETH                    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WBTC                    = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address public user;

    address[] assets;

    CapAutomator public capAutomator;

    IACLManager aclManager = IACLManager(ACL_MANAGER);
    IPool       pool       = IPool(POOL);

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 18721430);

        capAutomator = new CapAutomator(POOL_ADDRESSES_PROVIDER);

        capAutomator.transferOwnership(SPARK_PROXY);

        vm.prank(SPARK_PROXY);
        aclManager.addRiskAdmin(address(capAutomator));

        assets = pool.getReservesList();

        user = makeAddr("user");
    }

    function currentATokenSupply(DataTypes.ReserveData memory _reserveData) internal view returns (uint256) {
        return (IScaledBalanceToken(_reserveData.aTokenAddress).scaledTotalSupply() + uint256(_reserveData.accruedToTreasury)).rayMul(_reserveData.liquidityIndex)
            / 10 ** ERC20(_reserveData.aTokenAddress).decimals();
    }

    function currentBorrows(DataTypes.ReserveData memory _reserveData) internal view returns (uint256) {
        return ERC20(_reserveData.variableDebtTokenAddress).totalSupply() / 10 ** ERC20(_reserveData.variableDebtTokenAddress).decimals();
    }

}

contract GeneralizedTests is CapAutomatorIntegrationTestsBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function test_E2E_increaseBorrow() public {
        for (uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preIncreaseBorrowCap = reserveData.configuration.getBorrowCap();
            uint256 currentBorrow        = currentBorrows(reserveData);

            uint256 newMaxCap;
            uint256 newGap;

            if (preIncreaseBorrowCap != 0) {  // If there is a borrow cap, set config based on it
                uint256 preIncreaseBorrowGap = preIncreaseBorrowCap - currentBorrow;

                newMaxCap = preIncreaseBorrowCap * 2;
                newGap    = preIncreaseBorrowGap * 2;
            } else if (currentBorrow != 0) {  // If there is unlimited borrowing, set config based on current borrows
                newMaxCap = currentBorrow * 4;
                newGap    = currentBorrow * 2;
            } else {  // If there is no cap and no borrows, use arbitrary values for the config
                newMaxCap = 2_000;
                newGap    = 1_000;
            }

            vm.prank(SPARK_PROXY);
            capAutomator.setBorrowCapConfig({
                asset:            assets[i],
                max:              newMaxCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            ( ,,, uint48 lastUpdateBlock, uint48 lastIncreaseTime ) = capAutomator.borrowCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  0);
            assertEq(lastIncreaseTime, 0);

            capAutomator.exec(assets[i]);

            ( ,,, lastUpdateBlock, lastIncreaseTime ) = capAutomator.borrowCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  block.number);
            assertEq(lastIncreaseTime, block.timestamp);

            uint256 postIncreaseBorrowCap = pool.getReserveData(assets[i]).configuration.getBorrowCap();
            assertEq(postIncreaseBorrowCap, currentBorrow + newGap);
        }
    }

    function test_E2E_decreaseBorrow() public {
        for (uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preDecreaseBorrowCap = reserveData.configuration.getBorrowCap();
            if (preDecreaseBorrowCap == 0) {
                continue;
            }
            // If there is a cap a decrease will be attempted, but if there is no cap, decrease is not posssible

            uint256 currentBorrow        = currentBorrows(reserveData);
            uint256 preDecreaseBorrowGap = preDecreaseBorrowCap - currentBorrow;

            uint256 newGap = preDecreaseBorrowGap / 2;

            vm.prank(SPARK_PROXY);
            capAutomator.setBorrowCapConfig({
                asset:            assets[i],
                max:              preDecreaseBorrowCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            ( ,,, uint48 lastUpdateBlock, uint48 lastIncreaseTime ) = capAutomator.borrowCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  0);
            assertEq(lastIncreaseTime, 0);

            capAutomator.exec(assets[i]);

            ( ,,, lastUpdateBlock, lastIncreaseTime ) = capAutomator.borrowCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  block.number);
            assertEq(lastIncreaseTime, 0);

            uint256 postDecreaseBorrowCap = pool.getReserveData(assets[i]).configuration.getBorrowCap();
            assertEq(postDecreaseBorrowCap, currentBorrow + newGap);
        }
    }

    function test_E2E_increaseSupply() public {
        for (uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preIncreaseSupplyCap = reserveData.configuration.getSupplyCap();
            uint256 currentSupply        = currentATokenSupply(reserveData);

            uint256 newMaxCap;
            uint256 newGap;

            if (preIncreaseSupplyCap != 0) {  // If there is a supply cap, set config based on it
                uint256 preIncreaseSupplyGap = preIncreaseSupplyCap - currentSupply;
                newMaxCap = preIncreaseSupplyCap * 2;
                newGap    = preIncreaseSupplyGap * 2;
            } else if (currentSupply != 0) {  // If there is unlimited supplying, set config based on current supply
                newMaxCap = currentSupply * 4;
                newGap    = currentSupply * 2;
            } else {  // If there is no cap and no supply, use arbitrary values for the config
                newMaxCap = 2_000;
                newGap    = 1_000;
            }

            vm.prank(SPARK_PROXY);
            capAutomator.setSupplyCapConfig({
                asset:            assets[i],
                max:              newMaxCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            ( ,,, uint48 lastUpdateBlock, uint48 lastIncreaseTime ) = capAutomator.supplyCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  0);
            assertEq(lastIncreaseTime, 0);

            capAutomator.exec(assets[i]);

            ( ,,, lastUpdateBlock, lastIncreaseTime ) = capAutomator.supplyCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  block.number);
            assertEq(lastIncreaseTime, block.timestamp);

            uint256 postIncreaseSupplyCap = pool.getReserveData(assets[i]).configuration.getSupplyCap();
            assertEq(postIncreaseSupplyCap, currentSupply + newGap);
        }
    }

    function test_E2E_decreaseSupply() public {
        for (uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preDecreaseSupplyCap = reserveData.configuration.getSupplyCap();
            if (preDecreaseSupplyCap == 0) {
                continue;
            }
            // If there is a cap a decrease will be attempted, but if there is no cap, decrease is not posssible

            uint256 currentSupply        = currentATokenSupply(reserveData);
            uint256 preDecreaseSupplyGap = preDecreaseSupplyCap - currentSupply;

            uint256 newGap = preDecreaseSupplyGap / 2;

            vm.prank(SPARK_PROXY);
            capAutomator.setSupplyCapConfig({
                asset:            assets[i],
                max:              preDecreaseSupplyCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            ( ,,, uint48 lastUpdateBlock, uint48 lastIncreaseTime ) = capAutomator.supplyCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  0);
            assertEq(lastIncreaseTime, 0);

            capAutomator.exec(assets[i]);

            ( ,,, lastUpdateBlock, lastIncreaseTime ) = capAutomator.supplyCapConfigs(assets[i]);
            assertEq(lastUpdateBlock,  block.number);
            assertEq(lastIncreaseTime, 0);

            uint256 postDecreaseSupplyCap = pool.getReserveData(assets[i]).configuration.getSupplyCap();
            assertEq(postDecreaseSupplyCap, currentSupply + newGap);
        }
    }

}

contract ConcreteTests is CapAutomatorIntegrationTestsBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath           for uint256;

    uint256 USERS_STASH = 6_000e8;

    function test_E2E_supply_wbtc() public {
        assertEq(ERC20(WBTC).decimals(), 8);

        DataTypes.ReserveData memory wbtcReserveData = pool.getReserveData(WBTC);

        // Confirm initial supply cap
        assertEq(wbtcReserveData.configuration.getSupplyCap(), 3_000);

        // Confirm initial WBTC supply
        uint256 initialSupply = currentATokenSupply(wbtcReserveData);
        assertEq(initialSupply, 750);

        vm.prank(SPARK_PROXY);
        capAutomator.setSupplyCapConfig({
            asset:            WBTC,
            max:              6_000,
            gap:              500,
            increaseCooldown: 12 hours
        });

        vm.startPrank(user);

        deal(WBTC, user, USERS_STASH);
        ERC20(WBTC).approve(POOL, USERS_STASH);

        pool.supply(WBTC, 2_000e8, user, 0);

        vm.stopPrank();

        // Confirm that WBTC supply cap didn't change yet
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_000);

        capAutomator.execSupply(WBTC);

        // Confirm correct WBTC supply cap increase
        // initialSupply + newlySupplied + gap = 750 + 2_000 + 500 = 3_250
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_250);

        vm.roll(block.number + 1);
        vm.prank(user);
        pool.supply(WBTC, 250e8, user, 0);

        // Check the cap is not changing before cooldown passes
        capAutomator.execSupply(WBTC);
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_250);

        // Check correct cap increase after cooldown
        skip(24 hours);
        capAutomator.execSupply(WBTC);
        // initialSupply + suppliedBefore + newlySupplied + gap = 750 + 2_000 + 250 + 500 = 3_500
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_500);

        vm.roll(block.number + 1);
        vm.prank(user);
        pool.withdraw(WBTC, 125e8, user);

        // Check correct cap decrease
        capAutomator.execSupply(WBTC);
        // previousSupply + gap - justWithdrawn = 3_000 + 500 - 125 = 3_375
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_375);

        vm.prank(user);
        pool.withdraw(WBTC, 125e8, user);

        // Check the cap is not changing in the same block
        capAutomator.execSupply(WBTC);
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_375);

        // Check correct cap decrease after block changes
        vm.roll(block.number + 1);
        capAutomator.execSupply(WBTC);
        // previousSupply + gap - justWithdrawn = 2_875 + 500 - 125 = 3_250
        assertEq(pool.getReserveData(WBTC).configuration.getSupplyCap(), 3_250);
    }

    function test_E2E_borrow_weth() public {
        assertEq(ERC20(WETH).decimals(), 18);

        DataTypes.ReserveData memory wethReserveData = pool.getReserveData(WETH);

        // Confirm initial borrow cap
        uint256 initialBorrowCap = wethReserveData.configuration.getBorrowCap();
        assertEq(initialBorrowCap, 1_400_000);

        // Confirm initial borrows
        uint256 initialBorrows = currentBorrows(wethReserveData);
        assertEq(initialBorrows, 126_520);

        vm.prank(SPARK_PROXY);
        capAutomator.setBorrowCapConfig({
            asset:            WETH,
            max:              2_000_000,
            gap:              100_000,
            increaseCooldown: 12 hours
        });

        vm.startPrank(user);

        deal(WBTC, user, USERS_STASH);
        ERC20(WBTC).approve(POOL, USERS_STASH);

        pool.supply(WBTC, 2_000e8, user, 0);

        vm.stopPrank();

        // Check correct cap decrease
        capAutomator.execBorrow(WETH);
        // totalDebt + gap = 126_520 + 100_000 = 226_520
        assertEq(pool.getReserveData(WETH).configuration.getBorrowCap(), 226_520);

        vm.prank(user);
        pool.borrow(WETH, 480e18, 2 /* variable rate mode */, 0, user);

        // Check that another cap change is not possible in the same block
        capAutomator.execBorrow(WETH);
        assertEq(pool.getReserveData(WETH).configuration.getBorrowCap(), 226_520);

        // Check correct cap increase in the new block
        vm.roll(block.number + 1);
        capAutomator.execBorrow(WETH);
        // totalDebt + gap = initialBorrows + newlyBorrowed + gap = 126_520 + 480 + 100_000 = 227_000
        assertEq(pool.getReserveData(WETH).configuration.getBorrowCap(), 227_000);
    }

}
