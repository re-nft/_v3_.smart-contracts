// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    ReceivedItem,
    SpentItem,
    OrderType as SeaportOrderType
} from "@seaport-types/lib/ConsiderationStructs.sol";

/////////////////////////////////////////////////////////////////////////////////
//                           Order Creation Structs                            //
/////////////////////////////////////////////////////////////////////////////////

/**
 * @dev Defines the supported order types in a rental. BASE orders require that rental
 *      assets are offered up in exchange for some ERC20 payment. PAY orders must contain
 *      only offer items where at least one is a rental asset and at least one is a
 *      payment. These orders are paired with PAYEE orders only contain consideration
 *      items where at least one is a rental asset and at least one is a payment.
 */
enum OrderType {
    // Offer items: all must be ERC721/ERC1155.
    // Consideration items: all must be ERC20.
    BASE,
    // Offer items: at least one ERC721/ERC1155, at least one ERC20.
    // Consideration items: none.
    PAY,
    // Offer items: none.
    // Consideration items: at least one ERC721/ERC1155, at least one ERC20.
    PAYEE
}

/**
 * @dev A hook contains three components: an address of the hook which will activate if a
 *      path is present to the hook, the index of the item associated with this hook in
 *      the order (it will always be an offer item), and any arbitrary data that the
 *      offerer deems important to pass along to the call with the hook on rental start.
 */
struct Hook {
    // The hook contract.
    address target;
    // Index of the item in the order to apply the hook to.
    uint256 itemIndex;
    // Any extra data that the hook will need.
    bytes extraData;
}

/**
 * @dev Order metadata contains all the details supplied by the offerer when they sign an
 *      order. These items include the type of rental order, how long the rental will be
 *      active, any hooks associated with the order, and any data that should be emitted
 *      when the rental starts.
 */
struct OrderMetadata {
    // Type of order being created.
    OrderType orderType;
    // Duration of the rental in seconds.
    uint256 rentDuration;
    // Hooks that will act as middleware for the items in the order.
    Hook[] hooks;
    // Any extra data to be emitted upon order fulfillment.
    bytes emittedExtraData;
}

/**
 * @dev Order fulfillment data contains details supplied by the fulfiller of the order.
 *      Currently, the only data needed is the expected rental wallet address which will
 *      receive the rented assets. This address is used to check against the fulfiller of
 *      the order to make sure they are the owner of the rental safe recipient address.
 */
struct OrderFulfillment {
    // Rental wallet address.
    address recipient;
}

/////////////////////////////////////////////////////////////////////////////////
//                             Rental Order Structs                            //
/////////////////////////////////////////////////////////////////////////////////

/**
 * @dev Defines the different types of assets that a rental order supports.
 */
enum ItemType {
    // ERC721 assets.
    ERC721,
    // ERC1155 assets.
    ERC1155,
    // ERC20 assets.
    ERC20
}

/**
 * @dev Defines which party will receive an asset after a rental is settled.
 */
enum SettleTo {
    // Lender of the rental order.
    LENDER,
    // Renter of the rental order.
    RENTER
}

/**
 * @dev Defines a rental ID which is a hash of unique markers on an asset. Namely, the
 *      recipient of the asset, the asset address, and the asset identifier.
 */
type RentalId is bytes32;

/**
 * @dev Used to transport rental asset update information. Contains data for a
 *      single rental asset: a rental ID and the amount of tokens rented.
 */
struct RentalAssetUpdate {
    RentalId rentalId;
    uint256 amount;
}

/**
 * @dev Defines an item which is part of a rental order. Contains item type, EOA to
 *      settle the asset to, address of the token, amount of the token rented, and
 *      identifier of the token.
 */
struct Item {
    ItemType itemType;
    SettleTo settleTo;
    address token;
    uint256 amount;
    uint256 identifier;
}

/**
 * @dev Defines a rental order. This order is contructed from a single seaport order when
 *      a rental is created. To stop a rental, this order will need to be provided back
 *      to the protocol. Since it is not stored in long form, an event is emitted when
 *      the rental is started to provide all the data necessary to reconstruct the rental
 *      order.
 */
struct RentalOrder {
    bytes32 seaportOrderHash;
    Item[] items;
    Hook[] hooks;
    OrderType orderType;
    address lender;
    address renter;
    address rentalWallet;
    uint256 startTimestamp;
    uint256 endTimestamp;
}

/////////////////////////////////////////////////////////////////////////////////
//                               Payload Structs                               //
/////////////////////////////////////////////////////////////////////////////////

/**
 * @dev Used as a vehicle for extra data that is needed for the rental, which is provided to
 *      the seaport order during fulfillment. The hash of the metadata is checked against
 *      the hash stored in the signed seaport order to make sure the data matches.
 */
struct RentPayload {
    bytes32 orderHash;
    OrderFulfillment fulfillment;
    OrderMetadata metadata;
    uint256 expiration;
    address intendedFulfiller;
}

/**
 * @dev Converts data received from the seaport zone contract into a single struct that
 *      is easier to work with during rental creation.
 */
struct SeaportPayload {
    bytes32 orderHash;
    bytes32 zoneHash;
    SpentItem[] offer;
    ReceivedItem[] consideration;
    ReceivedItem[] totalExecutions;
    address fulfiller;
    address offerer;
    SeaportOrderType orderType;
}

/////////////////////////////////////////////////////////////////////////////////
//                              Kernel Structs                                 //
/////////////////////////////////////////////////////////////////////////////////

/**
 * @dev Defines the actions which can be carried out by the executor of the kernel.
 */
enum Actions {
    // Installs a new module.
    InstallModule,
    // Changes the 5-character keycode from one module to point to a new module.
    UpgradeModule,
    // Grants a policy's access to module permissioned module functionality.
    ActivatePolicy,
    // Revokes a policy's access to permissioned module functionality.
    DeactivatePolicy,
    // Changes the address of the executor role.
    ChangeExecutor,
    // Changes the address of the admin role.
    ChangeAdmin,
    // Migrates the kernel to a new contract. This can only be done once per contract.
    MigrateKernel
}

/**
 * @dev Defines permission for a policy to have access to the `funcSelector` at a
 *      specific module contract via its keycode.
 */
struct Permissions {
    Keycode keycode;
    bytes4 funcSelector;
}

/**
 * @dev A 5-character keycode that references a module contract.
 */
type Keycode is bytes5;

/**
 * @dev A unique role which can be granted or revoked by the admin.
 */
type Role is bytes32;
