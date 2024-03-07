// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {toRole} from "@src/libraries/KernelUtils.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";

contract Admin_Unit_Test is BaseTestWithoutEngine {
    // test addresses
    address constant DELEGATE = TEST_ADDR_1;
    address constant EXTENSION = TEST_ADDR_2;
    address constant TOKEN = TEST_ADDR_3;

    function test_Success_ToggleWhitelistDelegate() public {
        // impersonate the admin admin
        vm.prank(deployer.addr);

        // enable this address to be delegate called by rental safes
        admin.toggleWhitelistDelegate(DELEGATE, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedDelegates(DELEGATE));
    }

    function test_Success_ToggleWhitelistExtension() public {
        // impersonate the admin admin
        vm.prank(deployer.addr);

        // enable this address to be added as a module by rental safes
        admin.toggleWhitelistExtension(address(this), uint8(2));

        // assert the address can be enabled as a module.
        assertTrue(STORE.extensionEnableAllowed(address(this)));
    }

    function test_Reverts_ToggleWhitelistDelegate_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.toggleWhitelistDelegate(DELEGATE, true);
    }

    function test_Success_ToggleWhitelistAsset() public {
        // impersonate the admin admin
        vm.prank(deployer.addr);

        // enable this address to be added as a module by rental safes
        admin.toggleWhitelistAsset(TOKEN, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedAssets(TOKEN));
    }

    function test_Reverts_ToggleWhitelistAsset_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.toggleWhitelistAsset(TOKEN, true);
    }

    function test_Success_ToggleWhitelistAssetBatch() public {
        // impersonate the admin admin
        vm.prank(deployer.addr);

        // Plan to whitelist 2 of the 3 assets
        address[] memory assets = new address[](3);
        bool[] memory enabled = new bool[](3);

        // build up the asset batch
        for (uint256 i; i < assets.length; ++i) {
            assets[i] = address(erc721s[i]);
        }

        // dont whitelist the middle asset
        enabled[0] = true;
        enabled[1] = false;
        enabled[2] = true;

        // whitelist the batch of tokens
        admin.toggleWhitelistAssetBatch(assets, enabled);

        // assert the correct addresses are whitelisted
        assertEq(STORE.whitelistedAssets(assets[0]), true);
        assertEq(STORE.whitelistedAssets(assets[1]), false);
        assertEq(STORE.whitelistedAssets(assets[2]), true);
    }

    function test_Reverts_ToggleWhitelistAssetBatch_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.toggleWhitelistAssetBatch(new address[](0), new bool[](0));
    }

    function test_Success_ToggleWhitelistPayment() public {
        // impersonate the admin admin
        vm.prank(deployer.addr);

        // enable this address to be added as a module by rental safes
        admin.toggleWhitelistPayment(TOKEN, true);

        // assert the address is whitelisted
        assertTrue(STORE.whitelistedPayments(TOKEN));
    }

    function test_Reverts_ToggleWhitelistPayment_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.toggleWhitelistPayment(TOKEN, true);
    }

    function test_Success_ToggleWhitelistPaymentBatch() public {
        // impersonate the admin admin
        vm.prank(deployer.addr);

        // Plan to whitelist 2 of the 3 payments
        address[] memory payments = new address[](3);
        bool[] memory enabled = new bool[](3);

        // build up the payment batch
        for (uint256 i; i < payments.length; ++i) {
            payments[i] = address(erc20s[i]);
        }

        // dont whitelist the middle payment
        enabled[0] = true;
        enabled[1] = false;
        enabled[2] = true;

        // whitelist the batch of tokens
        admin.toggleWhitelistPaymentBatch(payments, enabled);

        // assert the correct addresses are whitelisted
        assertEq(STORE.whitelistedPayments(payments[0]), true);
        assertEq(STORE.whitelistedPayments(payments[1]), false);
        assertEq(STORE.whitelistedPayments(payments[2]), true);
    }

    function test_Reverts_ToggleWhitelistPaymentBatch_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.toggleWhitelistPaymentBatch(new address[](0), new bool[](0));
    }

    function test_Reverts_ToggleWhitelistExtension_NotAdmin() public {
        // impersonate a non-admin
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.toggleWhitelistExtension(EXTENSION, uint8(2));
    }

    function test_Success_SetFee() public {
        // impersonate the admin policy admin
        vm.prank(deployer.addr);

        // set the fee
        admin.setFee(123);

        // assert the fee was changed
        assertEq(ESCRW.fee(), 123);
    }

    function test_Reverts_SetFee_NotAdmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.setFee(10);
    }

    function test_Fuzz_Skim(uint256 amount) public {
        vm.assume(amount > 2);
        vm.assume(amount < 1_000_000);

        // add tokens to the contract
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate the create policy
        vm.prank(address(create));

        // increase the deposit balance of the contract by half
        // the token amount
        uint256 depositedAmount = amount / 2;
        ESCRW.increaseDeposit(address(erc20s[0]), depositedAmount);

        // impersonate the admin policy admin
        vm.prank(deployer.addr);

        // skim the rest
        admin.skim(address(erc20s[0]), deployer.addr);

        // stop impersonating
        vm.stopPrank();

        // expect the deposit balance and the skimmed balance to be equal
        assertEq(
            erc20s[0].balanceOf(deployer.addr) + ESCRW.balanceOf(address(erc20s[0])),
            amount
        );

        // expect the deposit balance and the true balance of the escrow to be equal
        assertEq(
            erc20s[0].balanceOf(address(ESCRW)),
            ESCRW.balanceOf(address(erc20s[0]))
        );
    }

    function test_Reverts_Skim_NotAdmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.skim(address(erc20s[0]), alice.addr);
    }

    function test_Success_UpgradeStorage() public {
        // encode implementation contract bytecode and constructor arguments
        bytes memory implementationInitCode = abi.encodePacked(
            type(Storage).creationCode,
            abi.encode(address(0))
        );

        // Deploy implementation contract
        vm.prank(deployer.addr);
        address implementation = create2Deployer.deploy(
            bytes32(uint256(salt) + uint256(1)),
            implementationInitCode
        );

        // upgrade the storage module
        vm.prank(deployer.addr);
        admin.upgradeStorage(implementation);
    }

    function test_Reverts_UpgradeStorage_NotAdmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.upgradeStorage(address(this));
    }

    function test_Success_FreezeStorage() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // freeze the storage module
        admin.freezeStorage();
    }

    function test_Reverts_FreezeStorage_NotAdmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.freezeStorage();
    }

    function test_Success_UpgradePaymentEscrow() public {
        // encode implementation contract bytecode and constructor arguments
        bytes memory implementationInitCode = abi.encodePacked(
            type(PaymentEscrow).creationCode,
            abi.encode(address(0))
        );

        // Deploy implementation contract
        vm.prank(deployer.addr);
        address implementation = create2Deployer.deploy(
            bytes32(uint256(salt) + uint256(1)),
            implementationInitCode
        );

        // upgrade the storage module
        vm.prank(deployer.addr);
        admin.upgradePaymentEscrow(implementation);
    }

    function test_Reverts_UpgradePaymentEscrow_NotAdmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.upgradePaymentEscrow(address(this));
    }

    function test_Success_FreezePaymentEscrow() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // freeze the storage module
        admin.freezePaymentEscrow();
    }

    function test_Reverts_FreezePaymentEscrow_NotAdmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.freezePaymentEscrow();
    }

    function test_Success_SetMaxRentDuration() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // set the max rent duration
        admin.setMaxRentDuration(22 days);

        // expect the max rent duration to have changed
        assertEq(STORE.maxRentDuration(), 22 days);
    }

    function test_Reverts_SetMaxRentDuration_NotAmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.setMaxRentDuration(22 days);
    }

    function test_Success_SetMaxOfferItems() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // set the max offer items
        admin.setMaxOfferItems(15);

        // expect the max offer items to have changed
        assertEq(STORE.maxOfferItems(), 15);
    }

    function test_Reverts_SetMaxOfferItems_NotAmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.setMaxOfferItems(15);
    }

    function test_Success_SetMaxConsiderationItems() public {
        // impersonate an address with permissions
        vm.prank(deployer.addr);

        // set the max consideration items
        admin.setMaxConsiderationItems(15);

        // expect the max consideration items to have changed
        assertEq(STORE.maxConsiderationItems(), 15);
    }

    function test_Reverts_setMaxConsiderationItems_NotAmin() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller is not an admin for the admin policy
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Policy_OnlyRole.selector, toRole("ADMIN_ADMIN"))
        );
        admin.setMaxConsiderationItems(15);
    }
}
