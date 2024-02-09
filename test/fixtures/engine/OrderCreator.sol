// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    OrderComponents,
    Order,
    AdvancedOrder,
    ItemType,
    CriteriaResolver,
    OrderType as SeaportOrderType
} from "@seaport-types/lib/ConsiderationStructs.sol";
import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    FulfillmentComponentLib,
    FulfillmentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib,
    SeaportArrays,
    ZoneParametersLib
} from "@seaport-sol/SeaportSol.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {BaseProtocol} from "@test/fixtures/protocol/BaseProtocol.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";

import {OrderMetadata, OrderType, Hook} from "@src/libraries/RentalStructs.sol";

// Sets up logic in the test engine related to order creation
contract OrderCreator is BaseProtocol {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using ECDSA for bytes32;

    // defines a config for a standard order component
    string constant STANDARD_ORDER_COMPONENTS = "standard_order_components";

    struct OrderToCreate {
        ProtocolAccount offerer;
        OfferItem[] offerItems;
        ConsiderationItem[] considerationItems;
        OrderMetadata metadata;
    }

    // keeps track of tokens used during a test
    uint256[] usedOfferERC721s;
    uint256[] usedOfferERC1155s;

    uint256[] usedConsiderationERC721s;
    uint256[] usedConsiderationERC1155s;

    // components of an order
    OrderToCreate orderToCreate;

    function setUp() public virtual override {
        super.setUp();

        // Define a standard OrderComponents struct which is ready for
        // use with the Create Policy and the protocol conduit contract
        OrderComponentsLib
            .empty()
            .withZone(address(create))
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 100)
            .withSalt(123456789)
            .withConduitKey(conduitKey)
            .saveDefault(STANDARD_ORDER_COMPONENTS);

        // for each test token, create a storage slot
        for (uint256 i = 0; i < erc721s.length; i++) {
            usedOfferERC721s.push();
            usedConsiderationERC721s.push();

            usedOfferERC1155s.push();
            usedConsiderationERC1155s.push();
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                                Order Creation                               //
    /////////////////////////////////////////////////////////////////////////////////

    // creates an order based on the provided context. The defaults on this order
    // are good for most test cases.
    function createOrder(
        ProtocolAccount memory offerer,
        OrderType orderType,
        uint256 erc721Offers,
        uint256 erc1155Offers,
        uint256 erc20Offers,
        uint256 erc721Considerations,
        uint256 erc1155Considerations,
        uint256 erc20Considerations
    ) internal {
        // require that the number of offer items or consideration items
        // dont exceed the number of test tokens
        require(
            erc721Offers <= erc721s.length &&
                erc721Offers <= erc1155s.length &&
                erc20Offers <= erc20s.length,
            "TEST: too many offer items defined"
        );
        require(
            erc721Considerations <= erc721s.length &&
                erc1155Considerations <= erc1155s.length &&
                erc20Considerations <= erc20s.length,
            "TEST: too many consideration items defined"
        );

        // create the offerer
        _createOfferer(offerer);

        // add the offer items
        _createOfferItems(erc721Offers, erc1155Offers, erc20Offers);

        // create the consideration items
        _createConsiderationItems(
            erc721Considerations,
            erc1155Considerations,
            erc20Considerations
        );

        // Create order metadata
        _createOrderMetadata(orderType);
    }

    // Creates an offerer on the order to create
    function _createOfferer(ProtocolAccount memory offerer) private {
        orderToCreate.offerer = offerer;
    }

    // Creates offer items which are good for most tests
    function _createOfferItems(
        uint256 erc721Offers,
        uint256 erc1155Offers,
        uint256 erc20Offers
    ) private {
        // generate the ERC721 offer items
        for (uint256 i = 0; i < erc721Offers; ++i) {
            // create the offer item
            orderToCreate.offerItems.push(
                OfferItemLib
                    .empty()
                    .withItemType(ItemType.ERC721)
                    .withToken(address(erc721s[i]))
                    .withIdentifierOrCriteria(usedOfferERC721s[i])
                    .withStartAmount(1)
                    .withEndAmount(1)
            );

            // mint an erc721 to the offerer
            erc721s[i].mint(orderToCreate.offerer.addr);

            // update the used token so it cannot be used again in the same test
            usedOfferERC721s[i]++;
        }

        // generate the ERC1155 offer items
        for (uint256 i = 0; i < erc1155Offers; ++i) {
            // create the offer item
            orderToCreate.offerItems.push(
                OfferItemLib
                    .empty()
                    .withItemType(ItemType.ERC1155)
                    .withToken(address(erc1155s[i]))
                    .withIdentifierOrCriteria(usedOfferERC1155s[i])
                    .withStartAmount(100)
                    .withEndAmount(100)
            );

            // mint an erc1155 to the offerer
            erc1155s[i].mint(orderToCreate.offerer.addr, 100);

            // update the used token so it cannot be used again in the same test
            usedOfferERC1155s[i]++;
        }

        // generate the ERC20 offer items
        for (uint256 i = 0; i < erc20Offers; ++i) {
            // create the offer item
            orderToCreate.offerItems.push(
                OfferItemLib
                    .empty()
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[i]))
                    .withStartAmount(100)
                    .withEndAmount(100)
            );
        }
    }

    // Creates consideration items that are good for most tests
    function _createConsiderationItems(
        uint256 erc721Considerations,
        uint256 erc1155Considerations,
        uint256 erc20Considerations
    ) private {
        // generate the ERC721 consideration items
        for (uint256 i = 0; i < erc721Considerations; ++i) {
            // create the consideration item, and set the recipient as the offerer's
            // rental safe address
            orderToCreate.considerationItems.push(
                ConsiderationItemLib
                    .empty()
                    .withRecipient(address(orderToCreate.offerer.safe))
                    .withItemType(ItemType.ERC721)
                    .withToken(address(erc721s[i]))
                    .withIdentifierOrCriteria(usedConsiderationERC721s[i])
                    .withStartAmount(1)
                    .withEndAmount(1)
            );

            // update the used token so it cannot be used again in the same test
            usedConsiderationERC721s[i]++;
        }

        // generate the ERC1155 consideration items
        for (uint256 i = 0; i < erc1155Considerations; ++i) {
            // create the consideration item, and set the recipient as the offerer's
            // rental safe address
            orderToCreate.considerationItems.push(
                ConsiderationItemLib
                    .empty()
                    .withRecipient(address(orderToCreate.offerer.safe))
                    .withItemType(ItemType.ERC1155)
                    .withToken(address(erc1155s[i]))
                    .withIdentifierOrCriteria(usedConsiderationERC1155s[i])
                    .withStartAmount(100)
                    .withEndAmount(100)
            );

            // update the used token so it cannot be used again in the same test
            usedConsiderationERC1155s[i]++;
        }

        // generate the ERC20 consideration items
        for (uint256 i = 0; i < erc20Considerations; ++i) {
            // create the offer item
            orderToCreate.considerationItems.push(
                ConsiderationItemLib
                    .empty()
                    .withRecipient(address(ESCRW))
                    .withItemType(ItemType.ERC20)
                    .withToken(address(erc20s[i]))
                    .withStartAmount(100)
                    .withEndAmount(100)
            );
        }
    }

    // Creates a order metadata that is good for most tests
    function _createOrderMetadata(OrderType orderType) private {
        // Create order metadata
        orderToCreate.metadata.orderType = orderType;
        orderToCreate.metadata.rentDuration = 500;
        orderToCreate.metadata.emittedExtraData = new bytes(0);
    }

    // creates a signed seaport order ready to be fulfilled by a renter
    function _createSignedOrder(
        ProtocolAccount memory _offerer,
        OfferItem[] memory _offerItems,
        ConsiderationItem[] memory _considerationItems,
        OrderMetadata memory _metadata,
        SeaportOrderType orderType
    ) private view returns (Order memory order, bytes32 orderHash) {
        // put offerer address on stack
        address offerer = _offerer.addr;

        // Build the order components
        OrderComponents memory orderComponents = OrderComponentsLib
            .fromDefault(STANDARD_ORDER_COMPONENTS)
            .withOrderType(orderType)
            .withOfferer(offerer)
            .withOffer(_offerItems)
            .withConsideration(_considerationItems)
            .withZoneHash(create.getOrderMetadataHash(_metadata))
            .withCounter(seaport.getCounter(offerer));

        // generate the order hash
        orderHash = seaport.getOrderHash(orderComponents);

        // generate the signature for the order components
        bytes memory signature = _signSeaportOrder(_offerer.privateKey, orderHash);

        // create the order, but dont provide a signature if its a PAYEE order.
        // Since PAYEE orders are fulfilled by the offerer of the order, they
        // dont need a signature.
        if (_metadata.orderType == OrderType.PAYEE) {
            order = OrderLib.empty().withParameters(orderComponents.toOrderParameters());
        } else {
            order = OrderLib
                .empty()
                .withParameters(orderComponents.toOrderParameters())
                .withSignature(signature);
        }
    }

    function _signSeaportOrder(
        uint256 signerPrivateKey,
        bytes32 orderHash
    ) private view returns (bytes memory signature) {
        // fetch domain separator from seaport
        (, bytes32 domainSeparator, ) = seaport.information();

        // sign the EIP-712 digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            domainSeparator.toTypedDataHash(orderHash)
        );

        // encode the signature
        signature = abi.encodePacked(r, s, v);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                               Order Amendments                              //
    /////////////////////////////////////////////////////////////////////////////////

    function resetOrderToCreate() internal {
        delete orderToCreate;
    }

    function withOfferer(ProtocolAccount memory _offerer) internal {
        orderToCreate.offerer = _offerer;
    }

    function resetOfferer() internal {
        delete orderToCreate.offerer;
    }

    function withReplacedOfferItems(OfferItem[] memory _offerItems) internal {
        // reset all current offer items
        resetOfferItems();

        // add the new offer items to storage
        for (uint256 i = 0; i < _offerItems.length; i++) {
            orderToCreate.offerItems.push(_offerItems[i]);
        }
    }

    function withOfferItem(OfferItem memory offerItem) internal {
        orderToCreate.offerItems.push(offerItem);
    }

    function resetOfferItems() internal {
        delete orderToCreate.offerItems;
    }

    function popOfferItem() internal {
        orderToCreate.offerItems.pop();
    }

    function withReplacedConsiderationItems(
        ConsiderationItem[] memory _considerationItems
    ) internal {
        // reset all current consideration items
        resetConsiderationItems();

        // add the new consideration items to storage
        for (uint256 i = 0; i < _considerationItems.length; i++) {
            orderToCreate.considerationItems.push(_considerationItems[i]);
        }
    }

    function withConsiderationItem(ConsiderationItem memory considerationItem) internal {
        orderToCreate.considerationItems.push(considerationItem);
    }

    function resetConsiderationItems() internal {
        delete orderToCreate.considerationItems;
    }

    function popConsiderationItem() internal {
        orderToCreate.considerationItems.pop();
    }

    function withHooks(Hook[] memory hooks) internal {
        // delete the current metatdata hooks
        delete orderToCreate.metadata.hooks;

        // add each metadata hook to storage
        for (uint256 i = 0; i < hooks.length; i++) {
            orderToCreate.metadata.hooks.push(hooks[i]);
        }
    }

    function withOrderMetadata(OrderMetadata memory _metadata) internal {
        // update the static metadata parameters
        orderToCreate.metadata.orderType = _metadata.orderType;
        orderToCreate.metadata.rentDuration = _metadata.rentDuration;
        orderToCreate.metadata.emittedExtraData = _metadata.emittedExtraData;

        // update the hooks
        withHooks(_metadata.hooks);
    }

    function resetOrderMetadata() internal {
        delete orderToCreate.metadata;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              Order Finalization                             //
    /////////////////////////////////////////////////////////////////////////////////

    function _finalizeOrder(
        SeaportOrderType orderType
    ) private returns (Order memory, bytes32, OrderMetadata memory) {
        // create and sign the order
        (Order memory order, bytes32 orderHash) = _createSignedOrder(
            orderToCreate.offerer,
            orderToCreate.offerItems,
            orderToCreate.considerationItems,
            orderToCreate.metadata,
            orderType
        );

        // pull order metadata into memory
        OrderMetadata memory metadata = orderToCreate.metadata;

        // clear structs
        resetOrderToCreate();

        return (order, orderHash, metadata);
    }

    function finalizePartialOrder()
        internal
        returns (Order memory, bytes32, OrderMetadata memory)
    {
        return _finalizeOrder(SeaportOrderType.PARTIAL_RESTRICTED);
    }

    function finalizeOrder()
        internal
        returns (Order memory, bytes32, OrderMetadata memory)
    {
        return _finalizeOrder(SeaportOrderType.FULL_RESTRICTED);
    }
}
