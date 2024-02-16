// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    ReceivedItem,
    ItemType as SeaportItemType
} from "@seaport-types/lib/ConsiderationStructs.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Item, ItemType, SettleTo} from "@src/libraries/RentalStructs.sol";
import {Actions} from "@src/Kernel.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {CreateHarness} from "@test/mocks/harnesses/CreateHarness.sol";

// Tests functionality on the create policy related to invariant checks
contract Create_InvariantChecks_Unit_Test is BaseTestWithoutEngine {
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

    function test_Success_ExecutionInvariantChecks_ERC20() public view {
        // create an execution
        ReceivedItem[] memory executions = new ReceivedItem[](1);
        executions[0] = ReceivedItem({
            token: address(erc20s[0]),
            itemType: SeaportItemType.ERC20,
            amount: 1,
            identifier: 0,
            recipient: payable(address(createHarness))
        });

        // check the invariant
        createHarness.executionInvariantChecks(executions);
    }

    function test_Reverts_ExecutionInvariantChecks_ERC20_UnexpectedTokenRecipient()
        public
    {
        // create an execution
        ReceivedItem[] memory executions = new ReceivedItem[](1);
        executions[0] = ReceivedItem({
            itemType: SeaportItemType.ERC20,
            token: address(erc20s[0]),
            identifier: 0,
            amount: 1,
            recipient: payable(alice.addr)
        });

        // Expect revert because the tokens were sent to the incorrect recipient
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_UnexpectedTokenRecipient.selector,
                executions[0].itemType,
                executions[0].token,
                executions[0].identifier,
                executions[0].amount,
                executions[0].recipient,
                address(createHarness)
            )
        );
        createHarness.executionInvariantChecks(executions);
    }

    function test_Success_ExecutionInvariantChecks_ERC721() public view {
        // create an execution
        ReceivedItem[] memory executions = new ReceivedItem[](1);
        executions[0] = ReceivedItem({
            token: address(erc721s[0]),
            itemType: SeaportItemType.ERC721,
            amount: 1,
            identifier: 0,
            recipient: payable(address(createHarness))
        });

        // check the invariant
        createHarness.executionInvariantChecks(executions);
    }

    function test_Reverts_ExecutionInvariantChecks_ERC721_UnexpectedTokenRecipient()
        public
    {
        // create an execution
        ReceivedItem[] memory executions = new ReceivedItem[](1);
        executions[0] = ReceivedItem({
            token: address(erc721s[0]),
            itemType: SeaportItemType.ERC721,
            amount: 1,
            identifier: 0,
            recipient: payable(address(bob.safe))
        });

        // Expect revert because the tokens were sent to the incorrect recipient
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_UnexpectedTokenRecipient.selector,
                executions[0].itemType,
                executions[0].token,
                executions[0].identifier,
                executions[0].amount,
                executions[0].recipient,
                address(createHarness)
            )
        );
        createHarness.executionInvariantChecks(executions);
    }

    function test_Success_ExecutionInvariantChecks_ERC1155() public view {
        // create an execution
        ReceivedItem[] memory executions = new ReceivedItem[](1);
        executions[0] = ReceivedItem({
            token: address(erc1155s[0]),
            itemType: SeaportItemType.ERC1155,
            amount: 1,
            identifier: 0,
            recipient: payable(address(createHarness))
        });

        // check the invariant
        createHarness.executionInvariantChecks(executions);
    }

    function test_Reverts_ExecutionInvariantChecks_ERC1155_UnexpectedTokenRecipient()
        public
    {
        // create an execution
        ReceivedItem[] memory executions = new ReceivedItem[](1);
        executions[0] = ReceivedItem({
            token: address(erc1155s[0]),
            itemType: SeaportItemType.ERC1155,
            amount: 1,
            identifier: 0,
            recipient: payable(address(bob.safe))
        });
        // Expect revert because the tokens were sent to the incorrect recipient
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CreatePolicy_UnexpectedTokenRecipient.selector,
                executions[0].itemType,
                executions[0].token,
                executions[0].identifier,
                executions[0].amount,
                executions[0].recipient,
                address(createHarness)
            )
        );
        createHarness.executionInvariantChecks(executions);
    }
}
