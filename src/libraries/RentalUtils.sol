// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    ReceivedItem,
    SpentItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";

import {
    RentalOrder,
    RentalId,
    RentalAssetUpdate,
    Item,
    ItemType,
    OrderType
} from "@src/libraries/RentalStructs.sol";

/**
 * @title RentalUtils
 * @notice Contains logic for working with rental IDs and various assertion
 *         helper functions.
 */
library RentalUtils {
    /////////////////////////////////////////////////////////////////////////////////
    //                               Rental ID Utils                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Generates a hashed `RentalId` type out of a recipient, token, and identifier.
     *
     * @param recipient  Address which will receive the rental asset.
     * @param token      Address of the rental asset.
     * @param identifier Identifier for the rental asset.
     *
     * @return id Rental ID generated from the input values.
     */
    function getItemPointer(
        address recipient,
        address token,
        uint256 identifier
    ) internal pure returns (RentalId id) {
        id = RentalId.wrap(keccak256(abi.encodePacked(recipient, token, identifier)));
    }

    /**
     * @dev Converts an `Item` and a recipient address into a `RentalId`.
     *
     * @param rentalItem The item to convert into a `RentalId`.
     * @param recipient  Address which will receive the rental asset.
     *
     * @return rentalId Rental ID generated from the input values.
     *
     */
    function toRentalId(
        Item memory rentalItem,
        address recipient
    ) internal pure returns (RentalId rentalId) {
        // Convert the rental item into a rental ID.
        return getItemPointer(recipient, rentalItem.token, rentalItem.identifier);
    }

    /**
     * @dev Converts an array of `Item` and a recipient address into an array of
     *      `RentalId`.
     *
     * @param rentalItems The items to convert into a `RentalId` array.
     * @param recipient   Address which will receive the rental asset.
     *
     * @return rentalIds Rental IDs generated from the input values.
     */
    function toRentalIds(
        Item[] memory rentalItems,
        address recipient
    ) internal pure returns (RentalId[] memory rentalIds) {
        rentalIds = new RentalId[](rentalItems.length);

        for (uint256 i; i < rentalIds.length; ++i) {
            // Convert the rental item into a rental ID.
            rentalIds[i] = getItemPointer(
                recipient,
                rentalItems[i].token,
                rentalItems[i].identifier
            );
        }
    }

    /**
     * @dev Converts an `Item` and a recipient address into a `RentalAssetUpdate`.
     *
     * @param item      The item to convert into a `RentalAssetupdate`.
     * @param recipient Address which will receive the rental asset.
     */
    function toRentalAssetUpdate(
        Item memory item,
        address recipient
    ) internal pure returns (RentalAssetUpdate memory rentalAssetupdate) {
        return RentalAssetUpdate(toRentalId(item, recipient), item.amount);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                               Item Assertions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Asserts whether an `Item` represents an ERC721 token.
     *
     * @return Whether the item is an ERC721 token.
     */
    function isERC721(Item memory item) internal pure returns (bool) {
        return item.itemType == ItemType.ERC721;
    }

    /**
     * @dev Asserts whether a `SpentItem` represents an ERC721 token.
     *
     * @return Whether the item is an ERC721 token.
     */
    function isERC721(SpentItem memory item) internal pure returns (bool) {
        return item.itemType == SeaportItemType.ERC721;
    }

    /**
     * @dev Asserts whether a `ReceivedItem` represents an ERC721 token.
     *
     * @return Whether the item is an ERC721 token.
     */
    function isERC721(ReceivedItem memory item) internal pure returns (bool) {
        return item.itemType == SeaportItemType.ERC721;
    }

    /**
     * @dev Asserts whether an `Item` represents an ERC1155 token.
     *
     * @return Whether the item is an ERC1155 token.
     */
    function isERC1155(Item memory item) internal pure returns (bool) {
        return item.itemType == ItemType.ERC1155;
    }

    /**
     * @dev Asserts whether a `SpentItem` represents an ERC1155 token.
     *
     * @return Whether the item is an ERC1155 token.
     */
    function isERC1155(SpentItem memory item) internal pure returns (bool) {
        return item.itemType == SeaportItemType.ERC1155;
    }

    /**
     * @dev Asserts whether a `ReceivedItem` represents an ERC1155 token.
     *
     * @return Whether the item is an ERC1155 token.
     */
    function isERC1155(ReceivedItem memory item) internal pure returns (bool) {
        return item.itemType == SeaportItemType.ERC1155;
    }

    /**
     * @dev Asserts whether an `Item` represents an ERC20 token.
     *
     * @return Whether the item is an ERC20 token.
     */
    function isERC20(Item memory item) internal pure returns (bool) {
        return item.itemType == ItemType.ERC20;
    }

    /**
     * @dev Asserts whether a `SpentItem` represents an ERC20 token.
     *
     * @return Whether the item is an ERC20 token.
     */
    function isERC20(SpentItem memory item) internal pure returns (bool) {
        return item.itemType == SeaportItemType.ERC20;
    }

    /**
     * @dev Asserts whether a `ReceivedItem` represents an ERC20 token.
     *
     * @return Whether the item is an ERC20 token.
     */
    function isERC20(ReceivedItem memory item) internal pure returns (bool) {
        return item.itemType == SeaportItemType.ERC20;
    }

    /**
     * @dev Asserts whether an `Item` represents a rented asset.
     *
     * @return Whether the item is a rented asset.
     */
    function isRental(Item memory item) internal pure returns (bool) {
        return isERC721(item) || isERC1155(item);
    }

    /**
     * @dev Asserts whether a `SpentItem` represents a rented asset.
     *
     * @return Whether the item is a rented asset.
     */
    function isRental(SpentItem memory item) internal pure returns (bool) {
        return isERC721(item) || isERC1155(item);
    }

    /**
     * @dev Asserts whether a `ReceivedItem` represents a rented asset.
     *
     * @return Whether the item is a rented asset.
     */
    function isRental(ReceivedItem memory item) internal pure returns (bool) {
        return isERC721(item) || isERC1155(item);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              Order Assertions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Asserts whether the order is a Base order.
     *
     * @return Whether the order is a Base order.
     */
    function isBaseOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.BASE;
    }

    /**
     * @dev Asserts whether the order is a Pay order.
     *
     * @return Whether the order is a Pay order.
     */
    function isPayOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.PAY;
    }

    /**
     * @dev Asserts whether the order is a Payee order.
     *
     * @return Whether the order is a Payee order.
     */
    function isPayeeOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.PAYEE;
    }
}
