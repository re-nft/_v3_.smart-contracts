// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the kernel
contract DeployKernel is BaseDeploy {
    function run() public {
        super.run(chain);

        // generate the salt
        bytes32 salt = _generateSaltWithSender(deployer, protocolVersion);

        // deploy the kernel
        _deployKernel(salt);

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        //output addresses
        console2.log("Kernel:  %s", address(kernel));

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
