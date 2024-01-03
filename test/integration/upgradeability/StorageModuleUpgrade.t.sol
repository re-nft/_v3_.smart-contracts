// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {Actions} from "@src/libraries/RentalStructs.sol";
import {StorageUpgrade} from "@src/examples/upgrades/StorageModuleUpgrade.sol";
import {Storage} from "@src/modules/Storage.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {MismatchUUID} from "@test/mocks/proxies/MismatchUUID.sol";

contract StorageModuleUpgrade_Upgradeability_Integration_Test is BaseTest {
    // Deploys the new storage upgrade implementation contract
    function _deployStorageUpgradeImplementation() internal {
        // abi encode the new storage bytecode and constructor arguments
        // for the implementation contract
        bytes memory storageUpgradeImplementationInitCode = abi.encodePacked(
            type(StorageUpgrade).creationCode,
            abi.encode(address(0))
        );

        // Deploy storage implementation contract
        vm.prank(deployer.addr);
        storageImplementation = Storage(
            create2Deployer.deploy(salt, storageUpgradeImplementationInitCode)
        );
    }

    function test_Success_Upgrade() public {
        // save initial storage contract addresses
        address originalProxy = address(STORE);
        address originalImplementation = address(storageImplementation);

        // assert the initial storage is expected
        assertEq(STORE.totalSafes(), 5);

        // deploy the storage upgrade implementation
        _deployStorageUpgradeImplementation();

        // impersonate the admin
        vm.prank(deployer.addr);

        // use the admin policy to upgrade the storage module
        admin.upgradeStorage(address(storageImplementation));

        // assert the proxy address has remained the same
        assertEq(address(STORE), originalProxy);

        // assert the implementation address has changed
        assertFalse(address(storageImplementation) == originalImplementation);

        // assert the initial storage is unchanged
        assertEq(STORE.totalSafes(), 5);

        // assert the new functionality can be accessed
        assertEq(StorageUpgrade(address(STORE)).upgradeSuccess(), true);
    }

    function test_Reverts_Upgrade_IncompatibleContract_IsNotUUPSCompliant() public {
        // impersonate the admin
        vm.prank(deployer.addr);

        // expect revert because an upgrade was attempted with an incompatible contract
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Proxy_NotCompatible.selector, address(this))
        );
        admin.upgradeStorage(address(this));
    }

    function test_Reverts_Upgrade_IncompatibleContract_UUIDMismatch() public {
        // deploy the mock proxiable contract
        MismatchUUID mismatchUUID = new MismatchUUID();

        // impersonate the admin
        vm.prank(deployer.addr);

        // expect revert because an upgrade was attempted with an incompatible contract
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Proxy_NotCompatible.selector,
                address(mismatchUUID)
            )
        );
        admin.upgradeStorage(address(mismatchUUID));
    }

    function test_Success_Freeze() public {
        // impersonate the admin
        vm.prank(deployer.addr);

        // use the admin policy to freeze the storage module
        admin.freezeStorage();

        // deploy the storage upgrade implementation
        _deployStorageUpgradeImplementation();

        // impersonate the admin
        vm.prank(deployer.addr);

        // expect revert because a frozen contract can not be upgraded
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_Frozen.selector));
        admin.upgradeStorage(address(storageImplementation));
    }
}
