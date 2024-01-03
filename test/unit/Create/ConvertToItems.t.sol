// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    SpentItem,
    ReceivedItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Actions} from "@src/Kernel.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Item, ItemType, SettleTo, OrderType} from "@src/libraries/RentalStructs.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {CreateHarness} from "@test/mocks/harnesses/CreateHarness.sol";

// Tests functionality on the create policy related to converting
// seaport offer and consideration items into rental items
contract Create_ConvertToItems_Unit_Test is BaseTestWithoutEngine {
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

    function test_Success_ConvertToItems_BaseOrder() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Create the expected RentalItem array
        Item[] memory expectedItems = new Item[](2);
        expectedItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });
        expectedItems[1] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.LENDER,
            token: address(erc20s[0]),
            amount: 1,
            identifier: 0
        });

        // convert a BASE order into items
        Item[] memory items = createHarness.convertToItems(
            offer,
            consideration,
            OrderType.BASE
        );

        // assert the Item lengths are the same
        assertEq(items.length, expectedItems.length);

        // assert that each Item is expected
        for (uint256 i = 0; i < items.length; i++) {
            assertEq(items[i], expectedItems[i]);
        }
    }

    function test_Success_ConvertToItems_PayOrder() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](2);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });
        offer[1] = SpentItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1
        });

        // Create the expected RentalItem array
        Item[] memory expectedItems = new Item[](2);
        expectedItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });
        expectedItems[1] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.RENTER,
            token: address(erc20s[0]),
            amount: 1,
            identifier: 0
        });

        // convert a PAY order into items
        Item[] memory items = createHarness.convertToItems(
            offer,
            new ReceivedItem[](0),
            OrderType.PAY
        );

        // assert the Item lengths are the same
        assertEq(items.length, expectedItems.length);

        // assert that each Item is expected
        for (uint256 i = 0; i < items.length; i++) {
            assertEq(items[i], expectedItems[i]);
        }
    }

    function test_Reverts_ConvertToItems_PayOrder_ConsiderationCountNotZero() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](2);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });
        offer[1] = SpentItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1
        });

        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Expect revert because consideration items were provided
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_ConsiderationCountNonZero.selector,
                consideration.length
            )
        );
        createHarness.convertToItems(offer, consideration, OrderType.PAY);
    }

    function test_Success_ConvertToItems_PayeeOrder() public {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](2);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(alice.safe))
        });
        consideration[1] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Create the expected RentalItem array, but without items
        Item[] memory expectedItems = new Item[](2);

        // convert a PAYEE order into items
        Item[] memory items = createHarness.convertToItems(
            new SpentItem[](0),
            consideration,
            OrderType.PAYEE
        );

        // assert the Item lengths are the same
        assertEq(items.length, expectedItems.length);
    }

    function test_Reverts_ConvertToItems_PayeeOrder_OfferCountNotZero() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](2);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(alice.safe))
        });
        consideration[1] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Expect revert because offer items were provided
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_OfferCountNonZero.selector,
                offer.length
            )
        );
        createHarness.convertToItems(offer, consideration, OrderType.PAYEE);
    }
}
