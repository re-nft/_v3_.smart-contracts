// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";

import {Create2Deployer} from "@src/Create2Deployer.sol";

// Deploys the Create2Deployer contract
contract External_Create2Deployer is Test {
    Create2Deployer public create2Deployer;

    function setUp() public virtual {
        // Deploy the create2 deployer contract
        create2Deployer = new Create2Deployer();

        // label the contract
        vm.label(address(create2Deployer), "Create2Deployer");
    }
}
