// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC165} from "@openzeppelin-contracts/utils/introspection/ERC165.sol";
import {Schema} from "@seaport-types/lib/ConsiderationStructs.sol";

import {ISIP5} from "@src/interfaces/ISip5.sol";
import {ZoneInterface} from "@src/interfaces/IZone.sol";

/**
 * @title Zone
 * @notice Used to accept callbacks to a zone contract from the Seaport protocol after
 *         an order has been processed, and all transfers have been made.
 *
 *         Seaport uses a series of standards when interacting with zone contracts,
 *         which are called SIPs. This contract implements SIP5 which is a standard
 *         for Seaport metadata.
 */
abstract contract Zone is ZoneInterface, ISIP5, ERC165 {
    /**
     * @dev Emit an event to signal a SIP-5 contract has been deployed.
     */
    constructor() {
        emit SeaportCompatibleContractDeployed();
    }

    /**
     * @notice Returns Seaport metadata for this contract, returning the contract
     *         name and supported schemas.
     *
     * @return name    The contract name
     * @return schemas The supported SIPs
     */
    function getSeaportMetadata()
        external
        pure
        override(ISIP5, ZoneInterface)
        returns (string memory name, Schema[] memory schemas)
    {
        schemas = new Schema[](1);
        schemas[0].id = 5;

        return ("ReNFT-RentalZone", schemas);
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface ID to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, ZoneInterface) returns (bool) {
        return
            interfaceId == type(ISIP5).interfaceId || // SIP-5
            interfaceId == type(ZoneInterface).interfaceId || // ZoneInterface
            super.supportsInterface(interfaceId); // ERC-165
    }
}
