// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ReceivedItem, SpentItem} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Kernel} from "@src/Kernel.sol";
import {Create} from "@src/policies/Create.sol";
import {Item, OrderType, OrderMetadata, Hook} from "@src/libraries/RentalStructs.sol";

contract CreateHarness is Create {
    constructor(Kernel kernel_) Create(kernel_) {}

    function processBaseOrderOffer(
        Item[] memory rentalItems,
        SpentItem[] memory offer,
        uint256 startIndex
    ) external view returns (Item[] memory processedItems) {
        _processBaseOrderOffer(rentalItems, offer, startIndex);

        // rental items are processed by reference. Set them to a new variable to return by value
        processedItems = rentalItems;
    }

    function processBaseOrderConsideration(
        Item[] memory rentalItems,
        ReceivedItem[] memory consideration,
        uint256 startIndex
    ) external view returns (Item[] memory processedItems) {
        _processBaseOrderConsideration(rentalItems, consideration, startIndex);

        // rental items are processed by reference. Set them to a new variable to return by value
        processedItems = rentalItems;
    }

    function processPayOrderOffer(
        Item[] memory rentalItems,
        SpentItem[] memory offer,
        uint256 startIndex
    ) external view returns (Item[] memory processedItems) {
        _processPayOrderOffer(rentalItems, offer, startIndex);

        // rental items are processed by reference. Set them to a new variable to return by value
        processedItems = rentalItems;
    }

    function processPayeeOrderConsideration(
        Item[] memory rentalItems,
        ReceivedItem[] memory consideration,
        uint256 startIndex
    ) external view {
        _processPayeeOrderConsideration(rentalItems, consideration, startIndex);
    }

    function convertToItems(
        SpentItem[] memory offer,
        ReceivedItem[] memory consideration,
        OrderType orderType
    ) external view returns (Item[] memory items) {
        items = _convertToItems(offer, consideration, orderType);
    }

    function addHooks(
        Hook[] memory hooks,
        SpentItem[] memory offerItems,
        address rentalWallet
    ) external {
        _addHooks(hooks, offerItems, rentalWallet);
    }

    function isValidOrderMetadata(
        OrderMetadata memory metadata,
        bytes32 zoneHash
    ) external view {
        _isValidOrderMetadata(metadata, zoneHash);
    }

    function isValidSafeOwner(address owner, address safe) external view {
        _isValidSafeOwner(owner, safe);
    }

    function executionInvariantChecks(ReceivedItem[] memory executions) external view {
        _executionInvariantChecks(executions);
    }
}
