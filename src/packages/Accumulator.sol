// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {RentalId, RentalAssetUpdate} from "@src/libraries/RentalStructs.sol";

/**
 * @title Accumulator
 * @notice Package that implements functionality for managing dynamically allocated data
 *         struct arrays directly in memory. The rationale for this was the need for an
 *         array of structs where the total size is not known at instantiation.
 */
abstract contract Accumulator {
    /**
     * @dev Accumulates an intermediary representation of a dynamic array of
     *      `RentalAssetUpdate` structs.
     *
     * In memory, the format of `rentalAssets` will be as follows:
     *
     * 0x00: Length of the intermediary representation bytes data
     * 0x20: Number of `RentalAssetUpdate` elements stored
     * 0x40: `rentalId` of the first element
     * 0x60: `amount` of the first element
     * 0x80: `rentalId` of the second element
     * 0xa0: `amount` of the second element
     * 0xc0: ...
     *
     * @param rentalAssets      Bytes value which will accumulate `RentalAssetUpdate`
     *                          structs.
     * @param rentalId          Rental ID to include in the next `RentalAssetUpdate`.
     * @param rentalAssetAmount Amount to include in the next `RentalAssetUpdate`.
     */
    function _insert(
        bytes memory rentalAssets,
        RentalId rentalId,
        uint256 rentalAssetAmount
    ) internal pure {
        // Place the rental ID on the stack.
        bytes32 _rentalId = RentalId.unwrap(rentalId);

        assembly {
            // This is the first time inserting into this bytes data.
            if eq(mload(rentalAssets), 0) {
                // Create some space for the initial element length word.
                mstore(rentalAssets, 0x20)

                // Zero out the number of elements.
                mstore(add(0x20, rentalAssets), 0x00)
            }

            // Calculate the new size of the bytes data by adding
            // the size of a `RentalAssetUpdate` struct.
            let newByteDataSize := add(mload(rentalAssets), 0x40)

            // Get the pointer for where the element data begins.
            let rentalAssetElementPtr := add(rentalAssets, 0x20)

            // Increase the number of rental elements by one.
            let elements := add(mload(rentalAssetElementPtr), 1)

            // Calculate the position for the new rental ID.
            // To do this, calculate the total length of the element portion, then
            // subtract by the initial offset. In this case, the offset is the 32-byte
            // word (0x20) which contains the length of the array.
            let newItemPosition := add(
                rentalAssetElementPtr,
                sub(mul(elements, 0x40), 0x20)
            )

            // Store the new byte data size
            mstore(rentalAssets, newByteDataSize)

            // Store the new number of elements
            mstore(rentalAssetElementPtr, elements)

            // Store the rental ID
            mstore(newItemPosition, _rentalId)

            // Store the amount in the adjacent 32-byte word
            mstore(add(newItemPosition, 0x20), rentalAssetAmount)

            // Update the free memory pointer so that memory is safe
            // once we stop doing dynamic memory array inserts
            mstore(0x40, add(newItemPosition, 0x40))
        }
    }

    /**
     * @dev Converts an intermediary dynamic array of `RentalAssetUpdate` into a
     *      conventional Solidity array.
     *
     * @param rentalAssetUpdates Bytes data that represents an array of
     *                           `RentalAssetUpdate` structs.
     *
     * @return updates Solidity representation of a `RentalAssetUpdate` array.
     */
    function _convertToStatic(
        bytes memory rentalAssetUpdates
    ) internal pure returns (RentalAssetUpdate[] memory updates) {
        // Pointer to the rental asset update data.
        bytes32 rentalAssetUpdatePointer;

        // Load the length of the rental asset update items.
        uint256 rentalAssetUpdateLength;
        assembly {
            // Get a pointer to the number of elements in the bytes data.
            // With the 0x20 offset, we would be loading the length of the entire
            // byte string, but we want the element length which starts one
            // word to the right.
            rentalAssetUpdatePointer := add(0x20, rentalAssetUpdates)

            // Load the number of elements.
            rentalAssetUpdateLength := mload(rentalAssetUpdatePointer)
        }

        // Instantiate the update array.
        updates = new RentalAssetUpdate[](rentalAssetUpdateLength);

        // Iterate through each item in the byte data, and add it as
        // an entry to the array.
        for (uint256 i = 0; i < rentalAssetUpdateLength; ++i) {
            // Define the placeholders.
            RentalId rentalId;
            uint256 amount;

            // Extract the current element from the byte data.
            assembly {
                // Determine element offset by multiplying the length of a
                // RentalAssetUpdate struct (0x40) by the current index, then
                // add a word to make sure the next word is accessed because the
                // offset defaults to being set to the length pointer.
                let currentElementOffset := add(0x20, mul(i, 0x40))

                // Load the rental ID starting at the data pointer.
                rentalId := mload(add(rentalAssetUpdatePointer, currentElementOffset))

                // Load the amount at the data pointer adjacent to it.
                amount := mload(
                    add(0x20, add(rentalAssetUpdatePointer, currentElementOffset))
                )
            }

            // Set the items
            updates[i] = RentalAssetUpdate(rentalId, amount);
        }
    }
}
