// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IERC721TokenReceiver
 * @notice Interface for handling ERC721 tokens.
 */
interface IERC721TokenReceiver {
    /**
     * @notice Handles the callback when receiving ERC721 tokens.
     *
     * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4);
}
