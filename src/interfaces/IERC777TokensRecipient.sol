// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IERC777TokensRecipient
 * @notice Interface for handling ERC777 tokens.
 */
interface IERC777TokensRecipient {
    /**
     * @notice Handles the callback when receiving ERC777 tokens.
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}
