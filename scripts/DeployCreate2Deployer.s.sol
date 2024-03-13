// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the create2 deployer
contract DeployCreate2Deployer is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // deploy the create2 deployer
        _deployCreate2Deployer();

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // output addresses
        console2.log("Create2 Deployer:  %s", address(create2Deployer));

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
