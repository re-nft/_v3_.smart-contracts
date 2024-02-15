// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IERC165
 * @notice Interface for checking if a contract implements a particular interface.
 */
interface IERC165 {
    /**
     * @notice Query if a contract supports an interface.
     *
     * @param interfaceId The interface identifier, as specified in ERC-165.
     *
     * @return whether the contract supports `interfaceId`.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
