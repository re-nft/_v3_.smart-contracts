// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Enum} from "@safe-contracts/common/Enum.sol";

import {ISafe} from "@src/interfaces/ISafe.sol";
import {Guard} from "@src/policies/Guard.sol";
import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";

// Represents a guard policy which a rental safe owner can opt into
contract GuardUpgrade is Guard {
    constructor(Kernel kernel_) Guard(kernel_) {}

    // Simple function that demonstrates the upgrade was successful
    function upgradeSuccess() external pure returns (bool) {
        return true;
    }
}

// The protocol can whitelist this contract to allow delegate calls to it. By doing so,
// the rental wallet will be able to upgrade to a new version of the policy
contract GuardPolicyMigration {
    // The original address that was this contract was deployed at
    address private immutable original;

    // The address of the new policy
    address public immutable newPolicy;

    // emits when a rental safe has upgraded its policy and disabled an old version
    event UpgradedPolicy(address rentalSafe, address newPolicy);

    constructor(address _newPolicy) {
        // set the original deployment address
        original = address(this);

        // set the new policy
        newPolicy = _newPolicy;
    }

    // Upgrades the safe to use a new version of the policy
    function upgrade() public {
        require(
            address(this) != original,
            "Upgrade should only be called via delegatecall"
        );

        // enable the new module
        ISafe(address(this)).setGuard(newPolicy);

        // emit the event
        emit UpgradedPolicy(address(this), newPolicy);
    }
}
