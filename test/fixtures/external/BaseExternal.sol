// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {External_Create2Deployer} from "@test/fixtures/external/Create2Deployer.sol";
import {External_Seaport} from "@test/fixtures/external/Seaport.sol";
import {External_Safe} from "@test/fixtures/external/Safe.sol";

contract BaseExternal is External_Create2Deployer, External_Seaport, External_Safe {
    // This is an explicit entrypoint for all external contracts that the V3 protocol depends on.
    //
    // It contains logic for:
    // - setup of the Create2Deployer contract
    // - setup of all Seaport protocol contracts
    // - setup of all Gnosis Safe protocol contracts
    //
    // The inheritance chain is as follows:
    // External_Create2Deployer + External_Seaport + External_Safe
    // --> BaseExternal

    function setUp()
        public
        virtual
        override(External_Create2Deployer, External_Seaport, External_Safe)
    {
        // set up dependencies
        External_Create2Deployer.setUp();
        External_Seaport.setUp();
        External_Safe.setUp();
    }
}
