// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin-contracts/token/ERC1155/IERC1155.sol";

import {RentalOrder, Item, ItemType} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Transferer} from "@src/libraries/Transferer.sol";

/**
 * @title Reclaimer
 * @notice Retrieves rented assets from a wallet contract once a rental has been
 *         stopped, and transfers them to the proper recipient.
 */
abstract contract Reclaimer {
    using Transferer for Item;

    // The original address that this contract was deployed with
    address private immutable original;

    /**
     * @dev Use the constructor to store the original deployment address.
     */
    constructor() {
        original = address(this);
    }

    /**
     * @notice Reclaims the assets that are currently owned by a rental safe.
     *         This function is intended to be delegate called by the safe.
     *
     *         NOTE: At first, it may seem that this function can be used to exploit
     *         the safe, since this is an external function that can transfer tokens
     *         out of a rental safe, so long as the caller is:
     *             1) Using delegate call to extract the assets
     *             2) The rental safe that holds those assets
     *
     *         This exploit is prevented because delegate calls from the rental safe can
     *         only be made to addresses which have been explicitly whitelisted by the
     *         Admin policy. Further, since the Stop policy is a whitelisted module on
     *         the safe, `reclaimRentalOrder()` can only be called via the context of the
     *         Stop policy contract, which prevents unauthorized reclaiming.
     *
     * @param rentalOrder Order which will have its contained items reclaimed by the
     *                    recipient parties.
     */
    function reclaimRentalOrder(RentalOrder calldata rentalOrder) external {
        // This contract address must be in the context of another address.
        if (address(this) == original) {
            revert Errors.ReclaimerPackage_OnlyDelegateCallAllowed();
        }

        // Only the rental wallet specified in the order can be the address that
        // initates the reclaim. In the context of a delegate call, address(this)
        // will be the safe.
        if (address(this) != rentalOrder.rentalWallet) {
            revert Errors.ReclaimerPackage_OnlyRentalSafeAllowed(
                rentalOrder.rentalWallet
            );
        }

        // Get a count for the number of items.
        uint256 itemCount = rentalOrder.items.length;

        // Transfer each item if it is a rented asset.
        for (uint256 i = 0; i < itemCount; ++i) {
            Item memory item = rentalOrder.items[i];

            // Check if the item is an ERC721.
            if (item.itemType == ItemType.ERC721) item.transferERC721(rentalOrder.lender);

            // check if the item is an ERC1155.
            if (item.itemType == ItemType.ERC1155)
                item.transferERC1155(rentalOrder.lender);
        }
    }
}
