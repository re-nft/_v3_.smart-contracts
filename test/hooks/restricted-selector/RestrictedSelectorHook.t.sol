// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order, OfferItem, ItemType} from "@seaport-types/lib/ConsiderationStructs.sol";

import {
    RestrictedSelectorHook
} from "@src/examples/restricted-selector/RestrictedSelectorHook.sol";
import {Game, Team} from "@src/examples/restricted-selector/Game.sol";
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

contract Hook_RestrictedSelectorHook_Test is BaseTest {
    // hook contract
    RestrictedSelectorHook public hook;

    // token which will be rented
    MockERC721 public gameToken;

    // target game contract
    Game public game;

    function setUp() public override {
        super.setUp();

        // deploy contracts needed for hook
        gameToken = erc721s[0];
        game = new Game(address(gameToken));
        hook = new RestrictedSelectorHook(
            address(create),
            address(stop),
            address(game),
            address(gameToken)
        );

        // admin enables the hook. Use binary 00000111 so that the hook
        // is enabled for `onStart`, `onStop`, and `onTransaction` calls
        vm.prank(deployer.addr);
        guard.updateHookStatus(address(hook), uint8(7));

        // admin enables the hook path to point to the game contract
        vm.prank(deployer.addr);
        guard.updateHookPath(address(game), address(hook));

        // assert that hook set up was successful
        assertEq(STORE.hookOnStart(address(hook)), true);
        assertEq(STORE.hookOnStop(address(hook)), true);
        assertEq(STORE.hookOnTransaction(address(hook)), true);
        assertEq(STORE.contractToHook(address(game)), address(hook));
    }

    // Helper function to start a rental using the game token
    function _startRentalWithGameToken(
        uint256 tokensToRent,
        Hook[] memory hooks
    ) internal returns (RentalOrder memory rentalOrder) {
        // create a BASE order where a lender offers the `gameToken` in
        // exchange for some erc20 tokens
        createOrder({
            offerer: alice,
            orderType: OrderType.BASE,
            erc721Offers: tokensToRent,
            erc1155Offers: 0,
            erc20Offers: 0,
            erc721Considerations: 0,
            erc1155Considerations: 0,
            erc20Considerations: 1
        });

        // use an amendment to add hooks to the metadata
        withOrderMetadata(
            OrderMetadata({
                // the type of order being created
                orderType: OrderType.BASE,
                // the duration of the rental in seconds
                rentDuration: 500,
                // the hooks that will act as middleware for the items in the order
                hooks: hooks,
                // any extra data to be emitted upon order fulfillment
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

        // finalize the base order fulfillment. This executes the token swap
        // and starts the rental.
        rentalOrder = finalizeBaseOrderFulfillment();
    }

    // Tests a hook for a single rented token that prevents calling `train()` on the token.
    function test_Reverts_TrainSelector_NotCallable() public {
        // create a bitmap that will disable the `train()` function selector
        uint256 bitmap = 1; // corresponds to 0x0001

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: abi.encode(bitmap)
        });

        // start the rental. This should activate the given hooks and use the
        // bitmap to determine which function selectors are safe to use
        _startRentalWithGameToken(1, hooks);

        // create safe transaction for game token 0 that interacts with the game contract
        bytes memory transaction = abi.encodeWithSelector(Game.train.selector, 0);

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            transaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError(
            address(bob.safe),
            address(game),
            transaction,
            transactionSignature,
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "train() not callable for this token Id"
            )
        );

        // assert that the level of the game token did not change
        assertEq(game.levelOf(0), 0);
    }

    // Tests a hook for a single rented token that prevents calling `retire()`,
    // but allows calling `train()` on the token.
    function test_Reverts_TrainSelector_Callable_RetireSelector_NotCallable() public {
        // create a bitmap that will disable the `retire()` function selector
        uint256 bitmap = 2; // corresponds to 0x0010

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: abi.encode(bitmap)
        });

        // start the rental. This should activate the given hooks and use the
        // bitmap to determine which function selectors are safe to use
        _startRentalWithGameToken(1, hooks);

        // create safe transaction for game token 0 that interacts with the game contract
        bytes memory transaction = abi.encodeWithSelector(Game.train.selector, 0);

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            transaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction(
            address(bob.safe),
            address(game),
            transaction,
            transactionSignature
        );

        // assert that the level of the game token did change
        assertEq(game.levelOf(0), 1, "game token level should not have changed");

        // create safe transaction for game token 0 that interacts with the game contract by calling `retire()`
        bytes memory retireTransaction = abi.encodeWithSelector(Game.retire.selector, 0);

        // sign the safe transaction
        bytes memory retireTransactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            retireTransaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError(
            address(bob.safe),
            address(game),
            retireTransaction,
            retireTransactionSignature,
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "retire() not callable for this token Id"
            )
        );

        // assert that the level of the game token was incremented
        assertEq(game.isRetired(0), false);
    }

    // Tests a hook which blocks `train()` on the rented token,
    // but not on the non-rented token.
    function test_Reverts_TrainSelector_Callable_NonRentedOnly() public {
        // create a bitmap that will disable the `train()` function selector
        uint256 bitmap = 1; // corresponds to 0x0001

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: abi.encode(bitmap)
        });

        // start the rental. This should activate the given hooks and use the
        // bitmap to determine which function selectors are safe to use
        _startRentalWithGameToken(1, hooks);

        // mint a non-rented token to the safe
        erc721s[0].mint(address(bob.safe));

        // create safe transaction for game token 0 that interacts with the game contract
        bytes memory transaction = abi.encodeWithSelector(Game.train.selector, 0);

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            transaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError(
            address(bob.safe),
            address(game),
            transaction,
            transactionSignature,
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "train() not callable for this token Id"
            )
        );

        // assert that the level of the rented game token did not change
        assertEq(game.levelOf(0), 0, "game token level should not have changed");

        // create safe transaction for game token 1 that interacts with the game contract
        bytes memory secondTransaction = abi.encodeWithSelector(Game.train.selector, 1);

        // sign the safe transaction
        bytes memory secondTransactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            secondTransaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to succeed
        SafeUtils.executeTransaction(
            address(bob.safe),
            address(game),
            secondTransaction,
            secondTransactionSignature
        );

        // assert that the level of the non-rented game token did change
        assertEq(game.levelOf(1), 1);
    }

    // Tests that the subguard entry prevents calling `changeTeam()` if there is an active rental present.
    function test_Reverts_ChangeTeam_NotCallable() public {
        // create a bitmap that will disable the `changeTeam()` function selector
        uint256 bitmap = 4; // corresponds to 0x0100

        // Define the hook for the rental
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            // the hook contract to target
            target: address(hook),
            // index of the item in the order to apply the hook to
            itemIndex: 0,
            // any extra data that the hook will need.
            extraData: abi.encode(bitmap)
        });

        // start the rental. This should activate the given hooks and use the
        // bitmap to determine which function selectors are safe to use
        _startRentalWithGameToken(1, hooks);

        // create safe transaction that interacts with the game contract by calling `changeTeam()`
        bytes memory transaction = abi.encodeWithSelector(
            Game.changeTeam.selector,
            Team.RED
        );

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            transaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError(
            address(bob.safe),
            address(game),
            transaction,
            transactionSignature,
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "changeTeam() not callable when holding a GameToken rental"
            )
        );

        // assert that the level of the game token was incremented
        assertEq(uint256(game.teamOf(0)), uint256(Team.NO_TEAM));
    }

    // Tests allowing a call to `changeTeam()` only if there are no active rentals
    // in the collection.
    function test_Success_ChangeTeam_NoActiveRentals() public {
        // mint a non-rented token to the safe
        erc721s[0].mint(address(bob.safe));

        // create safe transaction that interacts with the game contract by calling `changeTeam()`
        bytes memory transaction = abi.encodeWithSelector(
            Game.changeTeam.selector,
            Team.RED
        );

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(game),
            transaction
        );

        // impersonate the safe owner
        vm.prank(bob.addr);

        // Expect the transaction to succeed
        SafeUtils.executeTransaction(
            address(bob.safe),
            address(game),
            transaction,
            transactionSignature
        );

        // assert that the team for the token was switched to red
        assertEq(uint256(game.teamOf(0)), uint256(Team.RED));
    }
}
