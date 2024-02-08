// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    OrderComponents,
    Order,
    AdvancedOrder,
    ItemType as SeaportItemType,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent
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

import {OrderCreator} from "@test/fixtures/engine/OrderCreator.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";

import {
    OrderMetadata,
    OrderType,
    OrderFulfillment,
    RentPayload,
    RentalOrder,
    Item,
    SettleTo,
    ItemType
} from "@src/libraries/RentalStructs.sol";
import {Events} from "@src/libraries/Events.sol";

// Sets up logic in the test engine related to order fulfillment
contract OrderFulfiller is OrderCreator {
    using ECDSA for bytes32;

    struct OrderToFulfill {
        bytes32 orderHash;
        RentPayload payload;
        AdvancedOrder advancedOrder;
    }

    uint256 rentPayloadNonce;

    // components of a fulfillment
    ProtocolAccount fulfiller;
    OrderToFulfill[] ordersToFulfill;
    Fulfillment[] seaportMatchOrderFulfillments;
    FulfillmentComponent[][] seaportOfferFulfillments;
    FulfillmentComponent[][] seaportConsiderationFulfillments;
    address seaportRecipient;

    /////////////////////////////////////////////////////////////////////////////////
    //                             Fulfillment Creation                            //
    /////////////////////////////////////////////////////////////////////////////////

    // creates an order fulfillment
    function createOrderFulfillment(
        ProtocolAccount memory _fulfiller,
        Order memory order,
        bytes32 orderHash,
        OrderMetadata memory metadata
    ) internal {
        // set the fulfiller account
        fulfiller = _fulfiller;

        // set the recipient of any offer items after an order is fulfilled. If the fulfillment is via
        // `matchAdvancedOrders`, then any unspent offer items will go to this address as well
        seaportRecipient = address(_fulfiller.safe);

        // get a pointer to a new order to fulfill
        OrderToFulfill storage orderToFulfill = ordersToFulfill.push();

        // create an order fulfillment
        OrderFulfillment memory fulfillment = OrderFulfillment(address(_fulfiller.safe));

        // add the order hash and fulfiller
        orderToFulfill.orderHash = orderHash;

        // create rental zone payload data
        _createRentalPayload(
            orderToFulfill.payload,
            RentPayload(
                orderHash,
                rentPayloadNonce,
                fulfillment,
                metadata,
                block.timestamp + 100,
                _fulfiller.addr
            )
        );

        // increment the rent payload nonce
        rentPayloadNonce++;

        // generate the signature for the payload
        bytes memory signature = _signProtocolOrder(
            rentalSigner.privateKey,
            create.getRentPayloadHash(orderToFulfill.payload)
        );

        // create an advanced order from the order. Pass the rental
        // payload as extra data
        _createAdvancedOrder(
            orderToFulfill.advancedOrder,
            AdvancedOrder(
                order.parameters,
                1,
                1,
                order.signature,
                abi.encode(orderToFulfill.payload, signature)
            )
        );
    }

    function _createOrderFulfiller(
        ProtocolAccount storage storageFulfiller,
        ProtocolAccount memory _fulfiller
    ) private {
        storageFulfiller.addr = _fulfiller.addr;
        storageFulfiller.safe = _fulfiller.safe;
        storageFulfiller.publicKeyX = _fulfiller.publicKeyX;
        storageFulfiller.publicKeyY = _fulfiller.publicKeyY;
        storageFulfiller.privateKey = _fulfiller.privateKey;
    }

    function _createOrderFulfillment(
        OrderFulfillment storage storageFulfillment,
        OrderFulfillment memory fulfillment
    ) private {
        storageFulfillment.recipient = fulfillment.recipient;
    }

    function _createOrderMetadata(
        OrderMetadata storage storageMetadata,
        OrderMetadata memory metadata
    ) private {
        // Create order metadata in storage
        storageMetadata.orderType = metadata.orderType;
        storageMetadata.rentDuration = metadata.rentDuration;
        storageMetadata.emittedExtraData = metadata.emittedExtraData;

        // dynamically push the hooks from memory to storage
        for (uint256 i = 0; i < metadata.hooks.length; i++) {
            storageMetadata.hooks.push(metadata.hooks[i]);
        }
    }

    function _createRentalPayload(
        RentPayload storage storagePayload,
        RentPayload memory payload
    ) private {
        // set payload struct fields
        _createOrderFulfillment(storagePayload.fulfillment, payload.fulfillment);
        _createOrderMetadata(storagePayload.metadata, payload.metadata);

        // create the rest of the single slot parameters on the rental payload
        storagePayload.orderHash = payload.orderHash;
        storagePayload.nonce = payload.nonce;
        storagePayload.expiration = payload.expiration;
        storagePayload.intendedFulfiller = payload.intendedFulfiller;
    }

    function _createAdvancedOrder(
        AdvancedOrder storage storageAdvancedOrder,
        AdvancedOrder memory advancedOrder
    ) private {
        // create the order parameters on the order to fulfill
        _createOrderParameters(storageAdvancedOrder.parameters, advancedOrder.parameters);

        // create the rest of the static parameters on the order to fulfill
        storageAdvancedOrder.numerator = advancedOrder.numerator;
        storageAdvancedOrder.denominator = advancedOrder.denominator;
        storageAdvancedOrder.signature = advancedOrder.signature;
        storageAdvancedOrder.extraData = advancedOrder.extraData;
    }

    function _createOrderParameters(
        OrderParameters storage storageOrderParameters,
        OrderParameters memory orderParameters
    ) private {
        // create the static order parameters for the order to fulfill
        storageOrderParameters.offerer = orderParameters.offerer;
        storageOrderParameters.zone = orderParameters.zone;
        storageOrderParameters.orderType = orderParameters.orderType;
        storageOrderParameters.startTime = orderParameters.startTime;
        storageOrderParameters.endTime = orderParameters.endTime;
        storageOrderParameters.zoneHash = orderParameters.zoneHash;
        storageOrderParameters.salt = orderParameters.salt;
        storageOrderParameters.conduitKey = orderParameters.conduitKey;
        storageOrderParameters.totalOriginalConsiderationItems = orderParameters
            .totalOriginalConsiderationItems;

        // create the dynamic order parameters for the order to fulfill
        for (uint256 i = 0; i < orderParameters.offer.length; i++) {
            storageOrderParameters.offer.push(orderParameters.offer[i]);
        }
        for (uint256 i = 0; i < orderParameters.consideration.length; i++) {
            storageOrderParameters.consideration.push(orderParameters.consideration[i]);
        }
    }

    function _createSeaportFulfillment(
        Fulfillment storage storageFulfillment,
        Fulfillment memory fulfillment
    ) private {
        // push the offer components to storage
        for (uint256 i = 0; i < fulfillment.offerComponents.length; i++) {
            storageFulfillment.offerComponents.push(fulfillment.offerComponents[i]);
        }

        // push the consideration components to storage
        for (uint256 i = 0; i < fulfillment.considerationComponents.length; i++) {
            storageFulfillment.considerationComponents.push(
                fulfillment.considerationComponents[i]
            );
        }
    }

    function _seaportItemTypeToRentalItemType(
        SeaportItemType seaportItemType
    ) internal pure returns (ItemType) {
        if (seaportItemType == SeaportItemType.ERC20) {
            return ItemType.ERC20;
        } else if (seaportItemType == SeaportItemType.ERC721) {
            return ItemType.ERC721;
        } else if (seaportItemType == SeaportItemType.ERC1155) {
            return ItemType.ERC1155;
        } else {
            revert("seaport item type not supported");
        }
    }

    function _createRentalOrder(
        OrderToFulfill memory orderToFulfill
    ) internal view returns (RentalOrder memory rentalOrder) {
        // get the order parameters
        OrderParameters memory parameters = orderToFulfill.advancedOrder.parameters;

        // get the payload
        RentPayload memory payload = orderToFulfill.payload;

        // get the metadata
        OrderMetadata memory metadata = payload.metadata;

        // construct a rental order
        rentalOrder = RentalOrder({
            seaportOrderHash: orderToFulfill.orderHash,
            items: new Item[](parameters.offer.length + parameters.consideration.length),
            hooks: metadata.hooks,
            orderType: metadata.orderType,
            lender: parameters.offerer,
            renter: payload.intendedFulfiller,
            rentalWallet: payload.fulfillment.recipient,
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + metadata.rentDuration
        });

        // for each new offer item being rented, create a new item struct to add to the rental order
        for (uint256 i = 0; i < parameters.offer.length; i++) {
            // PAYEE orders cannot have offer items
            require(
                metadata.orderType != OrderType.PAYEE,
                "TEST: cannot have offer items in PAYEE order"
            );

            // get the offer item
            OfferItem memory offerItem = parameters.offer[i];

            // determine the item type
            ItemType itemType = _seaportItemTypeToRentalItemType(offerItem.itemType);

            // determine which entity the payment will settle to
            SettleTo settleTo = offerItem.itemType == SeaportItemType.ERC20
                ? SettleTo.RENTER
                : SettleTo.LENDER;

            // create a new rental item
            rentalOrder.items[i] = Item({
                itemType: itemType,
                settleTo: settleTo,
                token: offerItem.token,
                amount: offerItem.startAmount,
                identifier: offerItem.identifierOrCriteria
            });
        }

        // for each consideration item in return, create a new item struct to add to the rental order
        for (uint256 i = 0; i < parameters.consideration.length; i++) {
            // PAY orders cannot have consideration items
            require(
                metadata.orderType != OrderType.PAY,
                "TEST: cannot have consideration items in PAY order"
            );

            // get the offer item
            ConsiderationItem memory considerationItem = parameters.consideration[i];

            // determine the item type
            ItemType itemType = _seaportItemTypeToRentalItemType(
                considerationItem.itemType
            );

            // determine which entity the payment will settle to
            SettleTo settleTo = metadata.orderType == OrderType.PAYEE &&
                considerationItem.itemType == SeaportItemType.ERC20
                ? SettleTo.RENTER
                : SettleTo.LENDER;

            // calculate item index offset
            uint256 itemIndex = i + parameters.offer.length;

            // create a new payment item
            rentalOrder.items[itemIndex] = Item({
                itemType: itemType,
                settleTo: settleTo,
                token: considerationItem.token,
                amount: considerationItem.startAmount,
                identifier: considerationItem.identifierOrCriteria
            });
        }
    }

    function _signProtocolOrder(
        uint256 signerPrivateKey,
        bytes32 payloadHash
    ) internal view returns (bytes memory signature) {
        // fetch domain separator from create policy
        bytes32 domainSeparator = create.domainSeparator();

        // sign the EIP-712 digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            domainSeparator.toTypedDataHash(payloadHash)
        );

        // encode the signature
        signature = abi.encodePacked(r, s, v);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Fulfillment Amendments                           //
    /////////////////////////////////////////////////////////////////////////////////

    function withFulfiller(ProtocolAccount memory _fulfiller) internal {
        fulfiller = _fulfiller;
    }

    function withRecipient(address _recipient) internal {
        seaportRecipient = _recipient;
    }

    function withAdvancedOrder(
        AdvancedOrder memory _advancedOrder,
        uint256 orderIndex
    ) internal {
        // get a storage pointer to the order to fulfill
        OrderToFulfill storage orderToFulfill = ordersToFulfill[orderIndex];

        // set the new advanced order
        _createAdvancedOrder(orderToFulfill.advancedOrder, _advancedOrder);
    }

    function withSeaportMatchOrderFulfillment(Fulfillment memory _fulfillment) internal {
        // get a pointer to a new seaport fulfillment
        Fulfillment storage fulfillment = seaportMatchOrderFulfillments.push();

        // set the fulfillment
        _createSeaportFulfillment(
            fulfillment,
            Fulfillment({
                offerComponents: _fulfillment.offerComponents,
                considerationComponents: _fulfillment.considerationComponents
            })
        );
    }

    function withSeaportMatchOrderFulfillments(
        Fulfillment[] memory fulfillments
    ) internal {
        // reset all current seaport match order fulfillments
        resetSeaportMatchOrderFulfillments();

        // add the new offer items to storage
        for (uint256 i = 0; i < fulfillments.length; i++) {
            // get a pointer to a new seaport fulfillment
            Fulfillment storage fulfillment = seaportMatchOrderFulfillments.push();

            // set the fulfillment
            _createSeaportFulfillment(
                fulfillment,
                Fulfillment({
                    offerComponents: fulfillments[i].offerComponents,
                    considerationComponents: fulfillments[i].considerationComponents
                })
            );
        }
    }

    function withBaseOrderFulfillmentComponents() internal {
        // create offer fulfillments. We need to specify which offer items can be aggregated
        // into one transaction. For example, 2 different orders where the same seller is offering
        // the same item in each.
        //
        // Since BASE orders will only contain ERC721 offer items, these cannot be aggregated. So, a separate fulfillment
        // is created for each order.
        for (uint256 i = 0; i < ordersToFulfill.length; i++) {
            // get a pointer to a new offer fulfillment array. This array will contain indexes of
            // orders and items which are all grouped on whether they can be combined in a single transferFrom()
            FulfillmentComponent[] storage offerFulfillments = seaportOfferFulfillments
                .push();

            // number of offer items in the order
            uint256 offerItemsInOrder = ordersToFulfill[i]
                .advancedOrder
                .parameters
                .offer
                .length;

            // add a single fulfillment component for each offer item in the order
            for (uint256 j = 0; j < offerItemsInOrder; j++) {
                offerFulfillments.push(
                    FulfillmentComponent({orderIndex: i, itemIndex: j})
                );
            }
        }

        // create consideration fulfillments. We need to specify which consideration items can be aggregated
        // into one transaction. For example, 3 different orders where the same fungible consideration items are
        // expected in return.
        //
        // get a pointer to a new offer fulfillment array. This array will contain indexes of
        // orders and items which are all grouped on whether they can be combined in a single transferFrom()
        FulfillmentComponent[]
            storage considerationFulfillments = seaportConsiderationFulfillments.push();

        // BASE orders will only contain ERC20 items, these are fungible and are candidates for aggregation. Because
        // all of these BASE orders will be fulfilled by the same EOA, and all ERC20 consideration items are going to the
        // ESCRW contract, the consideration items can be aggregated. In other words, Seaport will only make a single transfer
        // of ERC20 tokens from the fulfiller EOA to the payment escrow contract.
        //
        // put all fulfillments into one which can be an aggregated transfer
        for (uint256 i = 0; i < ordersToFulfill.length; i++) {
            considerationFulfillments.push(
                FulfillmentComponent({orderIndex: i, itemIndex: 0})
            );
        }
    }

    function withLinkedPayAndPayeeOrders(
        uint256 payOrderIndex,
        uint256 payeeOrderIndex
    ) internal {
        // get the PAYEE order
        OrderParameters memory payeeOrder = ordersToFulfill[payeeOrderIndex]
            .advancedOrder
            .parameters;

        // For each consideration item in the PAYEE order, a fulfillment should be
        // constructed with a corresponding item from the PAY order's offer items.
        for (uint256 i = 0; i < payeeOrder.consideration.length; ++i) {
            // define the offer components
            FulfillmentComponent[] memory offerComponents = new FulfillmentComponent[](1);
            offerComponents[0] = FulfillmentComponent({
                orderIndex: payOrderIndex,
                itemIndex: i
            });

            // define the consideration components
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);
            considerationComponents[0] = FulfillmentComponent({
                orderIndex: payeeOrderIndex,
                itemIndex: i
            });

            // get a pointer to a new seaport fulfillment
            Fulfillment storage fulfillment = seaportMatchOrderFulfillments.push();

            // set the fulfillment
            _createSeaportFulfillment(
                fulfillment,
                Fulfillment({
                    offerComponents: offerComponents,
                    considerationComponents: considerationComponents
                })
            );
        }
    }

    function resetFulfiller() internal {
        delete fulfiller;
    }

    function resetOrdersToFulfill() internal {
        delete ordersToFulfill;
    }

    function resetSeaportMatchOrderFulfillments() internal {
        delete seaportMatchOrderFulfillments;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                           Fulfillment Finalization                          //
    /////////////////////////////////////////////////////////////////////////////////

    function _finalizePayOrderFulfillment(
        bytes memory expectedError
    )
        private
        returns (RentalOrder memory payRentalOrder, RentalOrder memory payeeRentalOrder)
    {
        // get the orders to fulfill
        OrderToFulfill memory payOrder = ordersToFulfill[0];
        OrderToFulfill memory payeeOrder = ordersToFulfill[1];

        // create rental orders
        payRentalOrder = _createRentalOrder(payOrder);
        payeeRentalOrder = _createRentalOrder(payeeOrder);

        // expect an error if error data was provided
        if (expectedError.length != 0) {
            vm.expectRevert(expectedError);
        }
        // otherwise, expect the relevant event to be emitted.
        else {
            vm.expectEmit({emitter: address(create)});
            emit Events.RentalOrderStarted(
                create.getRentalOrderHash(payRentalOrder),
                payOrder.payload.metadata.emittedExtraData,
                payRentalOrder.seaportOrderHash,
                payRentalOrder.items,
                payRentalOrder.hooks,
                payRentalOrder.orderType,
                payRentalOrder.lender,
                payRentalOrder.renter,
                payRentalOrder.rentalWallet,
                payRentalOrder.startTimestamp,
                payRentalOrder.endTimestamp
            );
        }

        // the offerer of the PAYEE order fulfills the orders.
        vm.prank(fulfiller.addr);

        // fulfill the orders
        seaport.matchAdvancedOrders(
            _deconstructOrdersToFulfill(),
            new CriteriaResolver[](0),
            seaportMatchOrderFulfillments,
            seaportRecipient
        );

        // clear structs
        resetFulfiller();
        resetOrdersToFulfill();
        resetSeaportMatchOrderFulfillments();
    }

    function finalizePayOrderFulfillment()
        internal
        returns (RentalOrder memory payRentalOrder, RentalOrder memory payeeRentalOrder)
    {
        (payRentalOrder, payeeRentalOrder) = _finalizePayOrderFulfillment(bytes(""));
    }

    function finalizePayOrderFulfillmentWithError(
        bytes memory expectedError
    )
        internal
        returns (RentalOrder memory payRentalOrder, RentalOrder memory payeeRentalOrder)
    {
        (payRentalOrder, payeeRentalOrder) = _finalizePayOrderFulfillment(expectedError);
    }

    function _finalizeBaseOrderFulfillment(
        bytes memory expectedError
    ) private returns (RentalOrder memory rentalOrder) {
        // get the order to fulfill
        OrderToFulfill memory baseOrder = ordersToFulfill[0];

        // create a rental order
        rentalOrder = _createRentalOrder(baseOrder);

        // expect an error if error data was provided
        if (expectedError.length != 0) {
            vm.expectRevert(expectedError);
        }
        // otherwise, expect the relevant event to be emitted.
        else {
            vm.expectEmit({emitter: address(create)});
            emit Events.RentalOrderStarted(
                create.getRentalOrderHash(rentalOrder),
                baseOrder.payload.metadata.emittedExtraData,
                rentalOrder.seaportOrderHash,
                rentalOrder.items,
                rentalOrder.hooks,
                rentalOrder.orderType,
                rentalOrder.lender,
                rentalOrder.renter,
                rentalOrder.rentalWallet,
                rentalOrder.startTimestamp,
                rentalOrder.endTimestamp
            );
        }

        // the owner of the rental wallet fulfills the advanced order, and marks the rental wallet
        // as the recipient
        vm.prank(fulfiller.addr);
        seaport.fulfillAdvancedOrder(
            baseOrder.advancedOrder,
            new CriteriaResolver[](0),
            conduitKey,
            seaportRecipient
        );

        // clear structs
        resetFulfiller();
        resetOrdersToFulfill();
        resetSeaportMatchOrderFulfillments();
    }

    function finalizeBaseOrderFulfillment()
        internal
        returns (RentalOrder memory rentalOrder)
    {
        rentalOrder = _finalizeBaseOrderFulfillment(bytes(""));
    }

    function finalizeBaseOrderFulfillmentWithError(
        bytes memory expectedError
    ) internal returns (RentalOrder memory rentalOrder) {
        rentalOrder = _finalizeBaseOrderFulfillment(expectedError);
    }

    function finalizeBaseOrdersFulfillment()
        internal
        returns (RentalOrder[] memory rentalOrders)
    {
        // Instantiate rental orders
        uint256 numOrdersToFulfill = ordersToFulfill.length;
        rentalOrders = new RentalOrder[](numOrdersToFulfill);

        // convert each order to fulfill into a rental order
        for (uint256 i = 0; i < numOrdersToFulfill; i++) {
            rentalOrders[i] = _createRentalOrder(ordersToFulfill[i]);
        }

        // Expect the relevant events to be emitted.
        for (uint256 i = 0; i < rentalOrders.length; i++) {
            vm.expectEmit({emitter: address(create)});
            emit Events.RentalOrderStarted(
                create.getRentalOrderHash(rentalOrders[i]),
                ordersToFulfill[i].payload.metadata.emittedExtraData,
                rentalOrders[i].seaportOrderHash,
                rentalOrders[i].items,
                rentalOrders[i].hooks,
                rentalOrders[i].orderType,
                rentalOrders[i].lender,
                rentalOrders[i].renter,
                rentalOrders[i].rentalWallet,
                rentalOrders[i].startTimestamp,
                rentalOrders[i].endTimestamp
            );
        }

        // the owner of the rental wallet fulfills the advanced orders, and marks the rental wallet
        // as the recipient
        vm.prank(fulfiller.addr);
        seaport.fulfillAvailableAdvancedOrders(
            _deconstructOrdersToFulfill(),
            new CriteriaResolver[](0),
            seaportOfferFulfillments,
            seaportConsiderationFulfillments,
            conduitKey,
            seaportRecipient,
            ordersToFulfill.length
        );

        // clear structs
        resetFulfiller();
        resetOrdersToFulfill();
        resetSeaportMatchOrderFulfillments();
    }

    function finalizePayOrdersFulfillment()
        internal
        returns (RentalOrder[] memory rentalOrders)
    {
        // Instantiate rental orders
        uint256 numOrdersToFulfill = ordersToFulfill.length;
        rentalOrders = new RentalOrder[](numOrdersToFulfill);

        // convert each order to fulfill into a rental order
        for (uint256 i = 0; i < numOrdersToFulfill; i++) {
            rentalOrders[i] = _createRentalOrder(ordersToFulfill[i]);
        }

        // Expect the relevant events to be emitted.
        for (uint256 i = 0; i < rentalOrders.length; i++) {
            // only expect the event if its a PAY order
            if (ordersToFulfill[i].payload.metadata.orderType == OrderType.PAY) {
                vm.expectEmit({emitter: address(create)});
                emit Events.RentalOrderStarted(
                    create.getRentalOrderHash(rentalOrders[i]),
                    ordersToFulfill[i].payload.metadata.emittedExtraData,
                    rentalOrders[i].seaportOrderHash,
                    rentalOrders[i].items,
                    rentalOrders[i].hooks,
                    rentalOrders[i].orderType,
                    rentalOrders[i].lender,
                    rentalOrders[i].renter,
                    rentalOrders[i].rentalWallet,
                    rentalOrders[i].startTimestamp,
                    rentalOrders[i].endTimestamp
                );
            }
        }

        // the offerer of the PAYEE order fulfills the orders. For this order, it shouldn't matter
        // what the recipient address is
        vm.prank(fulfiller.addr);
        seaport.matchAdvancedOrders(
            _deconstructOrdersToFulfill(),
            new CriteriaResolver[](0),
            seaportMatchOrderFulfillments,
            seaportRecipient
        );

        // clear structs
        resetFulfiller();
        resetOrdersToFulfill();
        resetSeaportMatchOrderFulfillments();
    }

    function _deconstructOrdersToFulfill()
        private
        view
        returns (AdvancedOrder[] memory advancedOrders)
    {
        // get the length of the orders to fulfill
        advancedOrders = new AdvancedOrder[](ordersToFulfill.length);

        // build up the advanced orders
        for (uint256 i = 0; i < ordersToFulfill.length; i++) {
            advancedOrders[i] = ordersToFulfill[i].advancedOrder;
        }
    }
}
