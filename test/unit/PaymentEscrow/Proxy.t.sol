// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {RentalOrder} from "@src/libraries/RentalStructs.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";

contract Proxy_PaymentEscrow_Unit_Test is BaseTestWithoutEngine {
    function test_Success_ImplementationDiffersFromProxy() public {
        // assert that the address of the proxy is not the same as the
        // implementation contract
        assertTrue(address(ESCRW) != address(paymentEscrowImplementation));
    }

    function test_Success_KernelAddressIsCorrect() public {
        // assert that the kernel address is 0 on the implementation contract
        assertEq(address(paymentEscrowImplementation.kernel()), address(0));

        // assert that the kernel address is not zero on the proxy contract
        assertEq(address(ESCRW.kernel()), address(kernel));
    }

    function test_Reverts_ModuleProxyInstantiation() public {
        // expect revert because the module proxy cannot be instantiated twice
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_AlreadyInitialized.selector));
        ESCRW.MODULE_PROXY_INSTANTIATION(kernel);
    }

    function test_Reverts_ModuleProxyInstantiation_NotByProxy() public {
        // expect revert because the module proxy cannot be instantiated twice
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.MODULE_PROXY_INSTANTIATION(kernel);
    }

    function test_Reverts_SettlePayment_NotByProxy() public {
        // create stub rental order
        RentalOrder memory order;

        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.settlePayment(order);
    }

    function test_Reverts_SettlePaymentBatch_NotByProxy() public {
        // create stub rental orders
        RentalOrder[] memory orders;

        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.settlePaymentBatch(orders);
    }

    function test_Reverts_IncreaseDeposit_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.increaseDeposit(address(erc20s[0]), 1);
    }

    function test_Reverts_Skim_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.skim(address(erc20s[0]), alice.addr);
    }

    function test_Reverts_SetFee_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.setFee(123);
    }

    function test_Reverts_Upgrade_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.upgrade(address(0));
    }

    function test_Reverts_Freeze_NotByProxy() public {
        // expect revert because the implementation contract is accessed
        // instead of the proxy
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_OnlyCallByProxy.selector));
        paymentEscrowImplementation.freeze();
    }
}
