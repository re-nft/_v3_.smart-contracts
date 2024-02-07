// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Hook, Item, ItemType, SettleTo} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Actions} from "@src/Kernel.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {StopHarness} from "@test/mocks/harnesses/StopHarness.sol";
import {
    MockHook_Success,
    MockHook_OnStopRevert,
    MockHook_OnStopRequire,
    MockHook_OnStopPanic,
    MockHookErrors
} from "@test/mocks/MockHook.sol";
import {MockTarget} from "@test/mocks/MockTarget.sol";

// Tests functionality on the stop policy related to removing hooks
contract Stop_RemoveHooks_Unit_Test is BaseTestWithoutEngine {
    // Stop Policy Harness contract
    StopHarness public stopHarness;

    // Mock hook contracts
    MockHook_Success public mockHook;
    MockHook_OnStopRevert public mockHookRevert;
    MockHook_OnStopRequire public mockHookRequire;
    MockHook_OnStopPanic public mockHookPanic;

    // Mock target contract that a hook will be placed between
    MockTarget public mockTarget;

    function setUp() public override {
        super.setUp();

        // deploy mock hook contracts
        mockHook = new MockHook_Success();
        mockHookRevert = new MockHook_OnStopRevert();
        mockHookRequire = new MockHook_OnStopRequire();
        mockHookPanic = new MockHook_OnStopPanic();

        // set up a mock target contract
        mockTarget = new MockTarget();

        // set up a stop policy contract that exposes the internal functions
        stopHarness = new StopHarness(kernel);

        // impersonate the deployer which is the kernel admin
        vm.prank(deployer.addr);

        // enable the stop policy harness
        kernel.executeAction(Actions.ActivatePolicy, address(stopHarness));
    }

    // enables a hook on a target contract
    function _enableHook(address to, address hook) private {
        // impersonate an address with permissions
        vm.startPrank(deployer.addr);

        // update the hook path
        guard.updateHookPath(to, hook);

        // enable the `onStop` hook
        guard.updateHookStatus(hook, uint8(4));

        // stop impersonating
        vm.stopPrank();
    }

    function test_Success_RemoveHooks() public {
        // enable the hook
        _enableHook(address(mockTarget), address(mockHook));

        // create the rental items
        Item[] memory rentalItems = new Item[](1);
        rentalItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({target: address(mockHook), itemIndex: 0, extraData: bytes("")});

        // unlink the offer items from the hook
        stopHarness.removeHooks(hooks, rentalItems, address(alice.safe));

        // assert that the hook was called
        assertEq(mockHook.entryRemoved(), true);
    }

    function test_Success_RemoveHooks_Skipped() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // update the hook path but dont enable it for onStop
        guard.updateHookPath(address(mockTarget), address(mockHook));

        // create the rental items
        Item[] memory rentalItems = new Item[](1);
        rentalItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({target: address(mockHook), itemIndex: 0, extraData: bytes("")});

        // Expect the call to succeed since the hook call is skipped
        stopHarness.removeHooks(hooks, rentalItems, address(alice.safe));

        // assert that the hook was not called
        assertEq(mockHook.entryRemoved(), false);
    }

    function test_Reverts_RemoveHooks_NonRentalHookItem() public {
        // enable the hook
        _enableHook(address(mockTarget), address(mockHook));

        // create the rental items
        Item[] memory rentalItems = new Item[](1);
        rentalItems[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.RENTER,
            token: address(erc20s[0]),
            amount: 1,
            identifier: 0
        });
        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({target: address(mockHook), itemIndex: 0, extraData: bytes("")});

        // Expect revert because the offer item cannot have a hook linked to it
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_NonRentalHookItem.selector,
                hooks[0].itemIndex
            )
        );
        stopHarness.removeHooks(hooks, rentalItems, address(alice.safe));
    }

    function test_Reverts_RemoveHooks_RevertFailure() public {
        // enable the hook that will cause a revert in `addEntry`
        _enableHook(address(mockTarget), address(mockHookRevert));

        // create the rental items
        Item[] memory rentalItems = new Item[](1);
        rentalItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            target: address(mockHookRevert),
            itemIndex: 0,
            extraData: bytes("")
        });

        // Expect revert because the `onStop` function on the hook reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailBytes.selector,
                abi.encodeWithSelector(MockHookErrors.OnStopRevert.selector)
            )
        );
        stopHarness.removeHooks(hooks, rentalItems, address(alice.safe));
    }

    function test_Reverts_RemoveHooks_RequireFailure() public {
        // enable the hook which will cause a failed `require`
        _enableHook(address(mockTarget), address(mockHookRequire));

        // create the rental items
        Item[] memory rentalItems = new Item[](1);
        rentalItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            target: address(mockHookRequire),
            itemIndex: 0,
            extraData: bytes("")
        });

        // Expect revert because the `onStop` function on the hook has a failed `require`
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Shared_HookFailString.selector, "OnStopRequire")
        );
        stopHarness.removeHooks(hooks, rentalItems, address(alice.safe));
    }

    function test_Reverts_RemoveHooks_PanicFailure() public {
        // enable the hook which will cause a panic
        _enableHook(address(mockTarget), address(mockHookPanic));

        // create the rental items
        Item[] memory rentalItems = new Item[](1);
        rentalItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            target: address(mockHookPanic),
            itemIndex: 0,
            extraData: bytes("")
        });

        // Expect revert because the `onStop` function on the hook will cause a panic
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "Hook reverted: Panic code 17"
            )
        );
        stopHarness.removeHooks(hooks, rentalItems, address(alice.safe));
    }
}
