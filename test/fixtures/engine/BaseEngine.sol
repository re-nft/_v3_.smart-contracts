// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {OrderFulfiller} from "@test/fixtures/engine/OrderFulfiller.sol";

contract BaseEngine is OrderFulfiller {
    // This is an explicit entrypoint for the test engine.
    //
    // It contains logic for:
    // - setup of the order creator portion of the engine
    // - setup of the order fulfiller portion of the engine
    //
    // The inheritance chain is as follows:
    // BaseProtocol
    // --> OrderCreator
    //     --> OrderFulfiller
    //         --> BaseEngine
}
