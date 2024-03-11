// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Kernel, Module, Keycode} from "@src/Kernel.sol";
import {Proxiable} from "@src/proxy/Proxiable.sol";
import {RentalUtils} from "@src/libraries/RentalUtils.sol";
import {RentalId, RentalAssetUpdate} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

/**
 * @title StorageBase
 * @notice Storage exists in its own base contract to avoid storage slot mismatch during upgrades.
 */
contract StorageBase {
    /////////////////////////////////////////////////////////////////////////////////
    //                                Rental Storage                               //
    /////////////////////////////////////////////////////////////////////////////////

    // Points an order hash to whether it is active.
    mapping(bytes32 orderHash => bool isActive) public orders;

    // Points an item ID to its number of actively rented tokens. This is used to
    // determine if an item is actively rented within the protocol. For ERC721, this
    // value will always be 1 when actively rented. Any inactive rentals will have a
    // value of 0.
    mapping(RentalId itemId => uint256 amount) public rentedAssets;

    // Maximum rent duration.
    uint256 public maxRentDuration;

    // Maximum offer items for a single order.
    uint256 public maxOfferItems;

    // Maximum consideration items for a single order.
    uint256 public maxConsiderationItems;

    /////////////////////////////////////////////////////////////////////////////////
    //                            Deployed Safe Storage                            //
    /////////////////////////////////////////////////////////////////////////////////

    // Records all safes that have been deployed by the protocol.
    mapping(address safe => uint256 nonce) public deployedSafes;

    // Records the total amount of deployed safes.
    uint256 public totalSafes;

    /////////////////////////////////////////////////////////////////////////////////
    //                                 Hook Storage                                //
    /////////////////////////////////////////////////////////////////////////////////

    // When interacting with the guard, any contracts that have hooks enabled
    // should have the guard logic routed through them.
    mapping(address to => address hook) internal _contractToHook;

    // Mapping of a bitmap which denotes the hook functions that are enabled.
    mapping(address hook => uint8 enabled) public hookStatus;

    /////////////////////////////////////////////////////////////////////////////////
    //                            Whitelist Storage                                //
    /////////////////////////////////////////////////////////////////////////////////

    // Allows the safe to delegate call to an approved address. For example, delegate
    // call to a contract that would swap out an old gnosis safe module for a new one.
    mapping(address delegate => bool isWhitelisted) public whitelistedDelegates;

    // Allows for the safe registration of extensions that can be enabled on a safe.
    mapping(address extension => uint8 enabled) public whitelistedExtensions;

    // Mapping of a bitmap which denotes whether the asset is enabled for renting and
    // whether the asset restricts gasless permit(). By default, an asset that is active
    // in the protocol should have a value of 0x11, which allows it to be rented and
    // prevents gasless permit() approvals.
    mapping(address asset => uint8 assetBitmap) public whitelistedAssets;

    // Allows the use of these whitelisted tokens as payments for rentals.
    mapping(address payment => bool isWhitelisted) public whitelistedPayments;

    // Allows a rental safe to upgrade to a newer guard policy if the current guard
    // policy ever has to be deactivated due to unforseen circumstances.
    address public guardEmergencyUpgrade;
}

/**
 * @title Storage
 * @notice Module dedicated to maintaining all the storage for the protocol. Includes
 *         storage for active rentals, deployed rental safes, hooks, and whitelists.
 */
