// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

contract MismatchUUID {
    function proxiableUUID() public pure returns (bytes32) {
        return keccak256("mismatched UUID");
    }
}
