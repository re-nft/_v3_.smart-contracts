// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order} from "@seaport-types/lib/ConsiderationStructs.sol";

import {OrderType, OrderMetadata, RentalOrder} from "@src/libraries/RentalStructs.sol";

import {BaseTest} from "@test/BaseTest.sol";

contract TestStopRent is BaseTest {
    function test_StopRent_BaseOrder() public {
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

        // speed up in time past the rental expiration
        vm.warp(block.timestamp + 750);

        // stop the rental order
        vm.prank(alice.addr);
        stop.stopRent(rentalOrder);

        // assert that the rental order doesnt exist in storage
        assertEq(STORE.orders(orderHash), false);

        // assert that the token is no longer rented out in storage
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), 0);

        // assert that the ERC721 is back to its original owner
        assertEq(erc721s[0].ownerOf(0), address(alice.addr));

        // assert that the offerer received a payment
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(10100));

        // assert that the fulfiller made a payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(9900));

        // assert that a payment was pulled from the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(0));
    }

    function test_StopRent_PayOrder_InFull_StoppedByLender() public {
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
        (RentalOrder memory payRentalOrder, ) = finalizePayOrderFulfillment();

        // speed up in time past the rental expiration
        vm.warp(block.timestamp + 750);

        // stop the rental order
        vm.prank(alice.addr);
        stop.stopRent(payRentalOrder);

        // get the rental order hashes
        bytes32 payRentalOrderHash = create.getRentalOrderHash(payRentalOrder);

        // assert that the rental order doesnt exist in storage
        assertEq(STORE.orders(payRentalOrderHash), false);

        // assert that the token is no longer rented out in storage
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), 0);

        // assert that the ERC721 is back to its original owner
        assertEq(erc721s[0].ownerOf(0), address(alice.addr));

        // assert that the offerer made a payment
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(9900));

        // assert that the fulfiller received the payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(10100));

        // assert that a payment was pulled from the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(0));
    }

    function test_stopRent_payOrder_inFull_stoppedByRenter() public {
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
        (RentalOrder memory payRentalOrder, ) = finalizePayOrderFulfillment();

        // speed up in time past the rental expiration
        vm.warp(block.timestamp + 750);

        // stop the rental order
        vm.prank(bob.addr);
        stop.stopRent(payRentalOrder);

        // get the rental order hashes
        bytes32 payRentalOrderHash = create.getRentalOrderHash(payRentalOrder);

        // assert that the rental order doesnt exist in storage
        assertEq(STORE.orders(payRentalOrderHash), false);

        // assert that the token is no longer rented out in storage
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), 0);

        // assert that the ERC721 is back to its original owner
        assertEq(erc721s[0].ownerOf(0), address(alice.addr));

        // assert that the offerer made a payment
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(9900));

        // assert that the fulfiller received the payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(10100));

        // assert that a payment was pulled from the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(0));
    }

    function test_stopRent_payOrder_proRata_stoppedByLender() public {
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
        (RentalOrder memory payRentalOrder, ) = finalizePayOrderFulfillment();

        // speed up in time only 40% of the way through the rental period
        vm.warp(block.timestamp + 200);

        // stop the rental order
        vm.prank(alice.addr);
        stop.stopRent(payRentalOrder);

        // get the rental order hashes
        bytes32 payRentalOrderHash = create.getRentalOrderHash(payRentalOrder);

        // assert that the rental order doesnt exist in storage
        assertEq(STORE.orders(payRentalOrderHash), false);

        // assert that the token is no longer rented out in storage
        assertEq(STORE.isRentedOut(address(bob.safe), address(erc721s[0]), 0), 0);

        // assert that the ERC721 is back to its original owner
        assertEq(erc721s[0].ownerOf(0), address(alice.addr));

        // assert that the offerer received a refund
        assertEq(erc20s[0].balanceOf(alice.addr), uint256(9960));

        // assert that the fulfiller received a partial payment
        assertEq(erc20s[0].balanceOf(bob.addr), uint256(10040));

        // assert that a payment was pulled from the escrow contract
        assertEq(erc20s[0].balanceOf(address(ESCRW)), uint256(0));
    }
}
