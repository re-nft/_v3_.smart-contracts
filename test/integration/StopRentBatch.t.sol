// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order} from "@seaport-types/lib/ConsiderationStructs.sol";

import {OrderType, OrderMetadata, RentalOrder} from "@src/libraries/RentalStructs.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";

contract TestStopRentBatch is BaseTest {
    function test_stopRentBatch_baseOrders_allSameLender() public {
        // create 3 orders and fulfillments
        for (uint256 i = 0; i < 3; i++) {
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

        // speed up in time past the rental expiration
        vm.warp(block.timestamp + 750);

        // stop the rental order
        vm.prank(alice.addr);
        stop.stopRentBatch(rentalOrders);

        // for each rental order stopped, perform some assertions
        for (uint256 i = 0; i < rentalOrders.length; i++) {
            // assert that the rental order doesnt exist in storage
            assertEq(STORE.orders(rentalOrders[i].seaportOrderHash), false);

            // assert that the token is no longer rented out in storage
            assertEq(
                STORE.isRentedOut(rentalOrders[i].rentalWallet, address(erc721s[0]), i),
                false
            );

            // assert that the ERC721 is back to its original owner
            assertEq(erc721s[0].ownerOf(i), address(alice.addr));
        }

        // assert that the offerer received a payment
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(10300));

        // assert that a payment was pulled from the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(0));

        // assert that the fulfiller made a payment for each order
        assertEq(erc20s[0].balanceOf(dan.addr), uint256(9700));
    }

    function test_stopRentBatch_payOrders_allDifferentLenders() public {
        // create an array of offerers
        ProtocolAccount[] memory offerers = new ProtocolAccount[](3);
        offerers[0] = alice;
        offerers[1] = bob;
        offerers[2] = carol;

        // for each offerer, create an order and a fulfillment
        for (uint256 i = 0; i < offerers.length; i++) {
            // create a PAY order
            createOrder({
                offerer: offerers[i],
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
                offerer: dan,
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
                _fulfiller: dan,
                order: payOrder,
                orderHash: payOrderHash,
                metadata: payOrderMetadata
            });

            // create an order fulfillment for the payee order
            createOrderFulfillment({
                _fulfiller: dan,
                order: payeeOrder,
                orderHash: payeeOrderHash,
                metadata: payeeOrderMetadata
            });

            // add an amendment to include the seaport fulfillment structs
            withLinkedPayAndPayeeOrders({
                payOrderIndex: (i * 2),
                payeeOrderIndex: (i * 2) + 1
            });
        }

        // finalize the order pay/payee order fulfillments
        RentalOrder[] memory rentalOrders = finalizePayOrdersFulfillment();

        // pull out just the PAY orders
        RentalOrder[] memory payRentalOrders = new RentalOrder[](3);
        for (uint256 i = 0; i < rentalOrders.length; i++) {
            if (rentalOrders[i].orderType == OrderType.PAY) {
                payRentalOrders[i / 2] = rentalOrders[i];
            }
        }

        // speed up in time past the rental expiration
        vm.warp(block.timestamp + 750);

        // renter stops the rental order
        vm.prank(dan.addr);
        stop.stopRentBatch(payRentalOrders);

        // for each rental order stopped, perform some assertions
        for (uint256 i = 0; i < payRentalOrders.length; i++) {
            // assert that the rental order doesnt exist in storage
            assertEq(STORE.orders(payRentalOrders[i].seaportOrderHash), false);

            // assert that the token is no longer rented out in storage
            assertEq(
                STORE.isRentedOut(
                    payRentalOrders[i].rentalWallet,
                    address(erc721s[0]),
                    i
                ),
                false
            );

            // assert that the ERC721 is back to its original owner
            assertEq(erc721s[0].ownerOf(i), address(offerers[i].addr));

            // assert that each offerer made a payment
            assertEq(erc20s[0].balanceOf(offerers[i].addr), uint256(9900));
        }

        // assert that the payments were pulled from the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(0));

        // assert that the fulfiller was paid for each order
        assertEq(erc20s[0].balanceOf(dan.addr), uint256(10300));
    }
}
