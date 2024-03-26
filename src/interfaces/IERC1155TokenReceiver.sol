// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IERC1155TokenReceiver
 * @notice Interface for handling ERC1155 tokens.
 */
interface IERC1155TokenReceiver {
    /**
     * @notice Handles the callback when receiving ERC1155 tokens.
     *
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) external pure returns (bytes4);

    /**
     * @notice Handles the callback when receiving multiple ERC1155 tokens.
     *
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata data
    ) external pure returns (bytes4);
}
