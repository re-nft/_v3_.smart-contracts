// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    SpentItem,
    ReceivedItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Item, ItemType, SettleTo} from "@src/libraries/RentalStructs.sol";
import {Actions} from "@src/Kernel.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {CreateHarness} from "@test/mocks/harnesses/CreateHarness.sol";

// Tests functionality on the create policy related to processing orders
contract Create_ProcessOrder_Unit_Test is BaseTestWithoutEngine {
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

    function test_Success_ProcessBaseOrderOffer() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // Create an empty RentalItem array
        Item[] memory items = new Item[](offer.length);

        // Create the expected RentalItem array
        Item[] memory expectedItems = new Item[](offer.length);
        expectedItems[0] = Item({
            itemType: ItemType.ERC721,
            settleTo: SettleTo.LENDER,
            token: address(erc721s[0]),
            amount: 1,
            identifier: 0
        });

        // process the BASE order offer items
        items = createHarness.processBaseOrderOffer(items, offer, 0);

        // assert the Item lengths are the same
        assertEq(items.length, expectedItems.length);

        // assert that each Item is expected
        for (uint256 i = 0; i < items.length; i++) {
            assertEq(items[i], expectedItems[i]);
        }
    }

    function test_Reverts_ProcessBaseOrderOffer_OfferCountZero() public {
        // Expect revert because no offer items were provided
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_OfferCountZero.selector)
        );
        createHarness.processBaseOrderOffer(new Item[](0), new SpentItem[](0), 0);
    }

    function test_Reverts_ProcessBaseOrderOffer_SeaportItemTypeNotSupported() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1
        });

        // Expect revert because an ERC20 offer item was provided
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_SeaportItemTypeNotSupported.selector,
                SeaportItemType.ERC20
            )
        );
        createHarness.processBaseOrderOffer(new Item[](offer.length), offer, 0);
    }

    function test_Success_ProcessBaseOrderConsideration() public {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Create an empty RentalItem array
        Item[] memory items = new Item[](consideration.length);

        // Create the expected RentalItem array
        Item[] memory expectedItems = new Item[](consideration.length);
        expectedItems[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.LENDER,
            token: address(erc20s[0]),
            amount: 1,
            identifier: 0
        });

        // process the BASE order consideration items
        items = createHarness.processBaseOrderConsideration(items, consideration, 0);

        // assert the Item lengths are the same
        assertEq(items.length, expectedItems.length);

        // assert that each Item is expected
        for (uint256 i = 0; i < items.length; i++) {
            assertEq(items[i], expectedItems[i]);
        }
    }

    function test_Reverts_ProcessBaseOrderConsideration_ConsiderationCountZero() public {
        // Expect revert because no consideration items were provided
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_ConsiderationCountZero.selector)
        );
        createHarness.processBaseOrderConsideration(
            new Item[](0),
            new ReceivedItem[](0),
            0
        );
    }

    function test_Reverts_ProcessBaseOrderConsideration_SeaportItemTypeNotSupported()
        public
    {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Expect revert because an ERC721 offer item was provided
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_SeaportItemTypeNotSupported.selector,
                SeaportItemType.ERC721
            )
        );
        createHarness.processBaseOrderConsideration(
            new Item[](consideration.length),
            consideration,
            0
        );
    }

    function test_Success_ProcessPayOrderOffer() public {
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

        // Create an empty RentalItem array
        Item[] memory items = new Item[](offer.length);

        // Create the expected RentalItem array
        Item[] memory expectedItems = new Item[](offer.length);
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

        // process the PAY order offer items
        items = createHarness.processPayOrderOffer(items, offer, 0);

        // assert the Item lengths are the same
        assertEq(items.length, expectedItems.length);

        // assert that each Item is expected
        for (uint256 i = 0; i < items.length; i++) {
            assertEq(items[i], expectedItems[i]);
        }
    }

    function test_Reverts_ProcessPayOrderOffer_TotalRentalsZero() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1
        });

        // Expect revert because a rental item wasnt provided in the offer array
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_ItemCountZero.selector, 0, 1)
        );
        createHarness.processPayOrderOffer(new Item[](offer.length), offer, 0);
    }

    function test_Reverts_ProcessPayOrderOffer_TotalPaymentsZero() public {
        // Create an Offer array
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // Expect revert because a payment item wasnt provided in the offer array
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_ItemCountZero.selector, 1, 0)
        );
        createHarness.processPayOrderOffer(new Item[](offer.length), offer, 0);
    }

    function test_Reverts_ProcessPayOrderOffer_SeaportItemTypeNotSupported() public {
        // Create an Offer array with a non-supported item type
        SpentItem[] memory offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: SeaportItemType.ERC1155_WITH_CRITERIA,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1
        });

        // Expect revert because the item type is not supported
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_SeaportItemTypeNotSupported.selector,
                SeaportItemType.ERC1155_WITH_CRITERIA
            )
        );
        createHarness.processPayOrderOffer(new Item[](offer.length), offer, 0);
    }

    function test_Success_ProcessPayeeOrderConsideration() public view {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](2);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });
        consideration[1] = ReceivedItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(alice.safe))
        });

        // process the PAYEE order consideration items
        createHarness.processPayeeOrderConsideration(consideration);
    }

    function test_Reverts_ProcessPayeeOrderConsideration_TotalRentalsZero() public {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Expect revert because a rental item wasnt provided in the offer array
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_ItemCountZero.selector, 0, 1)
        );
        createHarness.processPayeeOrderConsideration(consideration);
    }

    function test_Reverts_ProcessPayeeOrderConsideration_TotalPaymentsZero() public {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC721,
            token: address(erc721s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(alice.safe))
        });

        // Expect revert because a rental item wasnt provided in the offer array
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CreatePolicy_ItemCountZero.selector, 1, 0)
        );
        createHarness.processPayeeOrderConsideration(consideration);
    }

    function test_Reverts_ProcessPayeeOrderConsideration_SeaportItemTypeNotSupported()
        public
    {
        // Create a Consideration array
        ReceivedItem[] memory consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: SeaportItemType.ERC1155_WITH_CRITERIA,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(address(ESCRW))
        });

        // Expect revert because the item type is not supported
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_SeaportItemTypeNotSupported.selector,
                SeaportItemType.ERC1155_WITH_CRITERIA
            )
        );
        createHarness.processPayeeOrderConsideration(consideration);
    }
}
