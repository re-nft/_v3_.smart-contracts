// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the payment escrow module
contract DeployPaymentEscrowModule is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // generate the salt
        bytes32 salt = _generateSaltWithSender(deployer, protocolVersion);

        // deploy the payment escrow module
        _deployPaymentEscrowModule(salt);

        // set up the module
        _setUpModule(address(ESCRW));

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // output addresses
        console2.log("ESCRW Module:          %s", address(ESCRW));
        console2.log("ESCRW logic contract:  %s", address(ESCRW_IMPL));

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
