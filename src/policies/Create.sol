// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    ZoneParameters,
    OrderType as SeaportOrderType
} from "@seaport-core/lib/rental/ConsiderationStructs.sol";
import {ReceivedItem, SpentItem} from "@seaport-types/lib/ConsiderationStructs.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";

import {ISafe} from "@src/interfaces/ISafe.sol";
import {IHook} from "@src/interfaces/IHook.sol";
import {ZoneInterface} from "@src/interfaces/IZone.sol";

import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";
import {toKeycode, toRole} from "@src/libraries/KernelUtils.sol";
import {RentalUtils} from "@src/libraries/RentalUtils.sol";
import {Transferer} from "@src/libraries/Transferer.sol";
import {Signer} from "@src/packages/Signer.sol";
import {Zone} from "@src/packages/Zone.sol";
import {Accumulator} from "@src/packages/Accumulator.sol";
import {TokenReceiver} from "@src/packages/TokenReceiver.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";
import {
    RentalOrder,
    RentPayload,
    SeaportPayload,
    Hook,
    OrderFulfillment,
    OrderMetadata,
    OrderType,
    Item,
    ItemType,
    SettleTo,
    RentalId,
    RentalAssetUpdate
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

/**
 * @title Create
 * @notice Acts as an interface for all behavior related to creating a rental.
 */
contract Create is Policy, Signer, Zone, Accumulator, TokenReceiver {
    using Transferer for address;
    using Transferer for Item;
    using RentalUtils for Item;
    using RentalUtils for Item[];
    using RentalUtils for SpentItem;
    using RentalUtils for ReceivedItem;
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
    constructor(Kernel kernel_) Policy(kernel_) Signer() Zone() {}

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
        requests = new Permissions[](2);
        requests[0] = Permissions(toKeycode("STORE"), STORE.addRentals.selector);
        requests[1] = Permissions(toKeycode("ESCRW"), ESCRW.increaseDeposit.selector);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              View Functions                                 //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Retrieves the domain separator.
     *
     * @return The domain separator for the protocol.
     */
    function domainSeparator() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    /**
     * @notice Derives the rental order EIP-712 compliant hash from a `RentalOrder`.
     *
     * @param order Rental order converted to a hash.
     */
    function getRentalOrderHash(
        RentalOrder memory order
    ) external view returns (bytes32) {
        return _deriveRentalOrderHash(order);
    }

    /**
     * @notice Derives the rent payload EIP-712 compliant hash from a `RentPayload`.
     *
     * @param payload Rent payload converted to a hash.
     */
    function getRentPayloadHash(
        RentPayload memory payload
    ) external view returns (bytes32) {
        return _deriveRentPayloadHash(payload);
    }

    /**
     * @notice Derives the order metadata EIP-712 compliant hash from an `OrderMetadata`.
     *
     * @param metadata Order metadata converted to a hash.
     */
    function getOrderMetadataHash(
        OrderMetadata memory metadata
    ) external view returns (bytes32) {
        return _deriveOrderMetadataHash(metadata);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Helper function to emit an event which signals a rental order has started.
     *
     * @param order     Rental order to emit.
     * @param orderHash Order hash of the seaport order.
     * @param extraData Any extra data to be emitted which was supplied by the offerer.
     */
    function _emitRentalOrderStarted(
        RentalOrder memory order,
        bytes32 orderHash,
        bytes memory extraData
    ) internal {
        // Emit the event.
        emit Events.RentalOrderStarted(
            orderHash,
            extraData,
            order.seaportOrderHash,
            order.items,
            order.hooks,
            order.orderType,
            order.lender,
            order.renter,
            order.rentalWallet,
            order.startTimestamp,
            order.endTimestamp
        );
    }

    /**
     * @dev Processes the offer items for inclusion in a BASE order. All offer items must
     *      adhere to the BASE order format, else execution will revert.
     *
     * @param rentalItems Running array of items that comprise the rental order.
     * @param offers      Array of offer items to include in the the order.
     * @param startIndex  Index to begin adding the offer items to the
     *                    `rentalItems` array.
     */
    function _processBaseOrderOffer(
        Item[] memory rentalItems,
        SpentItem[] memory offers,
        uint256 startIndex
    ) internal view {
        // Put offer length onto the stack.
        uint256 offerLength = offers.length;

        // Must be at least one offer item.
        if (offerLength == 0) {
            revert Errors.CreatePolicy_OfferCountZero();
        }

        // Must not exceed maximum offer item amount.
        if (offerLength > STORE.maxOfferItems()) {
            revert Errors.CreatePolicy_OfferCountExceedsMax(offerLength);
        }

        // Define elements of the item which depend on the token type.
        ItemType itemType;

        // Process each offer item.
        for (uint256 i; i < offerLength; ++i) {
            // Get the offer item.
            SpentItem memory offer = offers[i];

            // Handle the ERC721 item.
            if (offer.isERC721()) {
                itemType = ItemType.ERC721;
            }
            // Handle the ERC1155 item.
            else if (offer.isERC1155()) {
                itemType = ItemType.ERC1155;
            }
            // ERC20s are not supported as offer items in a BASE order.
            else {
                revert Errors.CreatePolicy_SeaportItemTypeNotSupported(offer.itemType);
            }

            // An ERC721 or ERC1155 offer item is considered a rented asset which will be
            // returned to the lender upon expiration of the rental order.
            rentalItems[i + startIndex] = Item({
                itemType: itemType,
                settleTo: SettleTo.LENDER,
                token: offer.token,
                amount: offer.amount,
                identifier: offer.identifier
            });
        }
    }

    /**
     * @dev Processes the offer items for inclusion in a PAY order. All offer items must
     *      adhere to the PAY order format, else execution will revert.
     *
     * @param rentalItems Running array of items that comprise the rental order.
     * @param offers      Array of offer items to include in the the order.
     * @param startIndex  Index to begin adding the offer items to the
     *                    `rentalItems` array.
     */
    function _processPayOrderOffer(
        Item[] memory rentalItems,
        SpentItem[] memory offers,
        uint256 startIndex
    ) internal view {
        // Keep track of each item type.
        uint256 totalRentals;
        uint256 totalPayments;

        // Define elements of the item which depend on the token type.
        ItemType itemType;
        SettleTo settleTo;

        // Put offer length onto the stack.
        uint256 offerLength = offers.length;

        // Must not exceed maximum offer item amount.
        if (offerLength > STORE.maxOfferItems()) {
            revert Errors.CreatePolicy_OfferCountExceedsMax(offerLength);
        }

        // Process each offer item.
        for (uint256 i; i < offerLength; ++i) {
            // Get the offer item.
            SpentItem memory offer = offers[i];

            // Handle the ERC721 item.
            if (offer.isERC721()) {
                // The ERC721 will be returned to the lender upon expiration
                // of the rental order.
                itemType = ItemType.ERC721;
                settleTo = SettleTo.LENDER;

                // Increment rentals.
                totalRentals++;
            }
            // Handle the ERC1155 item.
            else if (offer.isERC1155()) {
                // The ERC1155 will be returned to the lender upon expiration
                // of the rental order.
                itemType = ItemType.ERC1155;
                settleTo = SettleTo.LENDER;

                // Increment rentals.
                totalRentals++;
            }
            // Process an ERC20 offer item.
            else if (offer.isERC20()) {
                // An ERC20 offer item is considered a payment to the renter upon
                // expiration of the rental order.
                itemType = ItemType.ERC20;
                settleTo = SettleTo.RENTER;

                // Increment payments.
                totalPayments++;
            }
            // Revert if unsupported item type.
            else {
                revert Errors.CreatePolicy_SeaportItemTypeNotSupported(offer.itemType);
            }

            // Create the item.
            rentalItems[i + startIndex] = Item({
                itemType: itemType,
                settleTo: settleTo,
                token: offer.token,
                amount: offer.amount,
                identifier: offer.identifier
            });
        }

        // PAY order offer must have at least one rental and one payment.
        if (totalRentals == 0 || totalPayments == 0) {
            revert Errors.CreatePolicy_ItemCountZero(totalRentals, totalPayments);
        }
    }

    /**
     * @dev Processes the consideration items for inclusion in a BASE order. All
     *      consideration items must adhere to the BASE order format, else
     *      execution will revert.
     *
     * @param rentalItems    Running array of items that comprise the rental order.
     * @param considerations Array of consideration items to include in the the order.
     * @param startIndex     Index to begin adding the offer items to the
     *                       `rentalItems` array.
     */
    function _processBaseOrderConsideration(
        Item[] memory rentalItems,
        ReceivedItem[] memory considerations,
        uint256 startIndex
    ) internal view {
        // Put consideration length onto the stack.
        uint256 considerationLength = considerations.length;

        // Must be at least one consideration item.
        if (considerationLength == 0) {
            revert Errors.CreatePolicy_ConsiderationCountZero();
        }

        // Must not exceed maximum consideration item amount.
        if (considerationLength > STORE.maxConsiderationItems()) {
            revert Errors.CreatePolicy_ConsiderationCountExceedsMax(considerationLength);
        }

        // Process each consideration item.
        for (uint256 i; i < considerationLength; ++i) {
            // Get the consideration item.
            ReceivedItem memory consideration = considerations[i];

            // Only process an ERC20 item.
            if (!consideration.isERC20()) {
                revert Errors.CreatePolicy_SeaportItemTypeNotSupported(
                    consideration.itemType
                );
            }

            // An ERC20 consideration item is considered a payment to the lender upon
            // expiration of the rental order.
            rentalItems[i + startIndex] = Item({
                itemType: ItemType.ERC20,
                settleTo: SettleTo.LENDER,
                token: consideration.token,
                amount: consideration.amount,
                identifier: consideration.identifier
            });
        }
    }

    /**
     * @dev Processes the consideration items for inclusion in a PAYEE order. All
     *      consideration items must adhere to the PAYEE order format, else
     *      execution will revert.
     *
     * @param considerations Array of consideration items to include in the the order.
     */
    function _processPayeeOrderConsideration(
        Item[] memory rentalItems,
        ReceivedItem[] memory considerations,
        uint256 startIndex
    ) internal view {
        // Keep track of each item type.
        uint256 totalRentals;
        uint256 totalPayments;

        // Define elements of the item which depend on the token type.
        ItemType itemType;
        SettleTo settleTo;

        // Put consideration length onto the stack.
        uint256 considerationLength = considerations.length;

        // Must not exceed maximum consideration item amount.
        if (considerationLength > STORE.maxConsiderationItems()) {
            revert Errors.CreatePolicy_ConsiderationCountExceedsMax(considerationLength);
        }

        // Process each consideration item.
        for (uint256 i; i < considerationLength; ++i) {
            // Get the consideration item.
            ReceivedItem memory consideration = considerations[i];

            // Process an ERC721 item.
            if (consideration.isERC721()) {
                // The ERC1155 will be returned to the lender upon expiration
                // of the rental order.
                itemType = ItemType.ERC721;
                settleTo = SettleTo.LENDER;

                // Increment rentals.
                totalRentals++;
            }
            // Process an ERC1155 item
            else if (consideration.isERC1155()) {
                // The ERC1155 will be returned to the lender upon expiration
                // of the rental order.
                itemType = ItemType.ERC1155;
                settleTo = SettleTo.LENDER;

                // Increment rentals.
                totalRentals++;
            }
            // Process an ERC20 item.
            else if (consideration.isERC20()) {
                // An ERC20 offer item is considered a payment to the renter upon
                // expiration of the rental order.
                itemType = ItemType.ERC20;
                settleTo = SettleTo.RENTER;

                // Increment payments.
                totalPayments++;
            }
            // Revert if unsupported item type.
            else {
                revert Errors.CreatePolicy_SeaportItemTypeNotSupported(
                    consideration.itemType
                );
            }

            // Create the item.
            rentalItems[i + startIndex] = Item({
                itemType: itemType,
                settleTo: settleTo,
                token: consideration.token,
                amount: consideration.amount,
                identifier: consideration.identifier
            });
        }

        // PAYEE order consideration must have at least one rental and one payment.
        if (totalRentals == 0 || totalPayments == 0) {
            revert Errors.CreatePolicy_ItemCountZero(totalRentals, totalPayments);
        }
    }

    /**
     * @dev Converts an offer array and a consideration array into a single array of
     *      `Item` which comprise a rental order. The offers and considerations must
     *      adhere to a specific set of rules depending on the type of order being
     *      constructed.
     *
     * @param offers         Array of Seaport offer items.
     * @param considerations Array of seaport consideration items.
     * @param orderType      Order type of the rental.
     */
    function _convertToItems(
        SpentItem[] memory offers,
        ReceivedItem[] memory considerations,
        OrderType orderType
    ) internal view returns (Item[] memory items) {
        // Initialize an array of items.
        items = new Item[](offers.length + considerations.length);

        // Process items for a base order.
        if (orderType.isBaseOrder()) {
            // Process offer items.
            _processBaseOrderOffer(items, offers, 0);

            // Process consideration items.
            _processBaseOrderConsideration(items, considerations, offers.length);
        }
        // Process items for a pay order.
        else if (orderType.isPayOrder()) {
            // Process offer items.
            _processPayOrderOffer(items, offers, 0);

            // Assert that no consideration items are provided.
            if (considerations.length > 0) {
                revert Errors.CreatePolicy_ConsiderationCountNonZero(
                    considerations.length
                );
            }
        }
        // Process items for a payee order.
        else if (orderType.isPayeeOrder()) {
            // Assert that no offer items are provided.
            if (offers.length > 0) {
                revert Errors.CreatePolicy_OfferCountNonZero(offers.length);
            }

            // Process consideration items.
            _processPayeeOrderConsideration(items, considerations, 0);
        }
        // Revert if order type is not supported.
        else {
            revert Errors.Shared_OrderTypeNotSupported(uint8(orderType));
        }
    }

    /**
     * @dev When a rental order is created, process each hook one by one but only if
     *      the hook's status is set to execute on a rental start.
     *
     * @param hooks        Array of hooks to process for the order.
     * @param offerItems   Array of offer items which are referenced by the hooks
     * @param rentalWallet Address of the rental wallet which is the recipient
     *                     of the rented assets.
     */
    function _addHooks(
        Hook[] memory hooks,
        SpentItem[] memory offerItems,
        address rentalWallet
    ) internal {
        // Define hook target, offer item index, and an offer item.
        address target;
        uint256 itemIndex;
        SpentItem memory offer;

        // Loop through each hook in the payload.
        for (uint256 i = 0; i < hooks.length; ++i) {
            // Get the hook's target address.
            target = hooks[i].target;

            // Check that the hook is reNFT-approved to execute on rental start.
            if (STORE.hookOnStart(target)) {
                // Get the offer item index for this hook.
                itemIndex = hooks[i].itemIndex;

                // Get the offer item for this hook.
                offer = offerItems[itemIndex];

                // Make sure the offer item is an ERC721 or ERC1155.
                if (!offer.isRental()) {
                    revert Errors.Shared_NonRentalHookItem(itemIndex);
                }

                // Call the hook with data about the rented item.
                try
                    IHook(target).onStart(
                        rentalWallet,
                        offer.token,
                        offer.identifier,
                        offer.amount,
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

    /**
     * @dev Initiates a rental order using a rental payload received by the fulfiller,
     *      and a payload from seaport with data involving the assets that were
     *      transferred in the order.
     *
     * @param payload Payload from the order fulfiller.
     * @param seaportPayload Payload containing the result of a seaport order fulfillment.
     */
    function _rentFromZone(
        RentPayload memory payload,
        SeaportPayload memory seaportPayload
    ) internal {
        // Check: Only full restricted orders are supported.
        _isValidSeaportOrderType(seaportPayload.orderType);

        // Check: The payload is being used for the correct order.
        _isValidPayloadForOrder(payload.orderHash, seaportPayload.orderHash);

        // Check: make sure order metadata is valid with the given seaport order zone hash.
        _isValidOrderMetadata(payload.metadata, seaportPayload.zoneHash);

        // Check: verify the fulfiller of the order is an owner of the recipient safe.
        _isValidSafeOwner(seaportPayload.fulfiller, payload.fulfillment.recipient);

        // Check: verify the offerer is not the recipient of any consideration items.
        _offererNotRecipient(seaportPayload.offerer, seaportPayload.consideration);

        // Check: verify each execution was sent to the expected destination.
        _executionInvariantChecks(seaportPayload.totalExecutions);

        // Check: validate and process seaport offer and consideration items based
        // on the order type.
        Item[] memory items = _convertToItems(
            seaportPayload.offer,
            seaportPayload.consideration,
            payload.metadata.orderType
        );

        // Check: Once all items have been processed, confirm that all items adhere to the
        // protocol whitelist for rented assets and payments.
        _checkProtocolWhitelist(items);

        // PAYEE orders are considered mirror-images of a PAY order. So, PAYEE orders
        // do not need to be processed in the same way that other order types do.
        if (
            payload.metadata.orderType.isBaseOrder() ||
            payload.metadata.orderType.isPayOrder()
        ) {
            // Create an accumulator which will hold all of the rental asset updates, consisting of IDs and
            // the rented amount. From this point on, new memory cannot be safely allocated until the
            // accumulator no longer needs to include elements.
            bytes memory rentalAssetUpdates = new bytes(0);

            // Check if each item is a rental. If so, then generate the rental asset update.
            // Memory will become safe again after this block.
            for (uint256 i; i < items.length; ++i) {
                if (items[i].isRental()) {
                    // Insert the rental asset update into the dynamic array.
                    _insert(
                        rentalAssetUpdates,
                        items[i].toRentalId(payload.fulfillment.recipient),
                        items[i].amount
                    );
                }
            }

            // Generate the rental order.
            RentalOrder memory order = RentalOrder({
                seaportOrderHash: seaportPayload.orderHash,
                items: items,
                hooks: payload.metadata.hooks,
                orderType: payload.metadata.orderType,
                lender: seaportPayload.offerer,
                renter: payload.intendedFulfiller,
                rentalWallet: payload.fulfillment.recipient,
                startTimestamp: block.timestamp,
                endTimestamp: block.timestamp + payload.metadata.rentDuration
            });

            // Compute the order hash.
            bytes32 orderHash = _deriveRentalOrderHash(order);

            // Invariant: Add rentals to storage before any other processing, and only
            // if the order is a Base Order or Pay order.
            STORE.addRentals(orderHash, _convertToStatic(rentalAssetUpdates));

            // Interaction: Send tokens to their expected destinations. The rented assets
            // will go to the rental wallet and the payments will go to the escrow.
            for (uint256 i = 0; i < items.length; ++i) {
                Item memory item = items[i];

                if (item.isERC20()) {
                    // Send tokens to the payment escrow.
                    item.token.transferERC20(address(ESCRW), item.amount);

                    // increase deposit on the escrow
                    ESCRW.increaseDeposit(item.token, item.amount);
                } else if (item.isERC721()) {
                    // Send ERC721 to the rental wallet.
                    item.transferERC721(order.rentalWallet);
                } else if (item.isERC1155()) {
                    // Send ERC1155 to the rental wallet.
                    item.transferERC1155(order.rentalWallet);
                }
            }

            // Interaction: Process the hooks associated with this rental.
            if (payload.metadata.hooks.length > 0) {
                _addHooks(
                    payload.metadata.hooks,
                    seaportPayload.offer,
                    payload.fulfillment.recipient
                );
            }

            // Emit rental order started.
            _emitRentalOrderStarted(order, orderHash, payload.metadata.emittedExtraData);
        }
    }

    /**
     * @dev Checks that the seaport order type is supported.
     *
     * @param orderType Order type for the order to fulfill.
     */
    function _isValidSeaportOrderType(SeaportOrderType orderType) internal pure {
        if (orderType != SeaportOrderType.FULL_RESTRICTED) {
            revert Errors.CreatePolicy_SeaportOrderTypeNotSupported(orderType);
        }
    }

    /**
     * @dev Checks that a payload is being used for the correct seaport order.
     *
     * @param payloadOrderHash Order hash that the payload expects.
     * @param seaportOrderHash Order hash of the order being fulfilled.
     */
    function _isValidPayloadForOrder(
        bytes32 payloadOrderHash,
        bytes32 seaportOrderHash
    ) internal pure {
        if (payloadOrderHash != seaportOrderHash) {
            revert Errors.CreatePolicy_InvalidPayloadForOrderHash(
                payloadOrderHash,
                seaportOrderHash
            );
        }
    }

    /**
     * @dev Checks that the order metadata passed with the seaport order is expected.
     *
     * @param metadata Order metadata that was passed in with the fulfillment.
     * @param zoneHash Hash of the order metadata that was passed in when the Seaport
     *                 order was signed.
     */
    function _isValidOrderMetadata(
        OrderMetadata memory metadata,
        bytes32 zoneHash
    ) internal view {
        // Check that the rent duration specified is not too long.
        if (STORE.maxRentDuration() < metadata.rentDuration) {
            revert Errors.CreatePolicy_RentDurationTooLong(metadata.rentDuration);
        }

        // Check that the rent duration specified is not zero.
        if (metadata.rentDuration == 0) {
            revert Errors.CreatePolicy_RentDurationZero();
        }

        // Check that the zone hash is equal to the derived hash of the metadata.
        if (_deriveOrderMetadataHash(metadata) != zoneHash) {
            revert Errors.CreatePolicy_InvalidOrderMetadataHash();
        }
    }

    /**
     * @dev Checks that an address is the owner of a protocol-deployed rental safe.
     *
     * @param owner Address of the potential safe owner.
     * @param safe  Address of the potential protocol-deployed rental safe.
     */
    function _isValidSafeOwner(address owner, address safe) internal view {
        // Make sure only protocol-deployed safes can rent.
        if (STORE.deployedSafes(safe) == 0) {
            revert Errors.CreatePolicy_InvalidRentalSafe(safe);
        }

        // Make sure the fulfiller is the owner of the recipient rental safe.
        if (!ISafe(safe).isOwner(owner)) {
            revert Errors.CreatePolicy_InvalidSafeOwner(owner, safe);
        }
    }

    /**
     * @dev Checks that none of the consideration item recipients are set to the offerer
     * of the order. Since seaport views these consideration items as a no-op, it will
     * result in them not being included in the array of `totalExecutions`.
     *
     * @param offerer 		 Address of the order offerer.
     * @param considerations Each consideration item in the order being processed.
     */
    function _offererNotRecipient(
        address offerer,
        ReceivedItem[] memory considerations
    ) internal pure {
        for (uint256 i = 0; i < considerations.length; ++i) {
            if (offerer == considerations[i].recipient) {
                revert Errors.CreatePolicy_OffererCannotBeRecipient();
            }
        }
    }

    /**
     * @dev After a Seaport order has been executed, invariant checks are made to ensure
     *      that all assets were sent to the correct address. More specifically, all
     *      tokens must first be sent to the Create Policy.
     *
     * @param executions Each execution that was performed by Seaport.
     */
    function _executionInvariantChecks(ReceivedItem[] memory executions) internal view {
        for (uint256 i = 0; i < executions.length; ++i) {
            ReceivedItem memory execution = executions[i];

            // All tokens must first be sent to the Create Policy.
            if (execution.recipient != address(this)) {
                revert Errors.CreatePolicy_UnexpectedTokenRecipient(
                    execution.itemType,
                    execution.token,
                    execution.identifier,
                    execution.amount,
                    execution.recipient,
                    address(this)
                );
            }
        }
    }

    /**
     * @dev Determines if an array of items are supported by the protocol whitelist.
     *
     * @param items The items generated by the incoming rental order.
     */
    function _checkProtocolWhitelist(Item[] memory items) internal view {
        for (uint256 i = 0; i < items.length; ++i) {
            // Get the token address for the item
            address token = items[i].token;

            // Check that a rented asset exists in the whitelisted assets mapping.
            if (items[i].isRental() && !STORE.assetEnabledForRent(token)) {
                revert Errors.CreatePolicy_AssetNotWhitelisted(token);
            }

            // Check that a payment exists in the whitelisted payments mapping.
            if (items[i].isERC20() && !STORE.whitelistedPayments(token)) {
                revert Errors.CreatePolicy_PaymentNotWhitelisted(token);
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Callback function implemented to make this contract a valid Seaport zone.
     *         It can be considered the entrypoint to creating a rental. When a seaport
     *         order specifies the create policy as its zone address, Seaport will call
     *         this function after each order in the batch is processed. A call to
     *         `validateOrder` is what kicks off the rental process, and performs steps
     *         to convert a seaport order into a rental order which is stored
     *         by the protocol.
     *
     * @param zoneParams Parameters from the seaport order.
     *
     * @return validOrderMagicValue A `bytes4` value to return back to Seaport.
     */
    function validateOrder(
        ZoneParameters calldata zoneParams
    ) external override onlyRole("SEAPORT") returns (bytes4 validOrderMagicValue) {
        // Decode the signed rental zone payload from the extra data.
        (RentPayload memory payload, bytes memory signature) = abi.decode(
            zoneParams.extraData,
            (RentPayload, bytes)
        );

        // Create a payload of seaport data.
        SeaportPayload memory seaportPayload = SeaportPayload({
            orderHash: zoneParams.orderHash,
            zoneHash: zoneParams.zoneHash,
            offer: zoneParams.offer,
            consideration: zoneParams.consideration,
            totalExecutions: zoneParams.totalExecutions,
            fulfiller: zoneParams.fulfiller,
            offerer: zoneParams.offerer,
            orderType: zoneParams.orderType
        });

        // Generate the rent payload hash.
        bytes32 rentPayloadHash = _deriveRentPayloadHash(payload);

        // Recover the signer from the payload.
        address signer = _recoverSignerFromPayload(rentPayloadHash, signature);

        // Check: The signature from the protocol signer has not expired.
        _validateProtocolSignatureExpiration(payload.expiration);

        // Check: The fulfiller is the intended fulfiller.
        _validateFulfiller(payload.intendedFulfiller, seaportPayload.fulfiller);

        // Check: The data matches the signature and that the protocol signer is the one that signed.
        if (!kernel.hasRole(signer, toRole("CREATE_SIGNER"))) {
            revert Errors.CreatePolicy_UnauthorizedCreatePolicySigner(signer);
        }

        // Initiate the rental using the rental manager.
        _rentFromZone(payload, seaportPayload);

        // Return the selector of validateOrder as the magic value.
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface ID to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Zone, TokenReceiver) returns (bool) {
        return
            Zone.supportsInterface(interfaceId) ||
            TokenReceiver.supportsInterface(interfaceId);
    }
}
