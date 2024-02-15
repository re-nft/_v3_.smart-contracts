// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {AccountCreator} from "@test/fixtures/protocol/AccountCreator.sol";

contract BaseProtocol is AccountCreator {
    // This is an explicit entrypoint for the setup and deployment of the V3 protocol.
    //
    // It contains logic for:
    // - setup of mock tokens to interact with the protocol
    // - setup of the v3 protocol architecture
    // - setup of test accounts to interact with the protocol
    //
    // The inheritance chain is as follows:
    // BaseExternal
    // --> TokenCreator
    //     --> Protocol
    //         --> AccountCreator
    //             --> BaseProtocol
}
