// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {RentalId} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {RentalAssetUpdate} from "@src/libraries/RentalUtils.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";

contract Proxy_Storage_Unit_Test is BaseTestWithoutEngine {
    bytes32 constant RENTAL_ORDER_HASH = keccak256(abi.encode("someRentalOrderHash"));

    function test_Success_ImplementationDiffersFromProxy() public {
        // assert that the address of the proxy is not the same as the
        // implementation contract
        assertTrue(address(STORE) != address(storageImplementation));
    }

    function test_Success_KernelAddressIsCorrect() public {
        // assert that the kernel address is 0 on the implementation contract
        assertEq(address(storageImplementation.kernel()), address(0));

        // assert that the kernel address is not zero on the proxy contract
        assertEq(address(STORE.kernel()), address(kernel));
    }

    function test_Reverts_ModuleProxyInstantiation() public {
        // expect revert because the module proxy cannot be instantiated twice
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_AlreadyInitialized.selector));
        STORE.MODULE_PROXY_INSTANTIATION(kernel);
    }

    function test_Reverts_ModuleProxyInstantiation_NotByProxy() public {
        // expect revert because the module proxy cannot be instantiated twice
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.MODULE_PROXY_INSTANTIATION(kernel);
    }

    function test_Reverts_AddRentals_NotByProxy() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(RentalId.wrap(bytes32(uint256(0))), 1);

        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.addRentals(RENTAL_ORDER_HASH, rentalAssets);
    }

    function test_Reverts_RemoveRentals_NotByProxy() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);

        // populate the array
        rentalAssets[0] = RentalAssetUpdate(RentalId.wrap(bytes32(uint256(0))), 1);

        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.removeRentals(RENTAL_ORDER_HASH, rentalAssets);
    }

    function test_Reverts_RemoveRentalsBatch_NotByProxy() public {
        // Create a rental asset array
        RentalAssetUpdate[] memory rentalAssetsCombined = new RentalAssetUpdate[](2);

        // populate the comnbined array
        rentalAssetsCombined[0] = RentalAssetUpdate(
            RentalId.wrap(bytes32(uint256(0))),
            1
        );
        rentalAssetsCombined[1] = RentalAssetUpdate(
            RentalId.wrap(bytes32(uint256(1))),
            1
        );

        // Create a rental order hash array
        bytes32[] memory rentalOrderHashes = new bytes32[](2);
        rentalOrderHashes[0] = RENTAL_ORDER_HASH;
        rentalOrderHashes[1] = keccak256(abi.encode("someOtherRentalOrderHash"));

        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.removeRentalsBatch(rentalOrderHashes, rentalAssetsCombined);
    }

    function test_Reverts_AddRentalSafe_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.addRentalSafe(TEST_ADDR_1);
    }

    function test_Reverts_UpdateHookPath_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.updateHookPath(address(0), address(0));
    }

    function test_Reverts_UpdateHookStatus_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.updateHookStatus(address(0), uint8(0));
    }

    function test_Reverts_ToggleWhitelistDelegate_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.toggleWhitelistDelegate(TEST_ADDR_1, true);
    }

    function test_Reverts_ToggleWhitelistExtension_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.toggleWhitelistExtension(TEST_ADDR_1, uint8(3));
    }

    function test_Reverts_ToggleWhitelistAsset_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.toggleWhitelistAsset(TEST_ADDR_1, uint8(3));
    }

    function test_Reverts_ToggleWhitelistAssetBatch_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.toggleWhitelistAssetBatch(new address[](0), new uint8[](0));
    }

    function test_Reverts_ToggleWhitelistPayment_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.toggleWhitelistPayment(TEST_ADDR_1, true);
    }

    function test_Reverts_ToggleWhitelistPaymentBatch_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.toggleWhitelistPaymentBatch(
            new address[](0),
            new bool[](0)
        );
    }

    function test_Reverts_Upgrade_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.upgrade(address(0));
    }

    function test_Reverts_Freeze_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.freeze();
    }

    function test_Reverts_SetMaxRentDuration_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.setMaxRentDuration(21 days);
    }

    function test_Reverts_SetMaxOfferItems_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.setMaxOfferItems(15);
    }

    function test_Reverts_SetMaxConsiderationItems_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.setMaxConsiderationItems(15);
    }

    function test_Reverts_setGuardEmergencyUpgrade_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        storageImplementation.setGuardEmergencyUpgrade(address(this));
    }
}
