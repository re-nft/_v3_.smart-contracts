// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

abstract contract Constants {
    // Zero constant
    uint256 constant ZERO = uint256(0);

    // Test addresses
    address constant ZERO_ADDRESS = address(0);
    address constant TEST_ADDR_1 =
        address(uint160(uint256(keccak256(abi.encode("test_addr_1")))));
    address constant TEST_ADDR_2 =
        address(uint160(uint256(keccak256(abi.encode("test_addr_2")))));
    address constant TEST_ADDR_3 =
        address(uint160(uint256(keccak256(abi.encode("test_addr_3")))));
}
