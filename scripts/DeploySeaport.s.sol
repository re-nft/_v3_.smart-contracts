// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the seaport contracts
contract DeploySeaport is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // generate the salt
        bytes32 salt = _generateSaltWithSender(deployer, protocolVersion);

        // deploy the conduit controller
        _deployConduitController();

        // deploy seaport
        _deploySeaport();

        // deploy conduit
        _deployConduit(salt);

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // output addresses
        console2.log("Seaport:              %s", address(seaport));
        console2.log("Conduit Controller:   %s", address(conduitController));
        console2.log("Conduit:              %s", address(conduit));
        console2.log("Conduit Key:          %s", _bytes32ToString(conduitKey));

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
