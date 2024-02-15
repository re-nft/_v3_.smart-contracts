// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    Order,
    FulfillmentComponent,
    Fulfillment,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {
    OrderType,
    OrderMetadata,
    RentalOrder,
    Hook
} from "@src/libraries/RentalStructs.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";

contract TestRent is BaseTest {
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
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), true);

        // assert that the fulfiller made a payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(9900));

        // assert that a payment was made to the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(100));

        // assert that a payment was synced properly in the escrow contract
        assertEq(ESCRW.balanceOf(address(erc20s[0])), uint256(100));

        // assert that the ERC721 is in the rental wallet of the fulfiller
        assertEq(erc721s[0].ownerOf(0), address(bob.safe));
    }

    function test_Reverts_Rent_BaseOrder_MaxRentDurationExceeded() public {
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

        // add an order metadata amendment
        withOrderMetadata(
            OrderMetadata({
                orderType: OrderType.BASE,
                rentDuration: 30 days,
                hooks: new Hook[](0),
                emittedExtraData: bytes("")
            })
        );

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

        // Expect revert because the rent duration is too long
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_RentDurationTooLong.selector,
                30 days
            )
        );
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
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc1155s[0]), 0), true);

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
            assertEq(STORE.isRentedOut(address(dan.safe), address(erc721s[0]), i), true);

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
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), true);

        // assert that the offerer made a payment
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(9900));

        // assert that a payment was made to the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(100));

        // assert that a payment was synced properly in the escrow contract
        assertEq(ESCRW.balanceOf(address(erc20s[0])), uint256(100));

        // assert that the ERC721 is in the rental wallet of the fulfiller
        assertEq(erc721s[0].ownerOf(0), address(bob.safe));
    }

    // This test involves a PAY order where one of the items is left out of the PAYEE order.
    // Instead, the fulfiller attempts to use the `recipient` input parameter on `matchAdvancedOrders`
    // to try to send an asset to an unauthorized address
    function test_Reverts_Rent_PayOrder_AdversarialRecipient() public {
        // create a PAY order with 2 ERC721s
        createOrder({
            offerer: alice,
            orderType: OrderType.PAY,
            erc721Offers: 2,
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

        // create a PAYEE order. Purposely omit one of the ERC721 tokens from the consideration
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

        // This is a non-standard test so the fulfillment components must be generated manaully

        // define the offer and consideration components for the ERC721
        FulfillmentComponent[] memory offerCompERC721 = new FulfillmentComponent[](1);
        FulfillmentComponent[] memory considCompERC721 = new FulfillmentComponent[](1);

        // link the ERC721 offer item in the PAY order to the ERC721 consideration item
        // in the PAYEE order
        offerCompERC721[0] = FulfillmentComponent({orderIndex: 0, itemIndex: 0});
        considCompERC721[0] = FulfillmentComponent({orderIndex: 1, itemIndex: 0});

        // define the offer and consideration components for the ERC20
        FulfillmentComponent[] memory offerCompERC20 = new FulfillmentComponent[](1);
        FulfillmentComponent[] memory considCompERC20 = new FulfillmentComponent[](1);

        // link the ERC20 offer item in the PAY order to the ERC20 consideration item
        // in the PAYEE order
        offerCompERC20[0] = FulfillmentComponent({orderIndex: 0, itemIndex: 2});
        considCompERC20[0] = FulfillmentComponent({orderIndex: 1, itemIndex: 1});

        // add the fulfillments to the order
        withSeaportMatchOrderFulfillment(
            Fulfillment({
                offerComponents: offerCompERC721,
                considerationComponents: considCompERC721
            })
        );
        withSeaportMatchOrderFulfillment(
            Fulfillment({
                offerComponents: offerCompERC20,
                considerationComponents: considCompERC20
            })
        );

        // Set the recipient to an unauthorized address
        withRecipient(bob.addr);

        // Expect revert because the second ERC721 token was not sent to
        // the rental wallet of the fulfiller, which was specified in the
        // `RentPayload` struct.
        finalizePayOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_UnexpectedTokenRecipient.selector,
                SeaportItemType.ERC721,
                address(erc721s[1]),
                0,
                1,
                bob.addr,
                address(bob.safe)
            )
        );
    }
}
