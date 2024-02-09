// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {
    RentPayload,
    Hook,
    RentalOrder,
    OrderFulfillment,
    OrderMetadata,
    Item
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

/**
 * @title Signer
 * @notice Contains logic related to signed payloads and signature verification when
 *         creating rentals.
 */
abstract contract Signer {
    using ECDSA for bytes32;

    // Declare constants for name and version.
    string internal constant _NAME = "ReNFT-Rentals";
    string internal constant _VERSION = "1.0.0";

    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;
    bytes32 internal immutable _ITEM_TYPEHASH;
    bytes32 internal immutable _HOOK_TYPEHASH;
    bytes32 internal immutable _RENTAL_ORDER_TYPEHASH;
    bytes32 internal immutable _ORDER_FULFILLMENT_TYPEHASH;
    bytes32 internal immutable _ORDER_METADATA_TYPEHASH;
    bytes32 internal immutable _RENT_PAYLOAD_TYPEHASH;

    /**
     * @dev Sets up the type hashes and sets the chain ID.
     */
    constructor() {
        // Derive name, version, and EIP-712 typehashes.
        (
            _NAME_HASH,
            _VERSION_HASH,
            _EIP_712_DOMAIN_TYPEHASH,
            _DOMAIN_SEPARATOR
        ) = _deriveTypehashes();

        // Derive name and version hashes alongside required EIP-712 typehashes.
        (
            _ITEM_TYPEHASH,
            _HOOK_TYPEHASH,
            _RENTAL_ORDER_TYPEHASH,
            _ORDER_FULFILLMENT_TYPEHASH,
            _ORDER_METADATA_TYPEHASH,
            _RENT_PAYLOAD_TYPEHASH
        ) = _deriveRentalTypehashes();

        // Store the current chainId and derive the current domain separator.
        _CHAIN_ID = block.chainid;
    }

    /**
     * @dev Validates that the expected fulfiller of the order is the same as the address
     *      executed the order. This check is meant to prevent order sniping where one
     *      party receives a server-side signature but another party intercepts the
     *      signature and uses it.
     *
     * @param intendedFulfiller Address that was expected to execute the order.
     * @param actualFulfiller   Address that actually executed the order.
     */
    function _validateFulfiller(
        address intendedFulfiller,
        address actualFulfiller
    ) internal pure {
        // Check actual fulfiller against the intended fulfiller.
        if (intendedFulfiller != actualFulfiller) {
            revert Errors.SignerPackage_UnauthorizedFulfiller(
                actualFulfiller,
                intendedFulfiller
            );
        }
    }

    /**
     * @dev Validates that the server-side signature has not expired.
     *
     * @param expiration Expiration time of the signature.
     */
    function _validateProtocolSignatureExpiration(uint256 expiration) internal view {
        // Check that the signature provided by the protocol signer has not expired.
        if (block.timestamp > expiration) {
            revert Errors.SignerPackage_SignatureExpired(block.timestamp, expiration);
        }
    }

    /**
     * @dev Recovers the signer of the payload hash.
     *
     * @param payloadHash The payload hash which was signed.
     * @param signature   The signature data for the payload hash.
     */
    function _recoverSignerFromPayload(
        bytes32 payloadHash,
        bytes memory signature
    ) internal view returns (address) {
        // Derive original EIP-712 digest using domain separator and order hash.
        bytes32 digest = _DOMAIN_SEPARATOR.toTypedDataHash(payloadHash);

        // Recover the signer address of the signature.
        return digest.recover(signature);
    }

    /**
     * @dev Derives the hash of a given item using a type hash.
     *
     * @param item Item to hash.
     *
     * @return The hash of the item.
     */
    function _deriveItemHash(Item memory item) internal view returns (bytes32) {
        // Derive and return the item as specified by EIP-712.
        return
            keccak256(
                abi.encode(
                    _ITEM_TYPEHASH,
                    item.itemType,
                    item.settleTo,
                    item.token,
                    item.amount,
                    item.identifier
                )
            );
    }

    /**
     * @dev Derives the hash of a given hook using a type hash.
     *
     * @param hook Hook to hash.
     *
     * @return The hash of the hook.
     */
    function _deriveHookHash(Hook memory hook) internal view returns (bytes32) {
        // Derive and return the hook as specified by EIP-712.
        return
            keccak256(
                abi.encode(
                    _HOOK_TYPEHASH,
                    hook.target,
                    hook.itemIndex,
                    keccak256(hook.extraData)
                )
            );
    }

    /**
     * @dev Derives the hash of a given rental order using a type hash.
     *
     * @param order Rental order to hash.
     *
     * @return The hash of the rental order.
     */
    function _deriveRentalOrderHash(
        RentalOrder memory order
    ) internal view returns (bytes32) {
        // Create arrays for items and hooks.
        bytes32[] memory itemHashes = new bytes32[](order.items.length);
        bytes32[] memory hookHashes = new bytes32[](order.hooks.length);

        // Iterate over each item.
        for (uint256 i = 0; i < order.items.length; ++i) {
            // Hash the item.
            itemHashes[i] = _deriveItemHash(order.items[i]);
        }

        // Iterate over each hook.
        for (uint256 i = 0; i < order.hooks.length; ++i) {
            // Hash the hook.
            hookHashes[i] = _deriveHookHash(order.hooks[i]);
        }

        return
            keccak256(
                abi.encode(
                    _RENTAL_ORDER_TYPEHASH,
                    order.seaportOrderHash,
                    keccak256(abi.encodePacked(itemHashes)),
                    keccak256(abi.encodePacked(hookHashes)),
                    order.orderType,
                    order.lender,
                    order.renter,
                    order.rentalWallet,
                    order.startTimestamp,
                    order.endTimestamp
                )
            );
    }

    /**
     * @dev Derives the hash of a given fulfillment using a type hash.
     *
     * @param fulfillment Order fulfillment to hash.
     *
     * @return The hash of the order fulfillment.
     */
    function _deriveOrderFulfillmentHash(
        OrderFulfillment memory fulfillment
    ) internal view returns (bytes32) {
        // Derive and return the fulfilmment hash as specified by EIP-712
        return keccak256(abi.encode(_ORDER_FULFILLMENT_TYPEHASH, fulfillment.recipient));
    }

    /**
     * @dev Derives the hash of a given order metadata using a type hash.
     *
     * @param metadata Order metadata to hash.
     *
     * @return The hash of the order metadata.
     */
    function _deriveOrderMetadataHash(
        OrderMetadata memory metadata
    ) internal view returns (bytes32) {
        // Create array for hooks.
        bytes32[] memory hookHashes = new bytes32[](metadata.hooks.length);

        // Iterate over each hook.
        for (uint256 i = 0; i < metadata.hooks.length; ++i) {
            // Hash the hook
            hookHashes[i] = _deriveHookHash(metadata.hooks[i]);
        }

        // Derive and return the metadata hash as specified by EIP-712.
        return
            keccak256(
                abi.encode(
                    _ORDER_METADATA_TYPEHASH,
                    metadata.orderType,
                    metadata.rentDuration,
                    keccak256(abi.encodePacked(hookHashes)),
                    keccak256(metadata.emittedExtraData)
                )
            );
    }

    /**
     * @dev Derives the hash of a given payload using a type hash.
     *
     * @param payload Rent payload to hash.
     *
     * @return The hash of the rent payload.
     */
    function _deriveRentPayloadHash(
        RentPayload memory payload
    ) internal view returns (bytes32) {
        // Derive and return the rent payload hash as specified by EIP-712.
        return
            keccak256(
                abi.encode(
                    _RENT_PAYLOAD_TYPEHASH,
                    payload.orderHash,
                    _deriveOrderFulfillmentHash(payload.fulfillment),
                    _deriveOrderMetadataHash(payload.metadata),
                    payload.expiration,
                    payload.intendedFulfiller
                )
            );
    }

    /**
     * @dev Derives the hash of the domain separator.
     *
     * @param _eip712DomainTypeHash The standard EIP-712 domain type string.
     * @param _nameHash             Hash of the contract name.
     * @param _versionHash          Hash of the contract version.
     *
     * @return The hash of the domain separator.
     */
    function _deriveDomainSeparator(
        bytes32 _eip712DomainTypeHash,
        bytes32 _nameHash,
        bytes32 _versionHash
    ) internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _eip712DomainTypeHash,
                    _nameHash,
                    _versionHash,
                    block.chainid,
                    address(this)
                )
            );
    }

    /**
     * @dev Derives the standard EIP-712 type hashes.
     *
     * @return nameHash             Hash of the contract name.
     * @return versionHash          Hash of the contract version.
     * @return eip712DomainTypehash Hash of the EIP-712 Domain.
     * @return domainSeparator      The constructed domain separator.
     */
    function _deriveTypehashes()
        internal
        view
        returns (
            bytes32 nameHash,
            bytes32 versionHash,
            bytes32 eip712DomainTypehash,
            bytes32 domainSeparator
        )
    {
        // Derive the name type hash.
        nameHash = keccak256(bytes(_NAME));

        // Derive the version type hash.
        versionHash = keccak256(bytes(_VERSION));

        // Construct the primary EIP-712 domain type string.
        eip712DomainTypehash = keccak256(
            abi.encodePacked(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            )
        );

        // Construct the domain separator.
        domainSeparator = _deriveDomainSeparator(
            eip712DomainTypehash,
            nameHash,
            versionHash
        );
    }

    /**
     * @dev Derives the protocol-specific type hashes.
     *
     * @return itemTypeHash             Type hash of the item.
     * @return hookTypeHash             Type hash of the hook.
     * @return rentalOrderTypeHash      Type hash of the rental order.
     * @return orderFulfillmentTypeHash Type hash of the order fulfillment.
     * @return orderMetadataTypeHash    Type hash of the order metadata.
     * @return rentPayloadTypeHash      Type hash of the rent payload.
     */
    function _deriveRentalTypehashes()
        internal
        pure
        returns (
            bytes32 itemTypeHash,
            bytes32 hookTypeHash,
            bytes32 rentalOrderTypeHash,
            bytes32 orderFulfillmentTypeHash,
            bytes32 orderMetadataTypeHash,
            bytes32 rentPayloadTypeHash
        )
    {
        // Construct the Item type string.
        bytes memory itemTypeString = abi.encodePacked(
            "Item(uint8 itemType,uint8 settleTo,address token,uint256 amount,uint256 identifier)"
        );

        // Construct the Hook type string.
        bytes memory hookTypeString = abi.encodePacked(
            "Hook(address target,uint256 itemIndex,bytes extraData)"
        );

        // Construct the RentalOrder type string.
        bytes memory rentalOrderTypeString = abi.encodePacked(
            "RentalOrder(bytes32 seaportOrderHash,Item[] items,Hook[] hooks,uint8 orderType,address lender,address renter,address rentalWallet,uint256 startTimestamp,uint256 endTimestamp)"
        );

        // Derive the Item type hash using the corresponding type string.
        itemTypeHash = keccak256(itemTypeString);

        // Derive the Hook type hash using the corresponding type string.
        hookTypeHash = keccak256(hookTypeString);

        // Derive the RentalOrder type hash using the corresponding type string.
        rentalOrderTypeHash = keccak256(
            abi.encodePacked(rentalOrderTypeString, hookTypeString, itemTypeString)
        );

        {
            // Construct the OrderFulfillment type string.
            bytes memory orderFulfillmentTypeString = abi.encodePacked(
                "OrderFulfillment(address recipient)"
            );

            // Construct the OrderMetadata type string.
            bytes memory orderMetadataTypeString = abi.encodePacked(
                "OrderMetadata(uint8 orderType,uint256 rentDuration,Hook[] hooks,bytes emittedExtraData)"
            );

            // Construct the RentPayload type string.
            bytes memory rentPayloadTypeString = abi.encodePacked(
                "RentPayload(bytes32 orderHash,OrderFulfillment fulfillment,OrderMetadata metadata,uint256 expiration,address intendedFulfiller)"
            );

            // Derive RentPayload type hash via combination of relevant type strings.
            rentPayloadTypeHash = keccak256(
                abi.encodePacked(
                    rentPayloadTypeString,
                    orderFulfillmentTypeString,
                    orderMetadataTypeString
                )
            );

            // Derive the OrderFulfillment type hash using the corresponding type string.
            orderFulfillmentTypeHash = keccak256(orderFulfillmentTypeString);

            // Derive the OrderMetadata type hash using the corresponding type string.
            orderMetadataTypeHash = keccak256(orderMetadataTypeString);
        }
    }
}
