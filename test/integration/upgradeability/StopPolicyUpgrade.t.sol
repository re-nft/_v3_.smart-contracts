// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {
    Actions,
    OrderType,
    OrderMetadata,
    RentalOrder
} from "@src/libraries/RentalStructs.sol";
import {
    StopUpgrade,
    StopPolicyMigration
} from "@src/examples/upgrades/StopPolicyUpgrade.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";

contract StopPolicyUpgrade_Upgradeability_Integration_Test is BaseTest {
    // The new policy to upgrade to
    StopUpgrade newStopPolicy;

    // The migration contract
    StopPolicyMigration migration;

    function setUp() public override {
        super.setUp();

        // deploy the new stop policy
        newStopPolicy = new StopUpgrade(kernel);

        // deploy the migration contract
        migration = new StopPolicyMigration(address(newStopPolicy));

        // impersonate the deployer which is the kernel admin
        vm.startPrank(deployer.addr);

        // enable the new stop policy
        kernel.executeAction(Actions.ActivatePolicy, address(newStopPolicy));

        // disable the old stop policy
        kernel.executeAction(Actions.DeactivatePolicy, address(stop));

        // enable the migration contract to be delegate called by rental safes
        admin.toggleWhitelistDelegate(address(migration), true);

        // stop impersonating
        vm.stopPrank();
    }

    function _performMigration(ProtocolAccount memory account) public {
        // create safe transaction to perform the migration
        bytes memory transaction = abi.encodeWithSelector(
            StopPolicyMigration.upgrade.selector
        );

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signDelegateTransaction(
            address(account.safe),
            account.privateKey,
            address(migration),
            transaction
        );

        // impersonate the safe owner
        vm.prank(account.addr);

        // Expect the transaction to succeed
        SafeUtils.executeDelegateTransaction(
            address(account.safe),
            address(migration),
            transaction,
            transactionSignature
        );
    }

    function test_Success_StopRent_NewStopPolicy() public {
        // bob migrates the rental wallet
        _performMigration(bob);

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
        newStopPolicy.stopRent(rentalOrder);

        // assert that the new method on the stop policy can be called
        assertEq(newStopPolicy.upgradeSuccess(), true);
    }

    function test_Reverts_StopRent_OldStopPolicy() public {
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

        // Expect revert because the old stop policy is no longer authorized
        // to access the storage modules of the protocol
        vm.prank(alice.addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Module_PolicyNotAuthorized.selector,
                address(stop)
            )
        );
        stop.stopRent(rentalOrder);
    }
}
