// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";

import {Accumulator} from "@src/packages/Accumulator.sol";
import {RentalAssetUpdate, RentalId} from "@src/libraries/RentalStructs.sol";

contract Accumulator_Unit_Test is Test, Accumulator {
    function test_Success_DynamicAndStaticUpdates() public {
        // grab the initial free memory pointer
        bytes32 initialFreeMemoryPointer;
        assembly {
            initialFreeMemoryPointer := mload(0x40)
        }

        // create an empty array
        bytes memory assetUpdates = new bytes(0);

        // dynamically add elements to it
        _insert(assetUpdates, RentalId.wrap(bytes32(uint256(7))), 1);
        _insert(assetUpdates, RentalId.wrap(bytes32(uint256(8))), 2);
        _insert(assetUpdates, RentalId.wrap(bytes32(uint256(9))), 3);

        // grab the current free memory pointer
        bytes32 currentFreeMemoryPointer;
        assembly {
            currentFreeMemoryPointer := mload(0x40)
        }

        // convert the intermediary dynamic array into a static array with fixed length
        RentalAssetUpdate[] memory staticUpdates = _convertToStatic(assetUpdates);

        // assert that the free memory pointer incremented by the expected amount
        // 8 words: 1 word for length of bytes data and 2 words for each
        // element (3 elements total) plus an additional 1 word to store the element length
        assertEq(
            bytes32(uint256(initialFreeMemoryPointer) + uint256(256)),
            currentFreeMemoryPointer
        );

        // assert that the length is correct
        assertEq(staticUpdates.length, 3);

        // assert that the rental ID values are correct
        assertEq(RentalId.unwrap(staticUpdates[0].rentalId), bytes32(uint256(7)));
        assertEq(RentalId.unwrap(staticUpdates[1].rentalId), bytes32(uint256(8)));
        assertEq(RentalId.unwrap(staticUpdates[2].rentalId), bytes32(uint256(9)));

        // assert that the rental ID values are correct
        assertEq(staticUpdates[0].amount, uint256(1));
        assertEq(staticUpdates[1].amount, uint256(2));
        assertEq(staticUpdates[2].amount, uint256(3));
    }

    function test_Success_Insert(uint256 elements) public {
        // create a number of elements. Cap it at 1000
        vm.assume(elements > 0 && elements < 1000);

        // grab the initial free memory pointer
        bytes32 initialFreeMemoryPointer;
        assembly {
            initialFreeMemoryPointer := mload(0x40)
        }

        // create an empty array
        bytes memory assetUpdates = new bytes(0);

        // dynamically add each element to the byte data
        for (uint256 i = 0; i < elements; ++i) {
            _insert(assetUpdates, RentalId.wrap(keccak256(abi.encodePacked(i))), i);
        }

        // grab the current free memory pointer
        bytes32 currentFreeMemoryPointer;
        assembly {
            currentFreeMemoryPointer := mload(0x40)
        }

        // assert that the free memory pointer has moved exactly the same amount as the
        // length of the `assetUpdate` bytes plus an extra word for the length of the bytes data
        assertEq(
            uint256(currentFreeMemoryPointer) - uint256(initialFreeMemoryPointer),
            assetUpdates.length + 0x20
        );

        // check slot 0 in the byte data. Each element is size 0x40, and there is a 1 word
        // offset at the beginning of the byte data
        assertEq(assetUpdates.length, 0x20 + (elements * 0x40));

        // check slot 1 in the byte data
        uint256 storedElements;
        assembly {
            // read the data stored in the second slot of the bytes data
            storedElements := mload(add(0x20, assetUpdates))
        }
        assertEq(storedElements, elements);

        // check every slot after that. The slot offset is used to skip the length of
        // the bytes data and the number of elements that are stored
        uint256 slotOffset = 0x40;
        bytes32 storedRentalId;
        uint256 storedAmount;
        for (uint256 i = 0; i < elements; ++i) {
            assembly {
                // determine the element offset
                let elementOffset := mul(0x40, i)

                // get a pointer to the element
                let elementPointer := add(add(slotOffset, elementOffset), assetUpdates)

                // get the rental ID
                storedRentalId := mload(elementPointer)

                // get the amount
                storedAmount := mload(add(elementPointer, 0x20))
            }

            // assert that the elements are equal
            assertEq(storedRentalId, keccak256(abi.encodePacked(i)));
            assertEq(storedAmount, i);
        }
    }

    function test_Success_ConvertToStatic(uint256 elements) public {
        // create a number of elements. Cap it at 1000
        vm.assume(elements > 0 && elements < 1000);

        // create an empty array
        bytes memory assetUpdates = new bytes(0);

        // dynamically add each element to the byte data
        for (uint256 i = 0; i < elements; ++i) {
            _insert(assetUpdates, RentalId.wrap(keccak256(abi.encodePacked(i))), i);
        }

        // convert the intermediary dynamic array into a static array with fixed length
        RentalAssetUpdate[] memory staticUpdates = _convertToStatic(assetUpdates);

        // assert that the length is correct
        assertEq(staticUpdates.length, elements);

        for (uint256 i = 0; i < elements; ++i) {
            // assert that the rental ID values are correct
            assertEq(
                RentalId.unwrap(staticUpdates[i].rentalId),
                keccak256(abi.encodePacked(i))
            );

            // assert that the rental ID values are correct
            assertEq(staticUpdates[i].amount, i);
        }
    }
}
