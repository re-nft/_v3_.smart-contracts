// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Item, ItemType, SettleTo} from "@src/libraries/RentalStructs.sol";

abstract contract Assertions is Test {
    // Compares two `ItemType` enum entities
    function assertEq(ItemType a, ItemType b) internal {
        assertEq(uint256(a), uint256(b), "itemType");
    }

    // Compares two `SettleTo` enum entities
    function assertEq(SettleTo a, SettleTo b) internal {
        assertEq(uint256(a), uint256(b), "settleTo");
    }

    // Compares two `Item` struct entities
    function assertEq(Item memory a, Item memory b) internal {
        assertEq(a.itemType, b.itemType);
        assertEq(a.settleTo, b.settleTo);
        assertEq(a.token, b.token, "token");
        assertEq(a.amount, b.amount, "amount");
        assertEq(a.identifier, b.identifier, "identifier");
    }
}
