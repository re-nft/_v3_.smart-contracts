// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

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
}
