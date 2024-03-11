// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {OrderMetadata, OrderType, Hook} from "@src/libraries/RentalStructs.sol";
import {Actions} from "@src/Kernel.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {StopHarness} from "@test/mocks/harnesses/StopHarness.sol";

// Tests functionality on the stop policy related to stopped order validity
contract Stop_ValidityChecks_Unit_Test is BaseTestWithoutEngine {
    // Stop Policy Harness contract
    StopHarness public stopHarness;

    function setUp() public override {
        super.setUp();

        // set up a stop policy contract that exposes the internal functions
        stopHarness = new StopHarness(kernel);

        // impersonate the deployer which is the kernel admin
        vm.prank(deployer.addr);

        // enable the stop policy harness
        kernel.executeAction(Actions.ActivatePolicy, address(stopHarness));
    }

    function test_Reverts_CanBeStopped_StoppedTooSoon() public {
        // impersonate the lender
        vm.prank(alice.addr);

        // Expect the rental cannot be stopped because it was started in the same
        // transaction that it was stopped.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StopPolicy_StoppedTooSoon.selector)
        );
        stopHarness.validateRentalCanBeStopped(
            OrderType.BASE,
            block.timestamp,
            block.timestamp - 1,
            alice.addr
        );
    }

    function test_Success_CanBeStopped_BaseOrder_Expired_IsLender() public {
        // impersonate the lender
        vm.prank(alice.addr);

        // Expect the rental can be stopped
        stopHarness.validateRentalCanBeStopped(
            OrderType.BASE,
            0,
            block.timestamp - 1,
            alice.addr
        );
    }

    function test_Success_CanBeStopped_BaseOrder_Expired_IsNotLender() public {
        // impersonate an address that is not the lender
        vm.prank(bob.addr);

        // Expect the rental can be stopped
        stopHarness.validateRentalCanBeStopped(
            OrderType.BASE,
            0,
            block.timestamp - 1,
            alice.addr
        );
    }

    function test_Reverts_CanBeStopped_BaseOrder_NotExpired_IsLender() public {
        // impersonate the lender
        vm.prank(alice.addr);

        // Expect the rental cannot be stopped because it has not expired
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.StopPolicy_CannotStopOrder.selector,
                block.timestamp,
                alice.addr
            )
        );
        stopHarness.validateRentalCanBeStopped(
            OrderType.BASE,
            0,
            block.timestamp + 1,
            alice.addr
        );
    }

    function test_Reverts_CanBeStopped_BaseOrder_NotExpired_IsNotLender() public {
        // impersonate an address that is not the lender
        vm.prank(bob.addr);

        // Expect the rental cannot be stopped because it has not expired
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.StopPolicy_CannotStopOrder.selector,
                block.timestamp,
                bob.addr
            )
        );
        stopHarness.validateRentalCanBeStopped(
            OrderType.BASE,
            0,
            block.timestamp + 1,
            alice.addr
        );
    }

    function test_Success_CanBeStopped_PayOrder_Expired_IsLender() public {
        // impersonate the lender
        vm.prank(alice.addr);

        // Expect the rental can be stopped
        stopHarness.validateRentalCanBeStopped(
            OrderType.PAY,
            0,
            block.timestamp - 1,
            alice.addr
        );
    }

    function test_Success_CanBeStopped_PayOrder_Expired_IsNotLender() public {
        // impersonate an address that is not the lender
        vm.prank(bob.addr);

        // Expect the rental can be stopped
        stopHarness.validateRentalCanBeStopped(
            OrderType.PAY,
            0,
            block.timestamp - 1,
            alice.addr
        );
    }

    function test_Success_CanBeStopped_PayOrder_NotExpired_IsLender() public {
        // impersonate the lender
        vm.prank(alice.addr);

        // Expect the rental can be stopped
        stopHarness.validateRentalCanBeStopped(
            OrderType.PAY,
            0,
            block.timestamp + 1,
            alice.addr
        );
    }

    function test_Reverts_CanBeStopped_PayOrder_NotExpired_IsNotLenter() public {
        // impersonate an address that is not the lender
        vm.prank(bob.addr);

        // Expect the rental cannot be stopped because the PAY order has not expired,
        // and a non-lender address is trying to stop
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.StopPolicy_CannotStopOrder.selector,
                block.timestamp,
                bob.addr
            )
        );
        stopHarness.validateRentalCanBeStopped(
            OrderType.PAY,
            0,
            block.timestamp + 1,
            alice.addr
        );
    }

    function test_Reverts_CanBeStopped_PayeeOrder_NotSupported() public {
        // impersonate the lender
        vm.prank(alice.addr);

        // Expect the rental cannot be stopped because PAYEE orders should
        // never be processed
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_OrderTypeNotSupported.selector,
                uint256(2)
            )
        );
        stopHarness.validateRentalCanBeStopped(
            OrderType.PAYEE,
            0,
            block.timestamp - 1,
            alice.addr
        );
    }
}
