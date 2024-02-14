// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Order} from "@seaport-types/lib/ConsiderationStructs.sol";
import {StorageAccessible} from "@safe-contracts/common/StorageAccessible.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {
    Actions,
    OrderType,
    OrderMetadata,
    RentalOrder
} from "@src/libraries/RentalStructs.sol";
import {
    GuardUpgrade,
    GuardPolicyMigration
} from "@src/examples/upgrades/GuardPolicyUpgrade.sol";

import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract GuardPolicyUpgrade_Upgradeability_Integration_Test is BaseTest {
    // The new policy to upgrade to
    GuardUpgrade newGuardPolicy;

    // The migration contract
    GuardPolicyMigration migration;

    function setUp() public override {
        super.setUp();

        // deploy the new stop policy
        newGuardPolicy = new GuardUpgrade(kernel);

        // deploy the migration contract
        migration = new GuardPolicyMigration(address(newGuardPolicy));

        // impersonate the deployer which is the kernel admin
        vm.startPrank(deployer.addr);

        // enable the new stop policy
        kernel.executeAction(Actions.ActivatePolicy, address(newGuardPolicy));

        // enable the migration contract to be delegate called by rental safes
        admin.toggleWhitelistDelegate(address(migration), true);

        // stop impersonating
        vm.stopPrank();
    }

    function _performMigration(ProtocolAccount memory account) public {
        // create safe transaction to perform the migration
        bytes memory transaction = abi.encodeWithSelector(
            GuardPolicyMigration.upgrade.selector
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

    function getGuard(address safe) public view returns (address) {
        // The guard storage slot in the safe
        bytes32 guardStorageSlot = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

        // get the return data
        bytes memory returnData = StorageAccessible(safe).getStorageAt(
            uint256(guardStorageSlot),
            1
        );

        return abi.decode(returnData, (address));
    }

    function test_Success_GuardTransaction_NewGuardPolicy() public {
        // bob migrates the rental wallet
        _performMigration(bob);

        // get the guard contract on the safe
        address guard = getGuard(address(bob.safe));

        // assert that the guard set on the wallet is the new guard policy
        assertEq(guard, address(newGuardPolicy));

        // assert that the new method on the guard policy can be called
        assertEq(newGuardPolicy.upgradeSuccess(), true);
    }
}