contract Storage is Proxiable, Module, StorageBase {
    using RentalUtils for address;

    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Instantiate this contract as a module. When using a proxy, the kernel address
     *      should be set to address(0).
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) Module(kernel_) {}

    /**
     * @notice Instantiates this contract as a module via a proxy.
     *
     * @param kernel_ Address of the kernel contract.
     */
    function MODULE_PROXY_INSTANTIATION(
        Kernel kernel_
    ) external onlyByProxy onlyUninitialized {
        kernel = kernel_;
        initialized = true;
    }

    /**
     * @notice Specifies which version of a module is being implemented.
     */
    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    /**
     * @notice Defines the keycode for this module.
     */
    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("STORE");
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              View Functions                                 //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Determines if an asset is actively being rented by a wallet.
     *
     * @param recipient  Address of the wallet which rents the asset.
     * @param token      Address of the token.
     * @param identifier ID of the token.
     *
     * @return Amount of actively rented tokens for the asset.
     */
    function isRentedOut(
        address recipient,
        address token,
        uint256 identifier
    ) external view returns (uint256) {
        // calculate the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(recipient, token, identifier);

        // Determine if there is a positive amount
        return rentedAssets[rentalId];
    }

    /**
     * @notice Fetches the hook address that is pointing at the the target.
     *
     * @param to Address which has a hook pointing to it.
     */
    function contractToHook(address to) external view returns (address) {
        // Fetch the hook that the address currently points to.
        address hook = _contractToHook[to];

        // This hook may have been disabled without setting a new hook to take its place.
        // So if the hook is disabled, then return the 0 address.
        return hookStatus[hook] != 0 ? hook : address(0);
    }

    /**
     * @notice Determines whether the `onTransaction()` function is enabled for the hook.
     *
     * @param hook Address of the hook contract.
     */
    function hookOnTransaction(address hook) external view returns (bool) {
        // 1 is 0x00000001. Determines if the masked bit is enabled.
        return (uint8(1) & hookStatus[hook]) != 0;
    }

    /**
     * @notice Determines whether the `onStart()` function is enabled for the hook.
     *
     * @param hook Address of the hook contract.
     */
    function hookOnStart(address hook) external view returns (bool) {
        // 2 is 0x00000010. Determines if the masked bit is enabled.
        return uint8(2) & hookStatus[hook] != 0;
    }

    /**
     * @notice Determines whether the `onStop()` function is enabled for the hook.
     *
     * @param hook Address of the hook contract.
     */
    function hookOnStop(address hook) external view returns (bool) {
        // 4 is 0x00000100. Determines if the masked bit is enabled.
        return uint8(4) & hookStatus[hook] != 0;
    }

    /**
     * @notice Determines whether the extension can be enabled on the rental safe.
     *
     * @param extension Address of the extension contract.
     */
    function extensionEnableAllowed(address extension) external view returns (bool) {
        // 2 is 0x10. Determines if the masked bit is enabled.
        return uint8(2) & whitelistedExtensions[extension] != 0;
    }

    /**
     * @notice Determines whether the extension can be disabled on the rental safe.
     *
     * @param extension Address of the extension contract.
     */
    function extensionDisableAllowed(address extension) external view returns (bool) {
        // 1 is 0x01. Determines if the masked bit is enabled.
        return uint8(1) & whitelistedExtensions[extension] != 0;
    }

    /**
     * @notice Determines whether the asset is enabled for renting in the protocol
     *
     * @param asset Address of the token to rent.
     */
    function assetEnabledForRent(address asset) external view returns (bool) {
        // 2 is 0x10. Determines if the masked bit is enabled.
        return uint8(2) & whitelistedAssets[asset] != 0;
    }

    /**
     * @notice Determines whether the asset is restricted for gasless permit().
     *
     * @param asset Address of the token to restrict gassless permit().
     */
    function assetRestrictedForPermit(address asset) external view returns (bool) {
        // 1 is 0x01. Determines if the masked bit is enabled.
        return uint8(1) & whitelistedAssets[asset] != 0;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Adds an order hash to storage. Once an order hash is added to storage,
     *         the assets contained within are considered actively rented. Additionally,
     *         rental asset IDs are added to storage which creates a blocklist on those
     *         assets. When the blocklist is active, the protocol guard becomes active on
     *         them and prevents transfer or approval of the assets by the owner of the
     *         safe.
     *
     * @param orderHash          Hash of the rental order which is added to storage.
     * @param rentalAssetUpdates Asset update structs which are added to storage.
     */
    function addRentals(
        bytes32 orderHash,
        RentalAssetUpdate[] memory rentalAssetUpdates
    ) external onlyByProxy permissioned {
        // Add the order to storage.
        orders[orderHash] = true;

        // Add the rented items to storage.
        for (uint256 i = 0; i < rentalAssetUpdates.length; ++i) {
            RentalAssetUpdate memory asset = rentalAssetUpdates[i];

            // Update the order hash for that item.
            rentedAssets[asset.rentalId] += asset.amount;
        }
    }

    /**
     * @notice Removes an order hash from storage. Once an order hash is removed from
     *         storage, it can no longer be stopped since the protocol will have no
     *         record of the order. Addtionally, rental asset IDs are removed from
     *         storage. Once these hashes are removed, they are no longer blocklisted
     *         from being transferred out of the rental wallet by the owner.
     *
     * @param orderHash          Hash of the rental order which will be removed from
     *                           storage.
     * @param rentalAssetUpdates Asset update structs which will be removed from storage.
     */
    function removeRentals(
        bytes32 orderHash,
        RentalAssetUpdate[] calldata rentalAssetUpdates
    ) external onlyByProxy permissioned {
        // Delete the order from storage.
        delete orders[orderHash];

        // Process each rental asset.
        for (uint256 i = 0; i < rentalAssetUpdates.length; ++i) {
            RentalAssetUpdate memory asset = rentalAssetUpdates[i];

            // Reduce the amount of tokens for the particular rental ID.
            rentedAssets[asset.rentalId] -= asset.amount;
        }
    }

    /**
     * @notice Behaves the same as `removeRentals()`, except that orders are processed in
     *          a loop.
     *
     * @param orderHashes        All order hashes which will be removed from storage.
     * @param rentalAssetUpdates Asset update structs which will be removed from storage.
     */
    function removeRentalsBatch(
        bytes32[] calldata orderHashes,
        RentalAssetUpdate[] calldata rentalAssetUpdates
    ) external onlyByProxy permissioned {
        // Delete the orders from storage.
        for (uint256 i = 0; i < orderHashes.length; ++i) {
            // Delete the order from storage.
            delete orders[orderHashes[i]];
        }

        // Process each rental asset.
        for (uint256 i = 0; i < rentalAssetUpdates.length; ++i) {
            RentalAssetUpdate memory asset = rentalAssetUpdates[i];

            // Reduce the amount of tokens for the particular rental ID.
            rentedAssets[asset.rentalId] -= asset.amount;
        }
    }

    /**
     * @notice Adds the addresss of a rental safe to storage so that protocol-deployed
     *         rental safes can be distinguished from those deployed elsewhere.
     *
     * @param safe Address of the rental safe to add to storage.
     */
    function addRentalSafe(address safe) external onlyByProxy permissioned {
        // Get the new safe count.
        uint256 newSafeCount = totalSafes + 1;

        // Register the safe as deployed.
        deployedSafes[safe] = newSafeCount;

        // Increment nonce.
        totalSafes = newSafeCount;
    }

    /**
     * @notice Connects a hook to a destination address. Once an active path is made,
     *         any transactions originating from a rental safe to the target address
     *         will use a hook as middleware. The hook chosen is determined by the path
     *         set.
     *
     * @param to   Target address which will use a hook as middleware.
     * @param hook Address of the hook which will act as a middleware.
     */
    function updateHookPath(address to, address hook) external onlyByProxy permissioned {
        // Require that the `to` address is a contract.
        if (to.code.length == 0) revert Errors.StorageModule_NotContract(to);

        // Require that the `hook` address is a contract.
        if (hook.code.length == 0) revert Errors.StorageModule_NotContract(hook);

        // Point the `to` address to the `hook` address.
        _contractToHook[to] = hook;
    }

    /**
     * @notice Updates a hook with a bitmap that indicates its active functionality.
     *         A valid bitmap is any decimal value that is less than or equal
     *         to 7 (0x111).
     *
     * @param hook   Address of the hook contract.
     * @param bitmap Decimal value that defines the active functionality on the hook.
     */
    function updateHookStatus(
        address hook,
        uint8 bitmap
    ) external onlyByProxy permissioned {
        // Require that the `hook` address is a contract.
        if (hook.code.length == 0) revert Errors.StorageModule_NotContract(hook);

        // 7 is 0x00000111. This ensures that only a valid bitmap can be set.
        if (bitmap > uint8(7))
            revert Errors.StorageModule_InvalidHookStatusBitmap(bitmap);

        // Update the status of the hook.
        hookStatus[hook] = bitmap;
    }

    /**
     * @notice Toggles whether an address can be delegate called.
     *
     * @param delegate  Address which can be delegate called.
     * @param isEnabled Boolean indicating whether the address is enabled.
     */
    function toggleWhitelistDelegate(
        address delegate,
        bool isEnabled
    ) external onlyByProxy permissioned {
        whitelistedDelegates[delegate] = isEnabled;
    }

    /**
     * @notice Updates an extension with a bitmap that indicates whether the extension
     *         can be enabled or disabled by the rental safe. A valid bitmap is any
     *         decimal value that is less than or equal to 3 (0x11).
     *
     * @param extension Gnosis safe module which can be added to a rental safe.
     * @param bitmap    Decimal value that defines the status of the extension.
     */
    function toggleWhitelistExtension(
        address extension,
        uint8 bitmap
    ) external onlyByProxy permissioned {
        // Require that the `extension` address is a contract.
        if (extension.code.length == 0)
            revert Errors.StorageModule_NotContract(extension);

        // 3 is 0x11. This ensures that only a valid bitmap can be set.
        if (bitmap > uint8(3)) revert Errors.StorageModule_InvalidWhitelistBitmap(bitmap);

        // Update the extension.
        whitelistedExtensions[extension] = bitmap;
    }

    /**
     * @notice Toggles whether a token can be rented.
     *
     * @param asset  Token address which can be rented via the protocol.
     * @param bitmap Bitmap that denotes whether an asset can be rented.
     */
    function toggleWhitelistAsset(
        address asset,
        uint8 bitmap
    ) external onlyByProxy permissioned {
        // 3 is 0x11. This ensures that only a valid bitmap can be set.
        if (bitmap > uint8(3)) revert Errors.StorageModule_InvalidWhitelistBitmap(bitmap);

        // Update the asset whitelist.
        whitelistedAssets[asset] = bitmap;
    }

    /**
     * @notice Toggles whether a batch of tokens can be rented.
     *
     * @param assets  Token array which can be rented via the protocol.
     * @param bitmaps Bitmap array indicating whether those token are whitelisted.
     */
    function toggleWhitelistAssetBatch(
        address[] memory assets,
        uint8[] memory bitmaps
    ) external onlyByProxy permissioned {
        // Check that the arrays are the same length
        if (assets.length != bitmaps.length) {
            revert Errors.StorageModule_WhitelistBatchLengthMismatch(
                assets.length,
                bitmaps.length
            );
        }

        // Process each whitelist entry
        for (uint256 i; i < assets.length; ++i) {
            // 3 is 0x11. This ensures that only a valid bitmap can be set.
            if (bitmaps[i] > uint8(3))
                revert Errors.StorageModule_InvalidWhitelistBitmap(bitmaps[i]);

            whitelistedAssets[assets[i]] = bitmaps[i];
        }
    }

    /**
     * @notice Toggles whether a token can be used as a payment.
     *
     * @param payment   Token address which can be used as payment via the protocol.
     * @param isEnabled Boolean indicating whether the token is whitelisted.
     */
    function toggleWhitelistPayment(
        address payment,
        bool isEnabled
    ) external onlyByProxy permissioned {
        whitelistedPayments[payment] = isEnabled;
    }

    /**
     * @notice Toggles whether a batch of tokens can be used as payment.
     *
     * @param payments  Token array which can be used as payment via the protocol.
     * @param isEnabled Boolean array indicating whether those token are whitelisted.
     */
    function toggleWhitelistPaymentBatch(
        address[] memory payments,
        bool[] memory isEnabled
    ) external onlyByProxy permissioned {
        // Check that the arrays are the same length
        if (payments.length != isEnabled.length) {
            revert Errors.StorageModule_WhitelistBatchLengthMismatch(
                payments.length,
                isEnabled.length
            );
        }

        // Process each whitelist entry
        for (uint256 i; i < payments.length; ++i) {
            whitelistedPayments[payments[i]] = isEnabled[i];
        }
    }

    /**
     * @notice Upgrades the contract to a different implementation. This implementation
     *         contract must be compatible with ERC-1822 or else the upgrade will fail.
     *
     * @param newImplementation Address of the implementation contract to upgrade to.
     */
    function upgrade(address newImplementation) external onlyByProxy permissioned {
        // _upgrade is implemented in the Proxiable contract.
        _upgrade(newImplementation);
    }

    /**
     * @notice Freezes the contract which prevents upgrading the implementation contract.
     *         There is no way to unfreeze once a contract has been frozen.
     */
    function freeze() external onlyByProxy permissioned {
        // _freeze is implemented in the Proxiable contract.
        _freeze();
    }

    /**
     * @notice Sets the maximum rent duration.
     *
     * @param newDuration The new maximum rent duration.
     */
    function setMaxRentDuration(uint256 newDuration) external onlyByProxy permissioned {
        maxRentDuration = newDuration;
    }

    /**
     * @notice Sets the maximum offer items for a single order.
     *
     * @param newOfferLength The new maximum number of offer items.
     */
    function setMaxOfferItems(uint256 newOfferLength) external onlyByProxy permissioned {
        maxOfferItems = newOfferLength;
    }

    /**
     * @notice Sets the maximum consideration items for a single order.
     *
     * @param newConsiderationLength The new maximum number of consideration items.
     */
    function setMaxConsiderationItems(
        uint256 newConsiderationLength
    ) external onlyByProxy permissioned {
        maxConsiderationItems = newConsiderationLength;
    }

    /**
     * @notice Sets the guard emergency upgrade address.
     *
     * @param guardEmergencyUpgradeAddress The contract address which will allow rental
     * 									   safes to upgrade their guard policy.
     */
    function setGuardEmergencyUpgrade(
        address guardEmergencyUpgradeAddress
    ) external onlyByProxy permissioned {
        guardEmergencyUpgrade = guardEmergencyUpgradeAddress;
    }
}
