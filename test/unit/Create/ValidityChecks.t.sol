// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {OrderMetadata, OrderType, Hook} from "@src/libraries/RentalStructs.sol";
import {Actions} from "@src/Kernel.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {CreateHarness} from "@test/mocks/harnesses/CreateHarness.sol";

// Tests functionality on the create policy related to order validity
contract Create_ValidityChecks_Unit_Test is BaseTestWithoutEngine {
    // Create Policy Harness contract
    CreateHarness public createHarness;

    function setUp() public override {
        super.setUp();

        // set up a create policy contract that exposes the internal functions
        createHarness = new CreateHarness(kernel);

        // impersonate the deployer which is the kernel admin
        vm.prank(deployer.addr);

        // enable the create policy harness
        kernel.executeAction(Actions.ActivatePolicy, address(createHarness));
    }

    function test_Success_IsValidSafeOwner() public view {
        // check for a valid safe owner
        createHarness.isValidSafeOwner(alice.addr, address(alice.safe));
    }

    function test_Reverts_IsValidSafeOwner_InvalidRentalSafe() public {
        // Expect revert because the safe was not deployed by the protocol
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_InvalidRentalSafe.selector,
                TEST_ADDR_1
            )
        );
        createHarness.isValidSafeOwner(alice.addr, TEST_ADDR_1);
    }

    function test_Reverts_IsValidSafeOwner_InvalidSafeOwner() public {
        // Expect revert because the owner does not own the rental safe
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_InvalidSafeOwner.selector,
                alice.addr,
                address(bob.safe)
            )
        );
        createHarness.isValidSafeOwner(alice.addr, address(bob.safe));
    }

    function test_Success_IsValidOrderMetadata() public view {
        // create order metadata
        OrderMetadata memory metadata = OrderMetadata({
            orderType: OrderType.BASE,
            rentDuration: 1,
            hooks: new Hook[](0),
            emittedExtraData: bytes("")
        });

        // create metadata hash
        bytes32 metadataHash = createHarness.getOrderMetadataHash(metadata);

        // check for a valid order metadata
        createHarness.isValidOrderMetadata(metadata, metadataHash);
    }

    function test_Reverts_IsValidOrderMetadata_RentDurationZero() public {
        // create order metadata with a rent duration of 0
        OrderMetadata memory metadata = OrderMetadata({
            orderType: OrderType.BASE,
            rentDuration: 0,
            hooks: new Hook[](0),
            emittedExtraData: bytes("")
        });

        // create metadata hash
        bytes32 metadataHash = createHarness.getOrderMetadataHash(metadata);

        // Expect revert because the rent duration is 0
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_RentDurationZero.selector)
        );
        createHarness.isValidOrderMetadata(metadata, metadataHash);
    }

    function test_Reverts_IsValidOrderMetadata_InvalidOrderMetadataHash() public {
        // create order metadata
        OrderMetadata memory metadata = OrderMetadata({
            orderType: OrderType.BASE,
            rentDuration: 1,
            hooks: new Hook[](0),
            emittedExtraData: bytes("")
        });

        // create an invalid metadata hash
        bytes32 invalidMetadataHash = keccak256(abi.encode("invalidMetadataHash"));

        // Expect revert because the metadata hash is invalid
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_InvalidOrderMetadataHash.selector)
        );
        createHarness.isValidOrderMetadata(metadata, invalidMetadataHash);
    }
}
