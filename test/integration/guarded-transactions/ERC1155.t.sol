// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    Order,
    OfferItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";
import {OfferItemLib} from "@seaport-sol/SeaportSol.sol";
import {
    ERC1155Burnable
} from "@openzeppelin-contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import {
    OrderType,
    OrderMetadata,
    RentalOrder,
    Hook
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";

contract GuardedTransactions_ERC1155_Integration_Test is BaseTest {
    using OfferItemLib for OfferItem;

    function test_Success_ERC1155_Burn_NotRented() public {
        // mint token to the rental wallet
        erc1155s[0].mint(address(alice.safe), 5, 10);

        // assert that the token exists in the safe
        assertEq(erc1155s[0].balanceOf(address(alice.safe), 5), 10);

        // create the `burn(address,uint256,uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            ERC1155Burnable.burn.selector,
            address(alice.safe),
            5,
            10
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(alice.safe),
            ownerPrivateKey: alice.privateKey,
            to: address(erc1155s[0]),
            transaction: burnCalldata
        });

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction({
            safe: address(alice.safe),
            to: address(erc1155s[0]),
            transaction: burnCalldata,
            signature: signature
        });

        // assert the tokens were burned
        assertEq(erc1155s[0].balanceOf(address(alice.safe), 5), 0);
    }

    function test_Reverts_ERC1155_Burn_Rented() public {
        // mint token to the lender
        erc1155s[0].mint(address(alice.addr), 5, 10);

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
                .withItemType(SeaportItemType.ERC1155)
                .withToken(address(erc1155s[0]))
                .withIdentifierOrCriteria(5)
                .withStartAmount(10)
                .withEndAmount(10)
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
        assertEq(erc1155s[0].balanceOf(address(bob.safe), 5), 10);

        // create the `burn(address,uint256,uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            ERC1155Burnable.burn.selector,
            address(bob.safe),
            5,
            10
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(bob.safe),
            ownerPrivateKey: bob.privateKey,
            to: address(erc1155s[0]),
            transaction: burnCalldata
        });

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError({
            safe: address(bob.safe),
            to: address(erc1155s[0]),
            transaction: burnCalldata,
            signature: signature,
            expectedError: abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedAssetAmount.selector,
                ERC1155Burnable.burn.selector,
                10,
                0
            )
        });

        // assert that the token still exists in the safe
        assertEq(erc1155s[0].balanceOf(address(bob.safe), 5), 10);
    }

    function test_Fuzz_ERC1155_Burn_PartiallyRented(
        uint256 amountToRent,
        uint256 nonRentedAmount,
        uint256 amountToBurn
    ) public {
        // assume a rental of a positive amount
        vm.assume(amountToRent > 0);

        // assume the amount of tokens is less than 1 trillion with 18 decimal places
        vm.assume(amountToRent < 1e30 && nonRentedAmount < 1e30 && amountToBurn < 1e30);

        // assume there are enough tokens to burn
        vm.assume(amountToRent + nonRentedAmount >= amountToBurn);

        // mint token to the lender
        erc1155s[0].mint(address(alice.addr), 5, amountToRent);

        // mint token directly to the rental safe
        erc1155s[0].mint(address(bob.safe), 5, nonRentedAmount);

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
                .withItemType(SeaportItemType.ERC1155)
                .withToken(address(erc1155s[0]))
                .withIdentifierOrCriteria(5)
                .withStartAmount(amountToRent)
                .withEndAmount(amountToRent)
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
        assertEq(
            erc1155s[0].balanceOf(address(bob.safe), 5),
            amountToRent + nonRentedAmount
        );

        // create the `burn(address,uint256,uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            ERC1155Burnable.burn.selector,
            address(bob.safe),
            5,
            amountToBurn
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(bob.safe),
            ownerPrivateKey: bob.privateKey,
            to: address(erc1155s[0]),
            transaction: burnCalldata
        });

        uint256 remainingBalance = amountToRent + nonRentedAmount - amountToBurn;

        // If the amount that isn't rented is greater than the amount being
        // burned, then the transaction should pass.
        if (nonRentedAmount >= amountToBurn) {
            // Expect the transaction to execute successfully
            SafeUtils.executeTransaction({
                safe: address(bob.safe),
                to: address(erc1155s[0]),
                transaction: burnCalldata,
                signature: signature
            });

            // assert that the remaining token amount exists in the safe after burning
            assertEq(erc1155s[0].balanceOf(address(bob.safe), 5), remainingBalance);
        }
        // Otherwise, we're attempting to burn tokens that have been rented.
        else {
            // Expect the transaction to revert
            SafeUtils.executeTransactionWithError({
                safe: address(bob.safe),
                to: address(erc1155s[0]),
                transaction: burnCalldata,
                signature: signature,
                expectedError: abi.encodeWithSelector(
                    Errors.GuardPolicy_UnauthorizedAssetAmount.selector,
                    ERC1155Burnable.burn.selector,
                    amountToRent,
                    remainingBalance
                )
            });

            // assert that the original token amount before burning still
            // exists in the safe
            assertEq(
                erc1155s[0].balanceOf(address(bob.safe), 5),
                amountToRent + nonRentedAmount
            );
        }
    }

    function test_Reverts_ERC1155_BurnBatch_Always() public {
        // mint token to the rental wallet
        erc1155s[0].mint(address(alice.safe), 5, 10);

        // assert that the token exists in the safe
        assertEq(erc1155s[0].balanceOf(address(alice.safe), 5), 10);

        // create batch IDs
        uint256[] memory ids = new uint256[](1);
        ids[0] = 5;

        // create amounts
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        // create the `burnBatch(address,uint256[],uint256[])` calldata
        bytes memory burnBatchCalldata = abi.encodeWithSelector(
            ERC1155Burnable.burnBatch.selector,
            address(alice.safe),
            ids,
            amounts
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(alice.safe),
            ownerPrivateKey: alice.privateKey,
            to: address(erc1155s[0]),
            transaction: burnBatchCalldata
        });

        // Expect the transaction to revert
        SafeUtils.executeTransactionWithError({
            safe: address(alice.safe),
            to: address(erc1155s[0]),
            transaction: burnBatchCalldata,
            signature: signature,
            expectedError: abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedSelector.selector,
                ERC1155Burnable.burnBatch.selector
            )
        });

        // assert that the token still exists in the safe
        assertEq(erc1155s[0].balanceOf(address(alice.safe), 5), 10);
    }
}
