// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISafe} from "@src/interfaces/ISafe.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";
import {MockExtension} from "@test/mocks/MockExtension.sol";

contract GuardedTransactions_Extensions_Integration_Test is BaseTest {
    // Mock extension contract
    MockExtension extension;

    function setUp() public override {
        super.setUp();

        // Deploy the extension contract
        extension = new MockExtension();
    }

    function test_Success_Extension_Enable_NotDisable() public {
        // Allow the extension to be only enabled.
        vm.prank(deployer.addr);
        admin.toggleWhitelistExtension(address(extension), uint8(2));

        // create safe transaction to enable the module
        bytes memory enableTransaction = abi.encodeWithSelector(
            ISafe.enableModule.selector,
            address(extension)
        );

        // sign the safe transaction
        bytes memory enableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            enableTransaction
        );

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction(
            address(alice.safe),
            address(alice.safe),
            enableTransaction,
            enableTransactionSignature
        );

        // assert the module has been enabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), true);

        // create safe transaction to disable the module
        bytes memory disableTransaction = abi.encodeWithSelector(
            ISafe.disableModule.selector,
            address(0x1),
            extension
        );

        // sign the safe transaction
        bytes memory disableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            disableTransaction
        );

        // Expect the transaction to revert because the extension cannot be disabled.
        SafeUtils.executeTransactionWithError(
            address(alice.safe),
            address(alice.safe),
            disableTransaction,
            disableTransactionSignature,
            abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedExtension.selector,
                address(extension)
            )
        );

        // assert the module is still enabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), true);
    }

    function test_Sucess_Extension_Enable_ThenDisableOnly() public {
        // Allow the extension to be freely enabled and disabled.
        vm.prank(deployer.addr);
        admin.toggleWhitelistExtension(address(extension), uint8(3));

        // create safe transaction to enable the module
        bytes memory enableTransaction = abi.encodeWithSelector(
            ISafe.enableModule.selector,
            address(extension)
        );

        // sign the safe transaction
        bytes memory enableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            enableTransaction
        );

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction(
            address(alice.safe),
            address(alice.safe),
            enableTransaction,
            enableTransactionSignature
        );

        // assert the module has been enabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), true);

        // admin decides to make the safe disable-only. So new safes cant enable the module,
        // and old safes can only disable it.
        vm.prank(deployer.addr);
        admin.toggleWhitelistExtension(address(extension), uint8(1));

        // create safe transaction to disable the module
        bytes memory disableTransaction = abi.encodeWithSelector(
            ISafe.disableModule.selector,
            address(0x1),
            extension
        );

        // sign the safe transaction
        bytes memory disableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            disableTransaction
        );

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction(
            address(alice.safe),
            address(alice.safe),
            disableTransaction,
            disableTransactionSignature
        );

        // assert the module has been disabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), false);

        // bob creates safe transaction to enable the module
        bytes memory enableTransactionBob = abi.encodeWithSelector(
            ISafe.enableModule.selector,
            address(extension)
        );

        // sign the safe transaction
        bytes memory enableTransactionSignatureBob = SafeUtils.signTransaction(
            address(bob.safe),
            bob.privateKey,
            address(bob.safe),
            enableTransactionBob
        );

        // Expect the transaction to revert because the extension cannot be enabled.
        SafeUtils.executeTransactionWithError(
            address(bob.safe),
            address(bob.safe),
            enableTransactionBob,
            enableTransactionSignatureBob,
            abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedExtension.selector,
                address(extension)
            )
        );

        // assert the module has not been enabled
        assertEq(bob.safe.isModuleEnabled(address(extension)), false);
    }

    function test_Success_Extension_EnableAndDisable() public {
        // Allow the extension to be freely enabled and disabled.
        vm.prank(deployer.addr);
        admin.toggleWhitelistExtension(address(extension), uint8(3));

        // create safe transaction to enable the module
        bytes memory enableTransaction = abi.encodeWithSelector(
            ISafe.enableModule.selector,
            address(extension)
        );

        // sign the safe transaction
        bytes memory enableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            enableTransaction
        );

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction(
            address(alice.safe),
            address(alice.safe),
            enableTransaction,
            enableTransactionSignature
        );

        // assert the module has been enabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), true);

        // create safe transaction to disable the module
        bytes memory disableTransaction = abi.encodeWithSelector(
            ISafe.disableModule.selector,
            address(0x1),
            extension
        );

        // sign the safe transaction
        bytes memory disableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            disableTransaction
        );

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction(
            address(alice.safe),
            address(alice.safe),
            disableTransaction,
            disableTransactionSignature
        );

        // assert the module has been disabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), false);
    }

    function test_Reverts_Extension_Enable() public {
        // create safe transaction to enable the module that hasnt been whitelisted
        bytes memory enableTransaction = abi.encodeWithSelector(
            ISafe.enableModule.selector,
            address(extension)
        );

        // sign the safe transaction
        bytes memory enableTransactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            enableTransaction
        );

        // Expect the transaction to execute successfully
        SafeUtils.executeTransactionWithError(
            address(alice.safe),
            address(alice.safe),
            enableTransaction,
            enableTransactionSignature,
            abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedExtension.selector,
                address(extension)
            )
        );

        // assert the module has not been enabled
        assertEq(alice.safe.isModuleEnabled(address(extension)), false);
    }
}
