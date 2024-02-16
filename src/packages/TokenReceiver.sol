// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC165} from "@src/interfaces/IERC165.sol";
import {IERC721TokenReceiver} from "@src/interfaces/IERC721TokenReceiver.sol";
import {IERC1155TokenReceiver} from "@src/interfaces/IERC1155TokenReceiver.sol";
import {IERC777TokensRecipient} from "@src/interfaces/IERC777TokensRecipient.sol";

/**
 * @title TokenReceiver
 * @notice Package that implements functionality for receiving tokens.
 */
abstract contract TokenReceiver is
    IERC721TokenReceiver,
    IERC1155TokenReceiver,
    IERC777TokensRecipient,
    IERC165
{
    // bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
    bytes4 private constant ERC721_RECEIVED_VALUE = 0x150b7a02;

    // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    bytes4 private constant ERC1155_RECEIVED_VALUE = 0xf23a6e61;

    // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
    bytes4 private constant ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;

    /**
     * @notice Handles the callback when receiving ERC721 tokens.
     *
     * @return ERC721_RECEIVED_VALUE
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return ERC721_RECEIVED_VALUE;
    }

    /**
     * @notice Handles the callback when receiving ERC1155 tokens.
     *
     * @return ERC1155_RECEIVED_VALUE
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return ERC1155_RECEIVED_VALUE;
    }

    /**
     * @notice Handles the callback when receiving multiple ERC1155 tokens.
     *
     * @return ERC1155_BATCH_RECEIVED_VALUE
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return ERC1155_BATCH_RECEIVED_VALUE;
    }

    /**
     * @notice Handles the callback when receiving ERC777 tokens.
     */
    function tokensReceived(
        address,
        address,
        address,
        uint256,
        bytes calldata,
        bytes calldata
    ) external override {}

    /**
     * @notice Implements support for IERC165, IERC721TokenReceiver, and IERC1155TokenReceiver.
     *
     * @param interfaceId The interface identifier, as specified in ERC-165.
     *
     * @return whether the contract supports `interfaceId`.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC721TokenReceiver).interfaceId ||
            interfaceId == type(IERC1155TokenReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
