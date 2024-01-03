// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Errors} from "@src/libraries/Errors.sol";
import {Keycode, Role} from "@src/libraries/RentalStructs.sol";

/**
 * @dev Converts a bytes5 value into a `Keycode` type.
 *
 * @param keycode_ The value to convert into a `Keycode`.
 */
function toKeycode(bytes5 keycode_) pure returns (Keycode) {
    return Keycode.wrap(keycode_);
}

/**
 * @dev Converts a `Keycode` into a bytes5 type.
 *
 * @param keycode_ The value to convert into a bytes5.
 */
function fromKeycode(Keycode keycode_) pure returns (bytes5) {
    return Keycode.unwrap(keycode_);
}

/**
 * @dev Converts a bytes32 value into a `Role` type.
 *
 * @param role_ The value to convert into a `Role`.
 */
function toRole(bytes32 role_) pure returns (Role) {
    return Role.wrap(role_);
}

/**
 * @dev Converts a `Role` into a bytes32 value.
 *
 * @param role_ The value to convert into a bytes32.
 */
function fromRole(Role role_) pure returns (bytes32) {
    return Role.unwrap(role_);
}

/**
 * @dev Ensures the target address is a contract. This is done by checking the length
 *      of the bytecode stored at that address. Note: This function will be used to set
 *      official protocol contracts so it is a highly unlikely situation where the code
 *      size check is performed while the `target_` address is inside its constructor.
 *
 * @param target_ Address to check the bytecode size.
 */
function ensureContract(address target_) view {
    uint256 size;
    assembly ("memory-safe") {
        size := extcodesize(target_)
    }
    if (size == 0) revert Errors.Kernel_TargetNotAContract(target_);
}

/**
 * @dev Ensures a `Keycode` is properly formatted. Keycodes can only be made up of
 *      letters A-Z, must be capitalized, and can only be 5 letters long.
 *
 * @param keycode_ The keycode to check the validity of.
 */
function ensureValidKeycode(Keycode keycode_) pure {
    bytes5 unwrapped = Keycode.unwrap(keycode_);

    for (uint256 i = 0; i < 5; ++i) {
        bytes1 char = unwrapped[i];

        if (char < 0x41 || char > 0x5A) revert Errors.Kernel_InvalidKeycode(keycode_);
    }
}

/**
 * @dev Ensures a `Role` is properly formatted. Roles can only be made up of
 *      letters A-Z, must be capitalized, but with the exception that underscores
 *      are allowed.
 *
 * @param role_ The role to check the validity of.
 */
function ensureValidRole(Role role_) pure {
    bytes32 unwrapped = Role.unwrap(role_);

    for (uint256 i = 0; i < 32; ++i) {
        bytes1 char = unwrapped[i];
        if ((char < 0x41 || char > 0x5A) && char != 0x5F && char != 0x00) {
            revert Errors.Kernel_InvalidRole(role_); // A-Z only, allow underscores
        }
    }
}
