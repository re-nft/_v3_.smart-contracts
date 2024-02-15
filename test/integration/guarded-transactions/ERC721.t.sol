// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    Order,
    OfferItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";
import {OfferItemLib} from "@seaport-sol/SeaportSol.sol";
import {
    ERC721Burnable
} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {IERC721Errors} from "@openzeppelin-contracts/interfaces/draft-IERC6093.sol";

import {
    OrderType,
    OrderMetadata,
    RentalOrder,
    Hook
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";

contract GuardedTransactions_ERC721_Integration_Test is BaseTest {
    using OfferItemLib for OfferItem;

    function test_Success_ERC721_Burn_NotRented() public {
        // mint token to the rental wallet
        erc721s[0].mint(address(alice.safe), 5);

        // assert that the token exists in the safe
        assertEq(erc721s[0].ownerOf(5), address(alice.safe));

        // create the `burn(uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            ERC721Burnable.burn.selector,
            5
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(alice.safe),
            ownerPrivateKey: alice.privateKey,
            to: address(erc721s[0]),
            transaction: burnCalldata
        });

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction({
            safe: address(alice.safe),
            to: address(erc721s[0]),
            transaction: burnCalldata,
            signature: signature
        });

        // assert the token was burned and is non-existent
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 5)
        );
        erc721s[0].ownerOf(5);
    }

    function test_Reverts_ERC721_Burn_Rented() public {
        // mint token to the lender
        erc721s[0].mint(address(alice.addr), 5);

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
                .withToken(address(erc721s[0]))
                .withIdentifierOrCriteria(5)
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

        // finalize the base order fulfillment
        finalizeBaseOrderFulfillment();

        // assert that the token exists in the safe
        assertEq(erc721s[0].ownerOf(5), address(bob.safe));

        // create the `burn(uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            ERC721Burnable.burn.selector,
            5
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(bob.safe),
            ownerPrivateKey: bob.privateKey,
            to: address(erc721s[0]),
            transaction: burnCalldata
        });

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError({
            safe: address(bob.safe),
            to: address(erc721s[0]),
            transaction: burnCalldata,
            signature: signature,
            expectedError: abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedSelector.selector,
                ERC721Burnable.burn.selector
            )
        });

        // assert that the token still exists in the safe
        assertEq(erc721s[0].ownerOf(5), address(bob.safe));
    }
}
