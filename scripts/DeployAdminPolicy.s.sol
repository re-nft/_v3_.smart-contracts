// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the admin policy
contract DeployAdminPolicy is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // generate the salt
        bytes32 salt = _generateSaltWithSender(deployer, protocolVersion);

        // deploy the admin policy
        _deployAdminPolicy(salt);

        // set up the admin policy
        _setUpPolicy(address(admin));

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // output addresses
        console2.log("Admin Policy:  %s", address(admin));

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
