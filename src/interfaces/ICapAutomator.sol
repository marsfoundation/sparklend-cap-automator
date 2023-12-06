// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface ICapAutomator {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev Event to log the setting of a new supply cap config.
     *  @param asset The address of the asset for which the config was set
     *  @param max Maximum allowed supply cap
     *  @param gap A gap between the supply and the supply cap that is being maintained
     *  @param increaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     */
    event SetSupplyCapConfig(address indexed asset, uint256 max, uint256 gap, uint256 increaseCooldown);

    /**
     *  @dev Event to log the setting of a new borrow cap config.
     *  @param asset The address of the asset for which the config was set
     *  @param max Maximum allowed borrow cap
     *  @param gap A gap between the borrows and the borrow cap that is being maintained
     *  @param increaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     */
    event SetBorrowCapConfig(address indexed asset, uint256 max, uint256 gap, uint256 increaseCooldown);

    /**
     *  @dev Event to log the removing of a supply cap config.
     *  @param asset The address of the asset for which supply config was removed
     */
    event RemoveSupplyCapConfig(address indexed asset);

    /**
     *  @dev Event to log the removing of a borrow cap config.
     *  @param asset The address of the asset for which supply borrow was removed
     */
    event RemoveBorrowCapConfig(address indexed asset);

    /**
     *  @dev Event to log the update of the supply cap.
     *  @param asset The address
     *  @param oldSupplyCap The old supply cap
     *  @param newSupplyCap The newly set supply cap
     */
    event UpdateSupplyCap(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);

    /**
     *  @dev Event to log the update of the borrow cap.
     *  @param asset The address
     *  @param oldBorrowCap The old borrow cap
     *  @param newBorrowCap The newly set borrow cap
     */
    event UpdateBorrowCap(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);

    /**********************************************************************************************/
    /*** Storage Variables                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev Returns the address of the pool configurator.
     *  @return poolConfigurator The address of the pool configurator.
     */
    function poolConfigurator() external view returns (address poolConfigurator);

    /**
     *  @dev Returns the address of the data provider.
     *  @return pool The address of the data provider.
     */
    function pool() external view returns (address pool);

    /**
     *  @dev Returns current configuration for automatic supply cap management
     *  @param asset The address of the asset which config is going to be returned
     *  @return max Maximum allowed supply cap
     *  @return gap A gap between the supply and the supply cap that is being maintained
     *  @return increaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     *  @return lastUpdateBlock The block of the last cap update
     *  @return lastIncreaseTime The timestamp of the last cap increase
     */
    function supplyCapConfigs(address asset) external view returns (
        uint48 max,
        uint48 gap,
        uint48 increaseCooldown,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    );

    /**
     *  @dev Returns current configuration for automatic borrow cap management
     *  @param asset The address of the asset which config is going to be returned
     *  @return max Maximum allowed borrow cap
     *  @return gap A gap between the borrows and the borrow cap that is being maintained
     *  @return increaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     *  @return lastUpdateBlock The block of the last cap update
     *  @return lastIncreaseTime The timestamp of the last cap increase
     */
    function borrowCapConfigs(address asset) external view returns (
        uint48 max,
        uint48 gap,
        uint48 increaseCooldown,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    );

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    /**
     *  @dev Function creating (or re-setting) a configuration for automatic supply cap management
     *  @param asset The address of the asset that is going to be managed
     *  @param max Maximum allowed supply cap
     *  @param gap A gap between the supply and the supply cap that is being maintained
     *  @param increaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     */
    function setSupplyCapConfig(
        address asset,
        uint256 max,
        uint256 gap,
        uint256 increaseCooldown
    ) external;

    /**
     *  @dev Function creating (or re-setting) a configuration for automatic borrow cap management
     *  @param asset The address of the asset that is going to be managed
     *  @param max Maximum allowed borrow cap
     *  @param gap A gap between the borrows and the borrow cap that is being maintained
     *  @param increaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     */
    function setBorrowCapConfig(
        address asset,
        uint256 max,
        uint256 gap,
        uint256 increaseCooldown
    ) external;

    /**
     *  @dev Function removing a configuration for automatic supply cap management
     *  @param asset The address of the asset for which the configuration is going to be removed
     */
    function removeSupplyCapConfig(address asset) external;

    /**
     *  @dev Function removing a configuration for automatic borrow cap management
     *  @param asset The address of the asset for which the configuration is going to be removed
     */
    function removeBorrowCapConfig(address asset) external;

    /**********************************************************************************************/
    /*** Public Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     *  @dev A public function that updates supply and borrow caps on markets of a given asset.
     *  @dev The supply and borrow caps are going to be set to, respectively, the values equal
     *  @dev to the sum of current supply and the supply cap gap and the the sum of current borrows and the borrow cap gap.
     *  @dev The caps are only going to be increased if the required cooldown time has passed.
     *  @dev Calling this function more than once per block will not have any additional effect.
     *  @param asset The address of the asset which caps are going to be updated
     *  @return newSupplyCap A newly set supply cap, or the old one if it was not updated
     *  @return newBorrowCap A newly set borrow cap, or the old one if it was not updated
     */
    function exec(address asset) external returns (uint256 newSupplyCap, uint256 newBorrowCap);
}
