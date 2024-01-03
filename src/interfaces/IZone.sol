// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ZoneParameters} from "@seaport-core/lib/rental/ConsiderationStructs.sol";
import {Schema} from "@seaport-types/lib/ConsiderationStructs.sol";

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @title  ZoneInterface
 * @notice Contains functions exposed by a zone.
 */
interface ZoneInterface is IERC165 {
    /**
     * @dev Validates an order.
     *
     * @param zoneParameters The context about the order fulfillment and any
     *                       supplied extraData.
     *
     * @return validOrderMagicValue The magic value that indicates a valid
     *                              order.
     */
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external returns (bytes4 validOrderMagicValue);

    /**
     * @dev Returns the metadata for this zone.
     *
     * @return name The name of the zone.
     * @return schemas The schemas that the zone implements.
     */
    function getSeaportMetadata()
        external
        view
        returns (string memory name, Schema[] memory schemas); // map to Seaport Improvement Proposal IDs

    function supportsInterface(bytes4 interfaceId) external view override returns (bool);
}
