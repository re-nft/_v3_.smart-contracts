// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Kernel} from "@src/Kernel.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";

// Represents a payment escrow module upgrade contract
contract PaymentEscrowUpgrade is PaymentEscrow {
    constructor(Kernel kernel_) PaymentEscrow(kernel_) {}

    // Simple function that demonstrates the upgrade was successful
    function upgradeSuccess() external pure returns (bool) {
        return true;
    }
}
