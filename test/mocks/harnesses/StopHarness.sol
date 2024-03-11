// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ReceivedItem, SpentItem} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Kernel} from "@src/Kernel.sol";
import {Stop} from "@src/policies/Stop.sol";
import {
    Item,
    OrderType,
    OrderMetadata,
    Hook,
    RentalOrder
} from "@src/libraries/RentalStructs.sol";

contract StopHarness is Stop {
    constructor(Kernel kernel_) Stop(kernel_) {}

    function validateRentalCanBeStopped(
        OrderType orderType,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address expectedLender
    ) external view {
        _validateRentalCanBeStopped(
            orderType,
            startTimestamp,
            endTimestamp,
            expectedLender
        );
    }

    function reclaimRentedItems(RentalOrder memory order) external {
        _reclaimRentedItems(order);
    }

    function removeHooks(
        Hook[] calldata hooks,
        Item[] calldata rentalItems,
        address rentalWallet
    ) external {
        _removeHooks(hooks, rentalItems, rentalWallet);
    }
}
