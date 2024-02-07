// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order, OfferItem, ItemType} from "@seaport-types/lib/ConsiderationStructs.sol";

import {OnStartAirdropHook} from "@src/examples/airdrop-hooks/OnStartAirdropHook.sol";
import {
    Hook,
    OrderType,
    OrderMetadata,
    RentalOrder
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {MockERC20} from "@test/mocks/tokens/standard/MockERC20.sol";
import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";

contract Hook_OnStartAirdropHook_Test is BaseTest {
    // hook contract
    OnStartAirdropHook public hook;

    // token which will be minted to renters
    MockERC721 public tokenToMint;

    function setUp() public override {
        super.setUp();

        // deploy token to mint
        tokenToMint = new MockERC721();

        // deploy hook contract
        hook = new OnStartAirdropHook(
            address(create),
            address(erc721s[0]),
            address(tokenToMint)
        );

        // admin enables the hook. Use binary 00000010 so that the hook
        // is enabled for `onStart` calls only
        vm.prank(deployer.addr);
        guard.updateHookStatus(address(hook), uint8(2));

        // assert that hook set up was successful
        assertEq(STORE.hookOnStart(address(hook)), true);
        assertEq(STORE.hookOnStop(address(hook)), false);
        assertEq(STORE.hookOnTransaction(address(hook)), false);
    }

    function test_Success_TokenMintedOnStart() public {
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

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: ""
        });

        // add the hooks to the rental
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

        // finalize the base order fulfillment
        RentalOrder memory rentalOrder = finalizeBaseOrderFulfillment();

        // assert that the token was minted to bob after starting the rental
        assertEq(tokenToMint.ownerOf(0), address(bob.safe));

        // speed up in time past the rental expiration
        vm.warp(block.timestamp + 750);

        // stop the rental order
        stop.stopRent(rentalOrder);

        // assert the stop passed, and successfully returned the asset
        assertEq(erc721s[0].ownerOf(0), alice.addr);
    }
}
