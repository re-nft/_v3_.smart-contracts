// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Kernel} from "@src/Kernel.sol";
import {Storage} from "@src/modules/Storage.sol";

// Represents a storage module upgrade contract
contract StorageUpgrade is Storage {
    constructor(Kernel kernel_) Storage(kernel_) {}

    // Simple function that demonstrates the upgrade was successful
    function upgradeSuccess() external pure returns (bool) {
        return true;
    }
}
