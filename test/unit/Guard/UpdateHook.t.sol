// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {toRole} from "@src/libraries/KernelUtils.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {MockHook_Success} from "@test/mocks/MockHook.sol";
import {MockTarget} from "@test/mocks/MockTarget.sol";

// Test the functionality on the Guard related to updating hook paths and statuses
contract Guard_UpdateHook_Unit_Test is BaseTestWithoutEngine {
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

    function test_Sucesss_UpdateHookStatus() public {
        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // update the hook status to 0x00000101 which enables `onTransaction` and `onStop` hooks
        guard.updateHookStatus(address(mockHook), uint8(5));

        // assert that the status has changed
        assertEq(STORE.hookStatus(address(mockHook)), uint8(5));

        // assert that the `onTransaction` hook is enabled
        assertEq(STORE.hookOnTransaction(address(mockHook)), true);

        // assert that the `onStop` hook is enabled
        assertEq(STORE.hookOnStop(address(mockHook)), true);

        // assert that the `onStart` hook is disabled
        assertEq(STORE.hookOnStart(address(mockHook)), false);
    }

    function test_Reverts_UpdateHookStatus_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // expect revert because the caller is not an admin for the guard policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("GUARD_ADMIN"))
        );
        guard.updateHookStatus(address(mockHook), uint8(5));
    }

    function test_Sucesss_UpdateHookPath_StatusSet() public {
        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // create a path from the hook to the target
        guard.updateHookPath(address(mockTarget), address(mockHook));

        // enable the hook
        guard.updateHookStatus(address(mockHook), uint8(5));

        // stop impersonating
        vm.stopPrank();

        // assert the path exists
        assertEq(STORE.contractToHook(address(mockTarget)), address(mockHook));
    }

    function test_Success_UpdateHookPath_StatusNotSet() public {
        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // create a path from the hook to the target
        guard.updateHookPath(address(mockTarget), address(mockHook));

        // assert the path doesnt exist because the status
        // of the hook has not changed
        assertEq(STORE.contractToHook(address(mockTarget)), ZERO_ADDRESS);
    }

    function test_Reverts_UpdateHookPath_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // expect revert because the caller is not an admin for the guard policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("GUARD_ADMIN"))
        );
        guard.updateHookPath(address(mockTarget), address(mockHook));
    }
}
