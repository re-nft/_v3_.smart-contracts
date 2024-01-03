// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SafeL2} from "@safe-contracts/SafeL2.sol";

// Defines a protocol account which consists of an EOA and a
// deployed rental safe where the EOA is the owner of the safe.
struct ProtocolAccount {
    // Address of the EOA
    address addr;
    // Address of the deployed rental safe
    SafeL2 safe;
    // Public key X of the EOA
    uint256 publicKeyX;
    // Public key Y of the EOA
    uint256 publicKeyY;
    // Private key of the EOA. can be used to sign data.
    uint256 privateKey;
}
