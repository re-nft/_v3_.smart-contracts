// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {Item} from "@src/libraries/RentalStructs.sol";

/**
 * @title Transferer
 * @notice Contains logic for for transferring tokens.
 */
library Transferer {
    /**
     * @dev Helper function to transfer an ERC721 token.
     *
     * @param item      Item which will be transferred.
     * @param recipient Address which will receive the token.
     */
    function transferERC721(Item memory item, address recipient) internal {
        IERC721(item.token).safeTransferFrom(address(this), recipient, item.identifier);
    }

    /**
     * @dev Helper function to transfer an ERC1155 token.
     *
     * @param item      Item which will be transferred.
     * @param recipient Address which will receive the token.
     */
    function transferERC1155(Item memory item, address recipient) internal {
        IERC1155(item.token).safeTransferFrom(
            address(this),
            recipient,
            item.identifier,
            item.amount,
            ""
        );
    }
}
