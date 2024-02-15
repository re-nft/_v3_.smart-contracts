// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    SpentItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Hook} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Actions} from "@src/Kernel.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {CreateHarness} from "@test/mocks/harnesses/CreateHarness.sol";
import {
    MockHook_Success,
    MockHook_OnStartRevert,
    MockHook_OnStartRequire,
    MockHook_OnStartPanic,
    MockHookErrors
} from "@test/mocks/MockHook.sol";
import {MockTarget} from "@test/mocks/MockTarget.sol";

// Tests functionality on the create policy related to adding hooks
contract Create_AddHooks_Unit_Test is BaseTestWithoutEngine {
    // Create Policy Harness contract
    CreateHarness public createHarness;

    // Mock hook contracts
    MockHook_Success public mockHook;
    MockHook_OnStartRevert public mockHookRevert;
    MockHook_OnStartRequire public mockHookRequire;
    MockHook_OnStartPanic public mockHookPanic;

    // Mock target contract that a hook will be placed between
    MockTarget public mockTarget;

    function setUp() public override {
        super.setUp();

        // deploy mock hook contracts
        mockHook = new MockHook_Success();
        mockHookRevert = new MockHook_OnStartRevert();
        mockHookRequire = new MockHook_OnStartRequire();
        mockHookPanic = new MockHook_OnStartPanic();

        // set up a mock target contract
        mockTarget = new MockTarget();

        // set up a create policy contract that exposes the internal functions
        createHarness = new CreateHarness(kernel);

        // impersonate the deployer which is the kernel admin
        vm.prank(deployer.addr);

        // enable the create policy harness
        kernel.executeAction(Actions.ActivatePolicy, address(createHarness));
    }

    // enables a hook on a target contract
    function _enableHook(address to, address hook) private {
        // impersonate an address with permissions
        vm.startPrank(deployer.addr);

        // update the hook path
        guard.updateHookPath(to, hook);

        // enable the `onStart` hook
        guard.updateHookStatus(hook, uint8(2));

        // stop impersonating
        vm.stopPrank();
    }

    function test_Success_AddHooks() public {
        // enable the hook
        _enableHook(address(mockTarget), address(mockHook));

        // create the offer items
        SpentItem[] memory offerItems = new SpentItem[](1);
        offerItems[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({target: address(mockHook), itemIndex: 0, extraData: bytes("")});

        // link the offer items to the hooks
        createHarness.addHooks(hooks, offerItems, address(alice.safe));

        // assert that the hook was called
        assertEq(mockHook.entryAdded(), true);
    }

    function test_Success_AddHooks_Skipped() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // update the hook path but dont enable it
        guard.updateHookPath(address(mockTarget), address(mockHook));

        // create the offer items
        SpentItem[] memory offerItems = new SpentItem[](1);
        offerItems[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({target: address(mockHook), itemIndex: 0, extraData: bytes("")});

        // Expect the call to succeed since the hook call is skipped
        createHarness.addHooks(hooks, offerItems, address(alice.safe));

        // assert that the hook was not called
        assertEq(mockHook.entryAdded(), false);
    }

    function test_Reverts_AddHooks_NonRentalHookItem() public {
        // enable the hook
        _enableHook(address(mockTarget), address(mockHook));

        // create the offer items, but make it an ERC20
        SpentItem[] memory offerItems = new SpentItem[](1);
        offerItems[0] = SpentItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1
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
        createHarness.addHooks(hooks, offerItems, address(alice.safe));
    }

    function test_Reverts_AddHooks_RevertFailure() public {
        // enable the hook that will cause a revert in `addEntry`
        _enableHook(address(mockTarget), address(mockHookRevert));

        // create the offer items
        SpentItem[] memory offerItems = new SpentItem[](1);
        offerItems[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            target: address(mockHookRevert),
            itemIndex: 0,
            extraData: bytes("")
        });

        // Expect revert because the `onStart` function on the hook reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailBytes.selector,
                abi.encodeWithSelector(MockHookErrors.OnStartRevert.selector)
            )
        );
        createHarness.addHooks(hooks, offerItems, address(alice.safe));
    }

    function test_Reverts_AddHooks_RequireFailure() public {
        // enable the hook which will cause a failed `require`
        _enableHook(address(mockTarget), address(mockHookRequire));

        // create the offer items
        SpentItem[] memory offerItems = new SpentItem[](1);
        offerItems[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            target: address(mockHookRequire),
            itemIndex: 0,
            extraData: bytes("")
        });

        // Expect revert because the `onStart` function on the hook has a failed `require`
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "OnStartRequire"
            )
        );
        createHarness.addHooks(hooks, offerItems, address(alice.safe));
    }

    function test_Reverts_AddHooks_PanicFailure() public {
        // enable the hook which will cause a panic
        _enableHook(address(mockTarget), address(mockHookPanic));

        // create the offer items
        SpentItem[] memory offerItems = new SpentItem[](1);
        offerItems[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // create the hooks
        Hook[] memory hooks = new Hook[](1);
        hooks[0] = Hook({
            target: address(mockHookPanic),
            itemIndex: 0,
            extraData: bytes("")
        });

        // Expect revert because the `onStart` function on the hook will cause a panic
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "Hook reverted: Panic code 17"
            )
        );
        createHarness.addHooks(hooks, offerItems, address(alice.safe));
    }
}
