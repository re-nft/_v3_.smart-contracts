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
    FallbackUpgrade,
    FallbackPolicyMigration
} from "@src/examples/upgrades/FallbackPolicyUpgrade.sol";

import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract FallbackPolicyUpgrade_Upgradeability_Integration_Test is BaseTest {
    // The new policy to upgrade to
    FallbackUpgrade newFallbackPolicy;

    // The migration contract
    FallbackPolicyMigration migration;

    function setUp() public override {
        super.setUp();

        // deploy the new fallback policy
        newFallbackPolicy = new FallbackUpgrade(kernel);

        // deploy the migration contract
        migration = new FallbackPolicyMigration(address(newFallbackPolicy));

        // impersonate the deployer which is the kernel admin
        vm.startPrank(deployer.addr);

        // enable the new fallback policy
        kernel.executeAction(Actions.ActivatePolicy, address(newFallbackPolicy));

        // enable the migration contract to be delegate called by rental safes
        admin.toggleWhitelistDelegate(address(migration), true);

        // stop impersonating
        vm.stopPrank();
    }

	// Demonstrate that the fallback handler can be opt-in upgraded on a wallet via the 
	// use of a whitelisted delegate call contract. 
    function test_Success_FallbackTransaction_NewFallbackPolicy() public {
        // bob migrates the rental wallet
        _performMigration(bob);

        // get the fallback contract on the safe
        address fallbackAddress = _getFallback(address(bob.safe));

        // assert that the fallback set on the wallet is the new fallback policy
        assertEq(fallbackAddress, address(newFallbackPolicy));

        // assert that the new method on the fallback policy can be called
        assertEq(newFallbackPolicy.upgradeSuccess(), true);
    }

    function _performMigration(ProtocolAccount memory account) internal {
        // create safe transaction to perform the migration
        bytes memory transaction = abi.encodeWithSelector(
            FallbackPolicyMigration.upgrade.selector
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

    function _getFallback(address safe) internal view returns (address) {
        // The fallback storage slot in the safe
        bytes32 fallbackStorageSlot = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

        // get the return data
        bytes memory returnData = StorageAccessible(safe).getStorageAt(
            uint256(fallbackStorageSlot),
            1
        );

        return abi.decode(returnData, (address));
    }
}
