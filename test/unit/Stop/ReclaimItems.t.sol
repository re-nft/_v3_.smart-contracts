// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {
    OrderMetadata,
    OrderType,
    Hook,
    RentalOrder,
    Item,
    ItemType,
    SettleTo
} from "@src/libraries/RentalStructs.sol";
import {Actions} from "@src/Kernel.sol";
import {ISafe} from "@src/interfaces/ISafe.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {StopHarness} from "@test/mocks/harnesses/StopHarness.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";
import {
    MockAlwaysRevertERC721
} from "@test/mocks/tokens/weird/MockAlwaysRevertERC721.sol";

// Tests functionality on the stop policy related to reclaiming items from a rental wallet
contract Stop_ReclaimItems_Unit_Test is BaseTestWithoutEngine {
    // Stop Policy Harness contract
    StopHarness public stopHarness;

    function setUp() public override {
        super.setUp();

        // set up a stop policy contract that exposes the internal functions
        stopHarness = new StopHarness(kernel);

        // impersonate the deployer which is the kernel admin
        vm.startPrank(deployer.addr);

        // enable the stop policy harness
        kernel.executeAction(Actions.ActivatePolicy, address(stopHarness));

        // enable the stop policy harness as a module. This is so the stop policy
        // harness can be added to a rental safe.
        admin.toggleWhitelistExtension(address(stopHarness), uint8(2));

        // stop impersonating
        vm.stopPrank();

        // add the module to alice's safe
        _enableStopHarnessModuleOnSafe();
    }

    function _enableStopHarnessModuleOnSafe() public {
        // create safe transaction for enabling a module
        bytes memory transaction = abi.encodeWithSelector(
            ISafe.enableModule.selector,
            address(stopHarness)
        );

        // sign the safe transaction
        bytes memory transactionSignature = SafeUtils.signTransaction(
            address(alice.safe),
            alice.privateKey,
            address(alice.safe),
            transaction
        );

        // impersonate the safe owner
        vm.prank(alice.addr);

        // Execute the transaction on Alice's safe
        SafeUtils.executeTransaction(
            address(alice.safe),
            address(alice.safe),
            transaction,
            transactionSignature
        );
    }

    function test_Success_ReclaimItems() public {
        // mint tokens to the rental wallet
        erc721s[0].mint(address(alice.safe));
        erc721s[1].mint(address(alice.safe));

        // Create the items
        Item[] memory items = new Item[](2);
        items[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });
        items[1] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[1]),
            amount: 1,
            identifier: 0
        });

        // Create a mock rental order
        RentalOrder memory order = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("seaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.BASE,
            lender: bob.addr,
            renter: alice.addr,
            rentalWallet: address(alice.safe),
            startTimestamp: 10,
            endTimestamp: 11
        });

        // reclaim the items
        stopHarness.reclaimRentedItems(order);

        // assert the tokens were returned
        assertEq(erc721s[0].ownerOf(0), bob.addr);
        assertEq(erc721s[1].ownerOf(0), bob.addr);
    }

    function test_Reverts_ReclaimItems_TransferFailed() public {
        // deploy a mock ERC721 which will always revert on transfer
        MockAlwaysRevertERC721 revertToken = new MockAlwaysRevertERC721();

        // mint tokens to the rental wallet
        revertToken.mint(address(alice.safe));

        // Create the items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(revertToken),
            amount: 1,
            identifier: 0
        });

        // Create a mock rental order
        RentalOrder memory order = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("seaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.BASE,
            lender: bob.addr,
            renter: alice.addr,
            rentalWallet: address(alice.safe),
            startTimestamp: 10,
            endTimestamp: 11
        });

        // Expect revert because the reclaim was not successful
        vm.expectRevert(abi.encodeWithSelector(Errors.StopPolicy_ReclaimFailed.selector));
        stopHarness.reclaimRentedItems(order);
    }
}
