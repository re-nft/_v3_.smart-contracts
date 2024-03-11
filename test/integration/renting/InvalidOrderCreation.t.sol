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
import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";
import {MockERC20} from "@test/mocks/tokens/standard/MockERC20.sol";

contract Renting_InvalidOrderCreation_Integration_Test is BaseTest {
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    function test_Reverts_Rent_BaseOrder_NonWhitelistedAsset() public {
        // Deploy mock token
        MockERC721 testToken = new MockERC721();

        // mint the token to alice
        testToken.mint(alice.addr);

        // approve the conduit to pull the token
        vm.prank(alice.addr);
        testToken.setApprovalForAll(address(conduit), true);

        // create a BASE order
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 0,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 1
        });

        // add custom offer item
        withOfferItem(
            OfferItemLib
                .empty()
                .withItemType(SeaportItemType.ERC721)
                .withToken(address(testToken))
                .withIdentifierOrCriteria(0)
                .withStartAmount(1)
                .withEndAmount(1)
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

        // Expect revert because the rented asset is not whitelisted
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_AssetNotWhitelisted.selector,
                address(testToken)
            )
        );
    }

    function test_Reverts_Rent_BaseOrder_NonWhitelistedPayment() public {
        // Deploy mock token
        MockERC20 testToken = new MockERC20();

        // mint the token to bob
        testToken.mint(bob.addr, 100);

        // approve the conduit to pull the token
        vm.prank(bob.addr);
        testToken.approve(address(conduit), 100);

        // create a BASE order
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 1,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 0
        });

        // add custom consideration item
        withConsiderationItem(
            ConsiderationItemLib
                .empty()
                .withItemType(SeaportItemType.ERC20)
                .withToken(address(testToken))
                .withIdentifierOrCriteria(0)
                .withStartAmount(100)
                .withEndAmount(100)
                .withRecipient(address(create))
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

        // Expect revert because the payment used to fulfill the order is not whitelisted
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_PaymentNotWhitelisted.selector,
                address(testToken)
            )
        );
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

    // This test involves a PAY order where one of the items is left out of the PAYEE order.
    // Instead, the fulfiller attempts to use the `recipient` input parameter on `matchAdvancedOrders`
    // to try to send an asset to an unauthorized address.
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
        // the create policy.
        finalizePayOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_UnexpectedTokenRecipient.selector,
                SeaportItemType.ERC721,
                address(erc721s[1]),
                0,
                1,
                bob.addr,
                address(create)
            )
        );
    }

    function test_Reverts_Rent_BaseOrder_PartialOrder() public {
        // mint 2 tokens to the lender
        erc1155s[0].mint(alice.addr, 0, 2);

        // create a BASE order
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 0,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 1
        });

        // add custom offer item for one of the tokens
        withOfferItem(
            OfferItemLib
                .empty()
                .withItemType(SeaportItemType.ERC1155)
                .withToken(address(erc1155s[0]))
                .withIdentifierOrCriteria(0)
                .withStartAmount(2)
                .withEndAmount(2)
        );

        // add partial restricted order type
        withOrderType(SeaportOrderType.PARTIAL_RESTRICTED);

        // finalize the order creation
        (
            Order memory order,
            bytes32 orderHash,
            OrderMetadata memory metadata
        ) = finalizeOrder();

        // create the first order fulfillment
        createOrderFulfillment({
            _fulfiller: bob,
            order: order,
            orderHash: orderHash,
            metadata: metadata
        });

        // convert the fulfillment into a partial 50% fulfillment
        ordersToFulfill[0].advancedOrder.denominator = 2;

        // Expect revert because partial orders are not supported
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_SeaportOrderTypeNotSupported.selector,
                SeaportOrderType.PARTIAL_RESTRICTED
            )
        );
    }

    function test_Reverts_Rent_BaseOrder_InvalidRentPayloadSigner() public {
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

        // get the advanced order and the rent payload
        AdvancedOrder memory advancedOrder = ordersToFulfill[0].advancedOrder;
        (RentPayload memory payload, ) = abi.decode(
            advancedOrder.extraData,
            (RentPayload, bytes)
        );

        // generate the signature for the payload
        bytes memory signature = _signProtocolOrder(
            bob.privateKey,
            create.getRentPayloadHash(payload)
        );

        // Pass the rental payload as extra data
        ordersToFulfill[0].advancedOrder.extraData = abi.encode(payload, signature);

        // Expect revert because the co-signer is incorrect
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_UnauthorizedCreatePolicySigner.selector,
                bob.addr
            )
        );
    }

    function test_Reverts_Rent_BaseOrder_RentPayloadReplay() public {
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

        // get the rent payload to reuse with a different order
        bytes memory encodedRentPayloadToReuse = ordersToFulfill[0]
            .advancedOrder
            .extraData;

        // finalize the base order fulfillment
        finalizeBaseOrderFulfillment();

        // create another BASE order
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

        // change the salt of the order
        withSalt(uint256(keccak256("random salt")));

        // finalize the order creation of the second order
        (
            Order memory secondOrder,
            bytes32 secondOrderHash,
            OrderMetadata memory secondMetadata
        ) = finalizeOrder();

        // create an order fulfillment for the second order
        createOrderFulfillment({
            _fulfiller: bob,
            order: secondOrder,
            orderHash: secondOrderHash,
            metadata: secondMetadata
        });

        // since the orders are identical except for the salt, try to swap in a signature and
        // payload from another similar order
        ordersToFulfill[0].advancedOrder.extraData = encodedRentPayloadToReuse;

        // Expect revert because the order hash of the order to fulfill differs from the
        // order hash that was included in the rent payload
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_InvalidPayloadForOrderHash.selector,
                orderHash,
                secondOrderHash
            )
        );
    }

    function test_Reverts_Rent_BaseOrder_MaxOfferItemsExceeded() public {
        // set maximum offer items to one
        vm.prank(deployer.addr);
        admin.setMaxOfferItems(1);

        // create a BASE order with 2 offer items
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 2,
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

        // Expect revert because there are too many offer items
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(Errors.CreatePolicy_OfferCountExceedsMax.selector, 2)
        );
    }

    function test_Reverts_Rent_BaseOrder_MaxConsiderationItemsExceeded() public {
        // set maximum consideration items to one
        vm.prank(deployer.addr);
        admin.setMaxConsiderationItems(1);

        // create a BASE order with 2 consideration items
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: 1,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 2
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

        // Expect revert because there are too many consideration items
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_ConsiderationCountExceedsMax.selector,
                2
            )
        );
    }

    function test_Reverts_Rent_PayOrder_MaxOfferItemsExceeded() public {
        // set maximum offer items to two
        vm.prank(deployer.addr);
        admin.setMaxOfferItems(2);

        // create a PAY order
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

        // create a PAYEE order. The fulfiller will be the offerer.
        createOrder({
            offerer: bob,
            orderType: OrderType.PAYEE,
            erc721Offers: 0,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 2,
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

        // Expect revert because there are too many offer items
        finalizePayOrderFulfillmentWithError(
            abi.encodeWithSelector(Errors.CreatePolicy_OfferCountExceedsMax.selector, 3)
        );
    }

    function test_Reverts_Rent_PayeeOrder_MaxConsiderationItemsExceeded() public {
        // set maximum consideration items to two
        vm.prank(deployer.addr);
        admin.setMaxConsiderationItems(2);

        // create a PAY order
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

        // create a PAYEE order. The fulfiller will be the offerer.
        createOrder({
            offerer: bob,
            orderType: OrderType.PAYEE,
            erc721Offers: 0,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 2,
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

        // Expect revert because there are too many consideration items
        finalizePayOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.CreatePolicy_ConsiderationCountExceedsMax.selector,
                3
            )
        );
    }
}
