// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {Actions} from "@src/libraries/RentalStructs.sol";
import {
    PaymentEscrowUpgrade
} from "@src/examples/upgrades/PaymentEscrowModuleUpgrade.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {MismatchUUID} from "@test/mocks/proxies/MismatchUUID.sol";

contract PaymentEscrowUpgrade_Upgradeability_Integration_Test is BaseTest {
    // Deploys the new payment escrow upgrade implementation contract
    function _deployPaymentEscrowUpgradeImplementation() internal {
        // abi encode the new payment escrow bytecode and constructor arguments
        // for the implementation contract
        bytes memory paymentEscrowUpgradeImplementationInitCode = abi.encodePacked(
            type(PaymentEscrowUpgrade).creationCode,
            abi.encode(address(0))
        );

        // Deploy payment escrow implementation contract
        vm.prank(deployer.addr);
        paymentEscrowImplementation = PaymentEscrow(
            create2Deployer.deploy(salt, paymentEscrowUpgradeImplementationInitCode)
        );
    }

    function test_Success_Upgrade() public {
        // save initial payment escrow contract addresses
        address originalProxy = address(ESCRW);
        address originalImplementation = address(paymentEscrowImplementation);

        // mint some tokens to the create policy
        erc20s[0].mint(address(create), 1);

        // increase the deposit amount in the contract
        vm.prank(address(create));
        ESCRW.increaseDeposit(address(erc20s[0]), 1);

        // assert the initial storage is expected
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 1);

        // deploy the payment escrow upgrade implementation
        _deployPaymentEscrowUpgradeImplementation();

        // impersonate the admin
        vm.prank(deployer.addr);

        // use the admin policy to upgrade the payment escrow module
        admin.upgradePaymentEscrow(address(paymentEscrowImplementation));

        // assert the proxy address has remained the same
        assertEq(address(ESCRW), originalProxy);

        // assert the implementation address has changed
        assertFalse(address(paymentEscrowImplementation) == originalImplementation);

        // assert the initial storage is unchanged
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 1);

        // assert the new functionality can be accessed
        assertEq(PaymentEscrowUpgrade(address(ESCRW)).upgradeSuccess(), true);
    }

    function test_Reverts_Upgrade_IncompatibleContract_IsNotUUPSCompliant() public {
        // impersonate the admin
        vm.prank(deployer.addr);

        // expect revert because an upgrade was attempted with an incompatible contract
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Proxy_NotCompatible.selector, address(this))
        );
        admin.upgradePaymentEscrow(address(this));
    }

    function test_Reverts_Upgrade_IncompatibleContract_UUIDMismatch() public {
        // deploy the mock proxiable contract
        MismatchUUID mismatchUUID = new MismatchUUID();

        // impersonate the admin
        vm.prank(deployer.addr);

        // expect revert because an upgrade was attempted with an incompatible contract
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Proxy_NotCompatible.selector,
                address(mismatchUUID)
            )
        );
        admin.upgradePaymentEscrow(address(mismatchUUID));
    }

    function test_Success_Freeze() public {
        // impersonate the admin
        vm.prank(deployer.addr);

        // use the admin policy to freeze the payment escrow module
        admin.freezePaymentEscrow();

        // deploy the payment escrow upgrade implementation
        _deployPaymentEscrowUpgradeImplementation();

        // impersonate the admin
        vm.prank(deployer.addr);

        // expect revert because a frozen contract can not be upgraded
        vm.expectRevert(abi.encodeWithSelector(Errors.Proxy_Frozen.selector));
        admin.upgradePaymentEscrow(address(paymentEscrowImplementation));
    }
}
