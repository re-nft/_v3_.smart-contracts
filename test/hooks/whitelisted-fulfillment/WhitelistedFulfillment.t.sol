// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order, OfferItem, ItemType} from "@seaport-types/lib/ConsiderationStructs.sol";

import {
    WhitelistedFulfillmentHook
} from "@src/examples/whitelisted-fulfillment/WhitelistedFulfillmentHook.sol";
import {
    Hook,
    OrderType,
    OrderMetadata,
    RentalOrder
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {BaseTest} from "@test/BaseTest.sol";

contract Hook_WhitelistedFulfillment_Test is BaseTest {
    // hook contract
    WhitelistedFulfillmentHook public hook;

    function setUp() public override {
        super.setUp();

        // deploy hook contract
        hook = new WhitelistedFulfillmentHook();

        // admin enables the hook. Use binary 00000010 so that the hook
        // is enabled for `onStart` calls only
        vm.prank(deployer.addr);
        guard.updateHookStatus(address(hook), uint8(2));

        // assert that hook set up was successful
        assertEq(STORE.hookOnStart(address(hook)), true);
        assertEq(STORE.hookOnStop(address(hook)), false);
        assertEq(STORE.hookOnTransaction(address(hook)), false);
    }

    function test_Success_RenterIsWhitelisted() public {
        // create a BASE order where a lender offers an ERC1155 in
        // exchange for some erc20 tokens
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

        // define the whitelist
        address[] memory whitelist = new address[](2);
        whitelist[0] = address(bob.safe);
        whitelist[1] = address(carol.safe);

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: abi.encode(whitelist)
        });

        // use an amendment to add hooks
        withHooks(hooks);

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

        // finalize the base order fulfillment. This executes the token swap
        // and starts the rental.
        finalizeBaseOrderFulfillment();
    }

    function test_Reverts_RenterIsNotWhitelisted() public {
        // create a BASE order where a lender offers an ERC1155 in
        // exchange for some erc20 tokens
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

        // define the whitelist
        address[] memory whitelist = new address[](2);
        whitelist[0] = address(bob.safe);
        whitelist[1] = address(carol.safe);

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: abi.encode(whitelist)
        });

        // use an amendment to add hooks
        withHooks(hooks);

        // finalize the order creation
        (
            Order memory order,
            bytes32 orderHash,
            OrderMetadata memory metadata
        ) = finalizeOrder();

        // create an order fulfillment with a non-whitelisted address
        createOrderFulfillment({
            _fulfiller: dan,
            order: order,
            orderHash: orderHash,
            metadata: metadata
        });

        // finalize the base order fulfillment. This executes the token swap
        // and starts the rental.
        finalizeBaseOrderFulfillmentWithError(
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "rental wallet is not authorized for this order"
            )
        );
    }
}
