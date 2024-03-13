// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the storage module
contract DeployStorageModule is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // generate the salt
        bytes32 salt = _generateSaltWithSender(deployer, protocolVersion);

        // deploy the storage module
        _deployStorageModule(salt);

        // set up the module
        _setUpModule(address(STORE));

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // output addresses
        console2.log("STORE Module:          %s", address(STORE));
        console2.log("STORE logic contract:  %s", address(STORE_IMPL));

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
