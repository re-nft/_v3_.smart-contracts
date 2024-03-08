// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Enum} from "@safe-contracts/common/Enum.sol";
import {LibString} from "@solady/utils/LibString.sol";

import {ISafe} from "@src/interfaces/ISafe.sol";
import {IHook} from "@src/interfaces/IHook.sol";

import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";
import {toKeycode} from "@src/libraries/KernelUtils.sol";
import {RentalUtils} from "@src/libraries/RentalUtils.sol";
import {Signer} from "@src/packages/Signer.sol";
import {Reclaimer} from "@src/packages/Reclaimer.sol";
import {Accumulator} from "@src/packages/Accumulator.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {
    Item,
    RentalOrder,
    Hook,
    OrderType,
    ItemType,
    RentalId,
    RentalAssetUpdate
} from "@src/libraries/RentalStructs.sol";

/**
 * @title Stop
 * @notice Acts as an interface for all behavior related to stoping a rental.
 */
contract Stop is Policy, Signer, Reclaimer, Accumulator {
    using RentalUtils for Item;
    using RentalUtils for Item[];
    using RentalUtils for OrderType;

    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    // Modules that the policy depends on.
    Storage public STORE;
    PaymentEscrow public ESCRW;

    /**
     * @dev Instantiate this contract as a policy.
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) Policy(kernel_) Signer() Reclaimer() {}

    /**
     * @notice Upon policy activation, configures the modules that the policy depends on.
     *         If a module is ever upgraded that this policy depends on, the kernel will
     *         call this function again to ensure this policy has the current address
     *         of the module.
     *
     * @return dependencies Array of keycodes which represent modules that
     *                      this policy depends on.
     */
    function configureDependencies()
        external
        override
        onlyKernel
        returns (Keycode[] memory dependencies)
    {
        dependencies = new Keycode[](2);

        dependencies[0] = toKeycode("STORE");
        STORE = Storage(getModuleAddress(toKeycode("STORE")));

        dependencies[1] = toKeycode("ESCRW");
        ESCRW = PaymentEscrow(getModuleAddress(toKeycode("ESCRW")));
    }

    /**
     * @notice Upon policy activation, permissions are requested from the kernel to access
     *         particular keycode <> function selector pairs. Once these permissions are
     *         granted, they do not change and can only be revoked when the policy is
     *         deactivated by the kernel.
     *
     * @return requests Array of keycode <> function selector pairs which represent
     *                  permissions for the policy.
     */
    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](4);
        requests[0] = Permissions(toKeycode("STORE"), STORE.removeRentals.selector);
        requests[1] = Permissions(toKeycode("STORE"), STORE.removeRentalsBatch.selector);
        requests[2] = Permissions(toKeycode("ESCRW"), ESCRW.settlePayment.selector);
        requests[3] = Permissions(toKeycode("ESCRW"), ESCRW.settlePaymentBatch.selector);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Helper function to emit an event which signals a rental order has stopped.
     *
     * @param seaportOrderHash Order hash of the seaport order.
     * @param stopper Address which stopped the rental order.
     */
    function _emitRentalOrderStopped(bytes32 seaportOrderHash, address stopper) internal {
        // Wmit the event.
        emit Events.RentalOrderStopped(seaportOrderHash, stopper);
    }

    /**
     * @dev Validates that a rental order can be stopped. Whether an order
     *      can be stopped is dependent on the type of order. BASE orders can
     *      be stopped only when the rental has expired. PAY orders can be stopped
     *      by the lender at any point in the time.
     *
     * @param orderType Order type of the rental order to stop.
     * @param endTimestamp Timestamp that the rental will end.
     * @param expectedLender Address of the initial lender in the order.
     */
    function _validateRentalCanBeStopped(
        OrderType orderType,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address expectedLender
    ) internal view {
        // Determine if the order has expired.
        bool hasExpired = endTimestamp <= block.timestamp;

        // Determine if the fulfiller is the lender of the order.
        bool isLender = expectedLender == msg.sender;

        // Order cannot be stopped in the same transaction it was created.
        if (startTimestamp == block.timestamp) {
            revert Errors.StopPolicy_StoppedTooSoon();
        }

        // BASE orders processing.
        if (orderType.isBaseOrder()) {
            // check that the period for the rental order has expired.
            if (!hasExpired) {
                revert Errors.StopPolicy_CannotStopOrder(block.timestamp, msg.sender);
            }
        }
        // PAY order processing.
        else if (orderType.isPayOrder()) {
            // If the stopper is the lender, then it doesnt matter whether the rental
            // has expired. But if the stopper is not the lender, then the rental must have expired.
            if (!isLender && (!hasExpired)) {
                revert Errors.StopPolicy_CannotStopOrder(block.timestamp, msg.sender);
            }
        }
        // Revert if given an invalid order type.
        else {
            revert Errors.Shared_OrderTypeNotSupported(uint8(orderType));
        }
    }

    /**
     * @dev Since the stop policy is an enabled Gnosis Safe module on all rental safes, it
     *      can be used to execute a transaction directly from the rental safe which retrieves
     *      the rented assets. This call bypasses the guard that prevents the assets from being
     *      transferred.
     *
     * @param order Rental order to reclaim the items for.
     */
    function _reclaimRentedItems(RentalOrder memory order) internal {
        // Transfer ERC721s from the renter back to lender.
        bool success = ISafe(order.rentalWallet).execTransactionFromModule(
            // Stop policy inherits the reclaimer package.
            address(this),
            // value.
            0,
            // The encoded call to the `reclaimRentalOrder` function.
            abi.encodeWithSelector(this.reclaimRentalOrder.selector, order),
            // Safe must delegate call to the stop policy so that it is the msg.sender.
            Enum.Operation.DelegateCall
        );

        // Assert that the transfer back to the lender was successful.
        if (!success) {
            revert Errors.StopPolicy_ReclaimFailed();
        }
    }

    /**
     * @dev When a rental order is stopped, process each hook one by one but only if
     *      the hook's status is set to execute on a rental stop.
     *
     * @param hooks        Array of hooks to process for the order.
     * @param rentalItems  Array of rental items which are referenced by the hooks
     * @param rentalWallet Address of the rental wallet which is the current owner
     *                     of the rented assets.
     */
    function _removeHooks(
        Hook[] calldata hooks,
        Item[] calldata rentalItems,
        address rentalWallet
    ) internal {
        // Define hook target, item index, and item.
        address target;
        uint256 itemIndex;
        Item memory item;

        // Loop through each hook in the payload.
        for (uint256 i = 0; i < hooks.length; ++i) {
            // Get the hook address.
            target = hooks[i].target;

            // Check that the hook is reNFT-approved to execute on rental stop.
            if (STORE.hookOnStop(target)) {
                // Get the rental item index for this hook.
                itemIndex = hooks[i].itemIndex;

                // Get the rental item for this hook.
                item = rentalItems[itemIndex];

                // Make sure the item is a rented item.
                if (!item.isRental()) {
                    revert Errors.Shared_NonRentalHookItem(itemIndex);
                }

                // Call the hook with data about the rented item.
                try
                    IHook(target).onStop(
                        rentalWallet,
                        item.token,
                        item.identifier,
                        item.amount,
                        hooks[i].extraData
                    )
                {} catch Error(string memory revertReason) {
                    // Revert with reason given.
                    revert Errors.Shared_HookFailString(revertReason);
                } catch Panic(uint256 errorCode) {
                    // Convert solidity panic code to string.
                    string memory stringErrorCode = LibString.toString(errorCode);

                    // Revert with panic code.
                    revert Errors.Shared_HookFailString(
                        string.concat("Hook reverted: Panic code ", stringErrorCode)
                    );
                } catch (bytes memory revertData) {
                    // Fallback to an error that returns the byte data.
                    revert Errors.Shared_HookFailBytes(revertData);
                }
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Stops a rental by providing a `RentalOrder` struct. This data does not
     *         exist in protocol storage, only the hash of the rental order. However,
     *         during rental creation, all data needed to construct the rental order
     *         is emitted as an event. A check is then made to ensure that the passed
     *         in rental order matches the hash of a rental order in storage.
     *
     * @param order Rental order to stop.
     */
    function stopRent(RentalOrder calldata order) external {
        // Compute the order hash.
        bytes32 orderHash = _deriveRentalOrderHash(order);

        // The order must exist to be deleted.
        if (!STORE.orders(orderHash)) {
            revert Errors.StopPolicy_OrderDoesNotExist(orderHash);
        }

        // Check that the rental can be stopped.
        _validateRentalCanBeStopped(
            order.orderType,
            order.startTimestamp,
            order.endTimestamp,
            order.lender
        );

        // Create an accumulator which will hold all of the rental asset updates, consisting of IDs and
        // the rented amount. From this point on, new memory cannot be safely allocated until the
        // accumulator no longer needs to include elements.
        bytes memory rentalAssetUpdates = new bytes(0);

        // Check if each item in the order is a rental. If so, then generate the rental asset update.
        // Memory will become safe again after this block.
        for (uint256 i; i < order.items.length; ++i) {
            if (order.items[i].isRental()) {
                // Insert the rental asset update into the dynamic array.
                _insert(
                    rentalAssetUpdates,
                    order.items[i].toRentalId(order.rentalWallet),
                    order.items[i].amount
                );
            }
        }

        // Interaction: Transfer rentals from the renter back to lender.
        _reclaimRentedItems(order);

        // Interaction: Transfer ERC20 payments from the escrow contract to the respective recipients.
        ESCRW.settlePayment(order);

        // Interaction: process hooks so they no longer exist for the renter.
        if (order.hooks.length > 0) {
            _removeHooks(order.hooks, order.items, order.rentalWallet);
        }

        // Invariant: Remove rentals from storage by using the order hash only after all
        // processing for the order has been completed
        STORE.removeRentals(orderHash, _convertToStatic(rentalAssetUpdates));

        // Emit rental order stopped.
        _emitRentalOrderStopped(order.seaportOrderHash, msg.sender);
    }

    /**
     * @notice Stops a batch of rentals by providing an array of `RentalOrder` structs.
     *
     * @param orders Array of rental orders to stop.
     */
    function stopRentBatch(RentalOrder[] calldata orders) external {
        // Process each rental order.
        // Memory will become safe after this block.
        for (uint256 i = 0; i < orders.length; ++i) {
            // Compute the order hash.
            bytes32 orderHash = _deriveRentalOrderHash(orders[i]);

            // The order must exist to be deleted.
            if (!STORE.orders(orderHash)) {
                revert Errors.StopPolicy_OrderDoesNotExist(orderHash);
            }

            // Check that the rental can be stopped.
            _validateRentalCanBeStopped(
                orders[i].orderType,
                orders[i].startTimestamp,
                orders[i].endTimestamp,
                orders[i].lender
            );

            // Create an accumulator which will hold all of the rental asset updates, consisting of IDs and
            // the rented amount. From this point on, new memory cannot be safely allocated until the
            // accumulator no longer needs to include elements.
            bytes memory rentalAssetUpdates = new bytes(0);

            // Check if each item in the order is a rental. If so, then generate the rental asset update.
            for (uint256 j = 0; j < orders[i].items.length; ++j) {
                // Insert the rental asset update into the dynamic array.
                if (orders[i].items[j].isRental()) {
                    _insert(
                        rentalAssetUpdates,
                        orders[i].items[j].toRentalId(orders[i].rentalWallet),
                        orders[i].items[j].amount
                    );
                }
            }

            // Interaction: Transfer rentals from the renter back to lender.
            _reclaimRentedItems(orders[i]);

            // Interaction: Transfer ERC20 payments from the escrow contract to the respective recipients.
            ESCRW.settlePayment(orders[i]);

            // Interaction: Process hooks so they no longer exist for the renter.
            if (orders[i].hooks.length > 0) {
                _removeHooks(orders[i].hooks, orders[i].items, orders[i].rentalWallet);
            }

            // Invariant: Remove rentals from storage by using the order hash only after
            // processing for the order has been completed
            STORE.removeRentals(orderHash, _convertToStatic(rentalAssetUpdates));

            // Emit rental order stopped.
            _emitRentalOrderStopped(orderHash, msg.sender);
        }
    }
}
