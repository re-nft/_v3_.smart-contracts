// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {RentalId} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {RentalUtils, RentalAssetUpdate} from "@src/libraries/RentalUtils.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {MockHook_Success} from "@test/mocks/MockHook.sol";
import {MockTarget} from "@test/mocks/MockTarget.sol";

contract Storage_Unit_Test is BaseTestWithoutEngine {
    bytes32 constant RENTAL_ORDER_HASH = keccak256(abi.encode("someRentalOrderHash"));

    // Mock hook contract that successfully executes
    MockHook_Success public mockHook;

    // Mock target contract that a hook will be placed between
    MockTarget public mockTarget;

    function setUp() public override {
        super.setUp();

        // deploy a mock hook contract
        mockHook = new MockHook_Success();

        // set up a mock target contract
        mockTarget = new MockTarget();
    }

    function test_Success_AddRentals() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // create the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(rentalId, 1);

        // mark rental asset as active
        vm.prank(address(create));
        STORE.addRentals(RENTAL_ORDER_HASH, rentalAssets);

        // assert that the rental order is in storage
        assertEq(STORE.orders(RENTAL_ORDER_HASH), true);

        // assert that the rental ID is in storage
        assertEq(STORE.rentedAssets(rentalAssets[0].rentalId), rentalAssets[0].amount);

        // assert that the item is rented out
        assertGt(STORE.isRentedOut(address(alice.safe), address(erc721s[0]), 0), 0);
    }

    function test_Reverts_AddRentals_NotAdmin() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // create the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(rentalId, 1);

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.addRentals(RENTAL_ORDER_HASH, rentalAssets);
    }

    function test_Success_RemoveRentals() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // create the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(rentalId, 1);

        // impersonate an address with permissions
        vm.prank(address(create));

        // add rentals to storage
        STORE.addRentals(RENTAL_ORDER_HASH, rentalAssets);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // remove rentals from storage
        STORE.removeRentals(RENTAL_ORDER_HASH, rentalAssets);

        // assert that the rental order is not storage
        assertEq(STORE.orders(RENTAL_ORDER_HASH), false);

        // assert that the rental ID is not in storage
        assertEq(STORE.rentedAssets(rentalAssets[0].rentalId), 0);

        // assert that the item is not rented out
        assertEq(STORE.isRentedOut(address(alice.safe), address(erc721s[0]), 0), 0);
    }

    function test_Reverts_RemoveRentals_NoPermissions() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // create the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(rentalId, 1);

        // impersonate an address with permissions
        vm.prank(address(create));

        // add rentals to storage
        STORE.addRentals(RENTAL_ORDER_HASH, rentalAssets);

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.removeRentals(RENTAL_ORDER_HASH, rentalAssets);
    }

    function test_Reverts_RemoveRentals_NonExistentOrderHash() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // create the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(rentalId, 1);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // Expect revert because the order does not exist
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.StorageModule_OrderDoesNotExist.selector,
                RENTAL_ORDER_HASH
            )
        );
        STORE.removeRentals(RENTAL_ORDER_HASH, rentalAssets);
    }

    function test_Success_RemoveRentalsBatch() public {
        // create some rental IDs
        RentalId rentalIdFirst = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );
        RentalId rentalIdSecond = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            1
        );

        // Create a rental asset arrays
        RentalAssetUpdate[] memory rentalAssetsFirstOrder = new RentalAssetUpdate[](1);
        RentalAssetUpdate[] memory rentalAssetsSecondOrder = new RentalAssetUpdate[](1);
        RentalAssetUpdate[] memory rentalAssetsCombined = new RentalAssetUpdate[](2);

        // populate the arrays
        rentalAssetsFirstOrder[0] = RentalAssetUpdate(rentalIdFirst, 1);
        rentalAssetsSecondOrder[0] = RentalAssetUpdate(rentalIdSecond, 1);

        // populate the comnbined array
        rentalAssetsCombined[0] = RentalAssetUpdate(rentalIdFirst, 1);
        rentalAssetsCombined[1] = RentalAssetUpdate(rentalIdSecond, 1);

        // Create a rental order hash array
        bytes32[] memory rentalOrderHashes = new bytes32[](2);
        rentalOrderHashes[0] = RENTAL_ORDER_HASH;
        rentalOrderHashes[1] = keccak256(abi.encode("someOtherRentalOrderHash"));

        // impersonate an address with permissions
        vm.startPrank(address(create));

        // add rentals to storage
        STORE.addRentals(rentalOrderHashes[0], rentalAssetsFirstOrder);
        STORE.addRentals(rentalOrderHashes[1], rentalAssetsSecondOrder);

        // stop impersonating
        vm.stopPrank();

        // impersonate an address with permissions
        vm.prank(address(stop));

        // remove rentals from storage
        STORE.removeRentalsBatch(rentalOrderHashes, rentalAssetsCombined);

        // assert that the rental order is not storage
        for (uint256 i = 0; i < rentalOrderHashes.length; i++) {
            assertEq(STORE.orders(rentalOrderHashes[i]), false);
        }

        // assert that the rental ID is not in storage
        for (uint256 i = 0; i < rentalAssetsCombined.length; i++) {
            assertEq(STORE.rentedAssets(rentalAssetsCombined[i].rentalId), 0);
        }

        // assert that the item is not rented out
        for (uint256 i = 0; i < 2; i++) {
            assertEq(STORE.isRentedOut(address(alice.safe), address(erc721s[0]), i), 0);
        }
    }

    function test_Reverts_RemoveRentalsBatch_NoPermissions() public {
        // create some rental IDs
        RentalId rentalIdFirst = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );
        RentalId rentalIdSecond = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            1
        );

        // Create a rental asset arrays
        RentalAssetUpdate[] memory rentalAssetsFirstOrder = new RentalAssetUpdate[](1);
        RentalAssetUpdate[] memory rentalAssetsSecondOrder = new RentalAssetUpdate[](1);
        RentalAssetUpdate[] memory rentalAssetsCombined = new RentalAssetUpdate[](2);

        // populate the arrays
        rentalAssetsFirstOrder[0] = RentalAssetUpdate(rentalIdFirst, 1);
        rentalAssetsSecondOrder[0] = RentalAssetUpdate(rentalIdSecond, 1);

        // populate the comnbined array
        rentalAssetsCombined[0] = RentalAssetUpdate(rentalIdFirst, 1);
        rentalAssetsCombined[1] = RentalAssetUpdate(rentalIdSecond, 1);

        // Create a rental order hash array
        bytes32[] memory rentalOrderHashes = new bytes32[](2);
        rentalOrderHashes[0] = RENTAL_ORDER_HASH;
        rentalOrderHashes[1] = keccak256(abi.encode("someOtherRentalOrderHash"));

        // impersonate an address with permissions
        vm.startPrank(address(create));

        // add rentals to storage
        STORE.addRentals(rentalOrderHashes[0], rentalAssetsFirstOrder);
        STORE.addRentals(rentalOrderHashes[1], rentalAssetsSecondOrder);

        // stop impersonating
        vm.stopPrank();

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.removeRentalsBatch(rentalOrderHashes, rentalAssetsCombined);
    }

    function test_Reverts_RemoveRentalsBatch_NonExistentOrderHash() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // create the rental ID
        RentalId rentalId = RentalUtils.getItemPointer(
            address(alice.safe),
            address(erc721s[0]),
            0
        );

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(rentalId, 1);

        // Create a rental order hash array
        bytes32[] memory rentalOrderHashes = new bytes32[](1);
        rentalOrderHashes[0] = RENTAL_ORDER_HASH;

        // impersonate an address with permissions
        vm.prank(address(stop));

        // Expect revert because the order does not exist
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.StorageModule_OrderDoesNotExist.selector,
                RENTAL_ORDER_HASH
            )
        );
        STORE.removeRentalsBatch(rentalOrderHashes, rentalAssets);
    }

    function test_Success_AddRentalSafe() public {
        // impersonate an address with permissions
        vm.prank(address(factory));

        // add the rental safe
        STORE.addRentalSafe(TEST_ADDR_1);

        // get the updated total safe count
        uint256 totalSafes = STORE.totalSafes();

        // assert the nonce was incremented
        assertEq(STORE.totalSafes(), totalSafes);

        // assert the safe was assigned the nonce
        assertEq(STORE.deployedSafes(TEST_ADDR_1), totalSafes);
    }

    function test_Reverts_AddRentalSafe_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.addRentalSafe(TEST_ADDR_1);
    }

    function test_Success_UpdateHookPath() public {
        // impersonate an address with permissions
        vm.prank(address(guard));

        // update the hook path by putting it between the caller and the target
        STORE.updateHookPath(address(mockTarget), address(mockHook));

        // assert that the path hasnt updated because the status
        // hasnt changed
        assertEq(STORE.contractToHook(address(mockTarget)), address(0));

        // impersonate an address with permissions
        vm.prank(address(guard));

        // update the hook status to 0x00000101 which enables `onTransaction` and `onStop` hooks
        STORE.updateHookStatus(address(mockHook), uint8(5));

        // assert that the path has updated
        assertEq(STORE.contractToHook(address(mockTarget)), address(mockHook));
    }

    function test_Reverts_UpdateHookPath_ToAddressNotContract() public {
        // impersonate an address with permissions
        vm.prank(address(guard));

        // Expect revert because the `to` address is not a contract
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StorageModule_NotContract.selector, TEST_ADDR_1)
        );
        STORE.updateHookPath(TEST_ADDR_1, address(mockHook));
    }

    function test_Reverts_UpdateHookPath_HookAddressNotContract() public {
        // impersonate an address with permissions
        vm.prank(address(guard));

        // Expect revert because the `hook` address is not a contract
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StorageModule_NotContract.selector, TEST_ADDR_2)
        );
        STORE.updateHookPath(address(mockTarget), TEST_ADDR_2);
    }

    function test_Reverts_UpdateHookPath_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.updateHookPath(TEST_ADDR_1, TEST_ADDR_2);
    }

    function test_Success_UpdateHookStatus() public {
        // impersonate an address with permissions
        vm.prank(address(guard));

        // update the hook status to 0x00000101 which enables `onTransaction` and `onStop` hooks
        STORE.updateHookStatus(address(mockHook), uint8(5));

        // assert that the status has changed
        assertEq(STORE.hookStatus(address(mockHook)), uint8(5));

        // assert that the `onTransaction` hook is enabled
        assertEq(STORE.hookOnTransaction(address(mockHook)), true);

        // assert that the `onStop` hook is enabled
        assertEq(STORE.hookOnStop(address(mockHook)), true);

        // assert that the `onStart` hook is disabled
        assertEq(STORE.hookOnStart(address(mockHook)), false);
    }

    function test_Reverts_UpdateHookStatus_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.updateHookStatus(address(mockHook), uint8(3));
    }

    function test_Reverts_UpdateHookStatus_NotContract() public {
        // impersonate an address with permissions
        vm.prank(address(guard));

        // Expect revert because the hook address is not a contract
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StorageModule_NotContract.selector, address(0))
        );
        STORE.updateHookStatus(address(0), uint8(3));
    }

    function test_Reverts_UpdateHookStatus_InvalidHookStatusBitmap() public {
        // impersonate an address with permissions
        vm.prank(address(guard));

        // Expect revert because the hook bitmap is greater than 0x00000111
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.StorageModule_InvalidHookStatusBitmap.selector,
                uint8(50)
            )
        );
        STORE.updateHookStatus(address(mockHook), uint8(50));
    }

    function test_Success_ToggleWhitelistDelegate() public {
        // impersonate an address with permissions
        vm.prank(address(admin));

        // enable this address to be delegate called by rental safes
        STORE.toggleWhitelistDelegate(TEST_ADDR_1, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedDelegates(TEST_ADDR_1));
    }

    function test_Reverts_ToggleWhitelistDelegate_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.toggleWhitelistDelegate(TEST_ADDR_1, true);
    }

    function test_Success_ToggleWhitelistExtension() public {
        // impersonate an address with permissions
        vm.prank(address(admin));

        // enable this address to be added as a module by rental safes
        STORE.toggleWhitelistExtension(TEST_ADDR_1, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedExtensions(TEST_ADDR_1));
    }

    function test_Reverts_ToggleWhitelistExtension_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.toggleWhitelistExtension(TEST_ADDR_1, true);
    }

    function test_Success_ToggleWhitelistAsset() public {
        // impersonate an address with permissions
        vm.prank(address(admin));

        // enable this address to be used as a rented asset
        STORE.toggleWhitelistAsset(TEST_ADDR_1, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedAssets(TEST_ADDR_1));
    }

    function test_Reverts_ToggleWhitelistAsset_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.toggleWhitelistAsset(TEST_ADDR_1, true);
    }

    function test_Success_ToggleWhitelistPayment() public {
        // impersonate an address with permissions
        vm.prank(address(admin));

        // enable this address to be used as a rented asset
        STORE.toggleWhitelistPayment(TEST_ADDR_1, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedPayments(TEST_ADDR_1));
    }

    function test_Reverts_ToggleWhitelistPayment_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.toggleWhitelistPayment(TEST_ADDR_1, true);
    }

    function test_Success_SetMaxRentDuration() public {
        // impersonate an address with permissions
        vm.prank(address(admin));

        // set the max rent duration
        STORE.setMaxRentDuration(22 days);

        // assert the max rent duration changed
        assertEq(STORE.maxRentDuration(), 22 days);
    }

    function test_Reverts_SetMaxRentDuration_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        STORE.setMaxRentDuration(22 days);
    }
}
