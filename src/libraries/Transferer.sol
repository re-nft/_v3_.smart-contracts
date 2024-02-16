// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {Item} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

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

    /**
     * @dev Safe transfer for ERC20 tokens that do not consistently renturn true/false.
     *
     * @param token Asset address which is being sent.
     * @param to    Destination address for the transfer.
     * @param value Amount of the asset being transferred.
     */
    function transferERC20(address token, address to, uint256 value) internal {
        // Call transfer() on the token.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );

        // Because both reverting and returning false are allowed by the ERC20 standard
        // to indicate a failed transfer, we must handle both cases.
        //
        // If success is false, the ERC20 contract reverted.
        //
        // If success is true, we must check if return data was provided. If no return
        // data is provided, then no revert occurred. But, if return data is provided,
        // then it must be decoded into a bool which will indicate the success of the
        // transfer.
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert Errors.Shared_ERC20TransferFailed(token, address(this), to, value);
        }
    }
}
