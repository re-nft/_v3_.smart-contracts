// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {OrderType, OrderMetadata, RentalOrder} from "@src/libraries/RentalStructs.sol";
import {Actions, Kernel, KernelAdapter} from "@src/Kernel.sol";
import {toRole} from "@src/libraries/KernelUtils.sol";

import {BaseTest} from "@test/BaseTest.sol";

contract KernelUpgrade_Upgradeability_Integration_Test is BaseTest {
    // The new kernel to upgrade to
    Kernel newKernel;

    function setUp() public override {
        super.setUp();

        // impersonate the deployer which is the kernel admin
        vm.startPrank(deployer.addr);

        // deploy the new kernel
        newKernel = new Kernel(deployer.addr, deployer.addr);

        // migrate from the old kernel to the new kernel. This permanently bricks the
        // old kernel
        kernel.executeAction(Actions.MigrateKernel, address(newKernel));

        // Install modules on the new kernel
        newKernel.executeAction(Actions.InstallModule, address(STORE));
        newKernel.executeAction(Actions.InstallModule, address(ESCRW));

        // Approve policies on the new kernel
        newKernel.executeAction(Actions.ActivatePolicy, address(create));
        newKernel.executeAction(Actions.ActivatePolicy, address(stop));
        newKernel.executeAction(Actions.ActivatePolicy, address(factory));
        newKernel.executeAction(Actions.ActivatePolicy, address(guard));
        newKernel.executeAction(Actions.ActivatePolicy, address(admin));

        // Grant `seaport` role to seaport protocol
        newKernel.grantRole(toRole("SEAPORT"), address(seaport));

        // Grant `signer` role to the protocol signer to sign off on create payloads
        newKernel.grantRole(toRole("CREATE_SIGNER"), rentalSigner.addr);

        // Grant 'admin_admin` role to the address which can conduct admin operations on the protocol
        newKernel.grantRole(toRole("ADMIN_ADMIN"), deployer.addr);

        // Grant 'guard_admin` role to the address which can toggle hooks
        newKernel.grantRole(toRole("GUARD_ADMIN"), deployer.addr);

        // Grant `stop_admin` role to the address which can skim funds from the payment escrow
        newKernel.grantRole(toRole("STOP_ADMIN"), deployer.addr);

        // stop impersonating
        vm.stopPrank();
    }

    function test_Success_MigrateKernel() public {
        // assert all modules are using the new kernel
        assertEq(address(KernelAdapter(address(STORE)).kernel()), address(newKernel));
        assertEq(address(KernelAdapter(address(ESCRW)).kernel()), address(newKernel));

        // assert all policies are using the new kernel
        assertEq(address(KernelAdapter(address(create)).kernel()), address(newKernel));
        assertEq(address(KernelAdapter(address(stop)).kernel()), address(newKernel));
        assertEq(address(KernelAdapter(address(factory)).kernel()), address(newKernel));
        assertEq(address(KernelAdapter(address(guard)).kernel()), address(newKernel));
        assertEq(address(KernelAdapter(address(admin)).kernel()), address(newKernel));
    }

    function test_Success_RentWorksProperlyAfterMigration() public {
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
    }
}
