// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {BaseEngine} from "@test/fixtures/engine/BaseEngine.sol";
import {BaseProtocol} from "@test/fixtures/protocol/BaseProtocol.sol";
import {Assertions} from "@test/utils/Assertions.sol";
import {Constants} from "@test/utils/Constants.sol";

contract BaseTest is BaseEngine, Assertions, Constants {
    // This is an explicit entrypoint that all test contracts should inherit from.
    //
    // It contains logic for:
    // - setup of the entire protocol architecture
    // - setup of the test engine
    //
    // The inheritance chain is as follows:
    // BaseExternal
    // --> BaseProtocol
    //     --> BaseEngine
    //         --> BaseTest
}

contract BaseTestWithoutEngine is BaseProtocol, Assertions, Constants {
    // This is an explicit entrypoint that all test contracts should inherit from.
    //
    // It contains logic for:
    // - setup of the entire protocol architecture
    // - setup of the test engine
    //
    // The inheritance chain is as follows:
    // BaseExternal
    // --> BaseProtocol
    //     --> BaseTestWithoutEngine
}
