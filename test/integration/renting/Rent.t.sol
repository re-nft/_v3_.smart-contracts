// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    Order,
    OfferItem,
    ConsiderationItem,
    FulfillmentComponent,
    Fulfillment,
    ItemType as SeaportItemType,
    OrderType as SeaportOrderType,
    AdvancedOrder
} from "@seaport-types/lib/ConsiderationStructs.sol";
import {OfferItemLib, ConsiderationItemLib} from "@seaport-sol/SeaportSol.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {
    OrderType,
    OrderMetadata,
    RentalOrder,
    Hook,
    RentPayload
} from "@src/libraries/RentalStructs.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";

contract TestRent is BaseTest {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    function test_Success_Rent_BaseOrder_ERC721() public {
        // create a BASE order
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 1,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 1
        });

        // finalize the order creation
        (
            Order memory order,
            bytes32 orderHash,
            OrderMetadata memory metadata
        ) = finalizeOrder();

        // create an order fulfillment
        createOrderFulfillment({
            _fulfiller: bob,
            order: order,
            orderHash: orderHash,
            metadata: metadata
        });

        // finalize the base order fulfillment
        RentalOrder memory rentalOrder = finalizeBaseOrderFulfillment();

        // get the rental order hash
        bytes32 rentalOrderHash = create.getRentalOrderHash(rentalOrder);

        // assert that the rental order was stored
        assertEq(STORE.orders(rentalOrderHash), true);

        // assert that the token is in storage
        assertGt(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), 0);

        // assert that the fulfiller made a payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(9900));

        // assert that a payment was made to the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(100));

        // assert that a payment was synced properly in the escrow contract
        assertEq(ESCRW.balanceOf(address(erc20s[0])), uint256(100));

        // assert that the ERC721 is in the rental wallet of the fulfiller
        assertEq(erc721s[0].ownerOf(0), address(bob.safe));
    }

    function test_Success_Rent_BaseOrder_ERC1155() public {
        // create a BASE order
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 0,
            erc1155Offers: 1,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 1
        });

        // finalize the order creation
        (
            Order memory order,
            bytes32 orderHash,
            OrderMetadata memory metadata
        ) = finalizeOrder();

        // create an order fulfillment
        createOrderFulfillment({
            _fulfiller: bob,
            order: order,
            orderHash: orderHash,
            metadata: metadata
        });

        // finalize the base order fulfillment
        RentalOrder memory rentalOrder = finalizeBaseOrderFulfillment();

        // get the rental order hash
        bytes32 rentalOrderHash = create.getRentalOrderHash(rentalOrder);

        // assert that the rental order was stored
        assertEq(STORE.orders(rentalOrderHash), true);

        // assert that the token is in storage
        assertGt(STORE.isRentedOut(address(bob.safe), address(erc1155s[0]), 0), 0);

        // assert that the fulfiller made a payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(9900));

        // assert that a payment was made to the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(100));

        // assert that a payment was synced properly in the escrow contract
        assertEq(ESCRW.balanceOf(address(erc20s[0])), uint256(100));

        // assert that the ERC1155 is in the rental wallet of the fulfiller
        assertEq(erc1155s[0].balanceOf(address(bob.safe), 0), uint256(100));
    }

    function test_Success_Rent_BaseOrders() public {
        // create an array of offerers
        ProtocolAccount[] memory offerers = new ProtocolAccount[](3);
        offerers[0] = alice;
        offerers[1] = bob;
        offerers[2] = carol;

        // for each offerer, create an order and a fulfillment
        for (uint256 i = 0; i < offerers.length; i++) {
            // create a BASE order
            createOrder({
                offerer: offerers[i],
                orderType: OrderType.BASE,
                erc721Offers: 1,
                erc1155Offers: 0,
                erc20Offers: 0,
                erc721Considerations: 0,
                erc1155Considerations: 0,
                erc20Considerations: 1
            });

            // finalize the order creation
            (
                Order memory order,
                bytes32 orderHash,
                OrderMetadata memory metadata
            ) = finalizeOrder();

            // create an order fulfillment
            createOrderFulfillment({
                _fulfiller: dan,
                order: order,
                orderHash: orderHash,
                metadata: metadata
            });
        }

        // add an amendment that generates base order fulfillment components
        withBaseOrderFulfillmentComponents();

        // finalize the base order fulfillments in one batch
        RentalOrder[] memory rentalOrders = finalizeBaseOrdersFulfillment();

        // for each rental order fulfilled, perform some assertions
        for (uint256 i = 0; i < rentalOrders.length; i++) {
            // get the rental order hash
            bytes32 rentalOrderHash = create.getRentalOrderHash(rentalOrders[i]);

            // assert that the stored rental order matches the expected rental order
            assertEq(STORE.orders(rentalOrderHash), true);

            // assert that the rental order was stored
            assertGt(STORE.isRentedOut(address(dan.safe), address(erc721s[0]), i), 0);

            // assert that the ERC721 is in the rental wallet of the fulfiller
            assertEq(erc721s[0].ownerOf(i), address(dan.safe));
        }

        // assert that the payments were synced properly in the escrow contract
        assertEq(ESCRW.balanceOf(address(erc20s[0])), uint256(300));

        // assert that the fulfiller made a payment for each order
        assertEq(erc20s[0].balanceOf(dan.addr), uint256(9700));
    }

    function test_Success_Rent_PayOrder() public {
        // create a PAY order
        createOrder({
            offerer: alice,
            orderType: OrderType.PAY,
            erc721Offers: 1,
            erc1155Offers: 0,
            erc20Offers: 1,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 0
        });

        // finalize the pay order creation
        (
            Order memory payOrder,
            bytes32 payOrderHash,
            OrderMetadata memory payOrderMetadata
        ) = finalizeOrder();

        // create a PAYEE order. The fulfiller will be the offerer.
        createOrder({
            offerer: bob,
            orderType: OrderType.PAYEE,
            erc721Offers: 0,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 1,
            erc1155Considerations: 0,
            erc20Considerations: 1
        });

        // finalize the pay order creation
        (
            Order memory payeeOrder,
            bytes32 payeeOrderHash,
            OrderMetadata memory payeeOrderMetadata
        ) = finalizeOrder();

        // create an order fulfillment for the pay order
        createOrderFulfillment({
            _fulfiller: bob,
            order: payOrder,
            orderHash: payOrderHash,
            metadata: payOrderMetadata
        });

        // create an order fulfillment for the payee order
        createOrderFulfillment({
            _fulfiller: bob,
            order: payeeOrder,
            orderHash: payeeOrderHash,
            metadata: payeeOrderMetadata
        });

        // add an amendment to include the seaport fulfillment structs
        withLinkedPayAndPayeeOrders({payOrderIndex: 0, payeeOrderIndex: 1});

        // finalize the order pay/payee order fulfillment
        (
            RentalOrder memory payRentalOrder,
            RentalOrder memory payeeRentalOrder
        ) = finalizePayOrderFulfillment();

        // get the rental order hashes
        bytes32 payRentalOrderHash = create.getRentalOrderHash(payRentalOrder);
        bytes32 payeeRentalOrderHash = create.getRentalOrderHash(payeeRentalOrder);

        // assert that the rental order was stored
        assertEq(STORE.orders(payRentalOrderHash), true);

        // assert that the payee rental order was not put in storage
        assertEq(STORE.orders(payeeRentalOrderHash), false);

        // assert that the token is in storage
        assertGt(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), 0);

        // assert that the offerer made a payment
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(9900));

        // assert that a payment was made to the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(100));

        // assert that a payment was synced properly in the escrow contract
        assertEq(ESCRW.balanceOf(address(erc20s[0])), uint256(100));

        // assert that the ERC721 is in the rental wallet of the fulfiller
        assertEq(erc721s[0].ownerOf(0), address(bob.safe));
    }
}
