// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Policy} from "@src/Kernel.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Update the asset whitelist
contract UpdatePolicyActivationStatus is BaseDeploy {
    function run(string memory chain, address policy, bool isActive) public {
        super.run(chain);

        // Set the asset whitelist
        if (isActive) {
            _setUpPolicy(policy);
        } else {
            _deactivatePolicy(policy);
        }

        // Output activation status
        console2.log("Policy:    %s", policy);
        console2.log("Is Active: %s", Policy(policy).isActive());
    }
}
