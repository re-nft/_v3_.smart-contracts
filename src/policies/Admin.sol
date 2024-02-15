// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";
import {toKeycode} from "@src/libraries/KernelUtils.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";

/**
 * @title Admin
 * @notice Acts as an interface for all behavior in the protocol related
 *         admin logic. Admin duties include fee management, proxy management,
 *         and whitelist management.
 */
contract Admin is Policy {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    // Modules that the policy depends on.
    Storage public STORE;
    PaymentEscrow public ESCRW;

    /**
     * @dev Instantiate this contract as a policy.
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) Policy(kernel_) {}

    /**
     * @notice Upon policy activation, configures the modules that the policy depends on.
     *         If a module is ever upgraded that this policy depends on, the kernel will
     *         call this function again to ensure this policy has the current address
     *         of the module.
     *
     * @return dependencies Array of keycodes which represent modules that
     *                      this policy depends on.
     */
    function configureDependencies()
        external
        override
        onlyKernel
        returns (Keycode[] memory dependencies)
    {
        dependencies = new Keycode[](2);

        dependencies[0] = toKeycode("STORE");
        STORE = Storage(getModuleAddress(toKeycode("STORE")));

        dependencies[1] = toKeycode("ESCRW");
        ESCRW = PaymentEscrow(getModuleAddress(toKeycode("ESCRW")));
    }

    /**
     * @notice Upon policy activation, permissions are requested from the kernel to access
     *         particular keycode <> function selector pairs. Once these permissions are
     *         granted, they do not change and can only be revoked when the policy is
     *         deactivated by the kernel.
     *
     * @return requests Array of keycode <> function selector pairs which represent
     *                  permissions for the policy.
     */
    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](11);
        requests[0] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistExtension.selector
        );
        requests[1] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistDelegate.selector
        );
        requests[2] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistAsset.selector
        );
        requests[3] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistPayment.selector
        );
        requests[4] = Permissions(toKeycode("STORE"), STORE.upgrade.selector);
        requests[5] = Permissions(toKeycode("STORE"), STORE.freeze.selector);
        requests[6] = Permissions(toKeycode("STORE"), STORE.setMaxRentDuration.selector);

        requests[7] = Permissions(toKeycode("ESCRW"), ESCRW.skim.selector);
        requests[8] = Permissions(toKeycode("ESCRW"), ESCRW.setFee.selector);
        requests[9] = Permissions(toKeycode("ESCRW"), ESCRW.upgrade.selector);
        requests[10] = Permissions(toKeycode("ESCRW"), ESCRW.freeze.selector);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Toggle whether an address can be delegate called by a rental safe.
     *
     * @param delegate  Target address for the delegate call.
     * @param isEnabled Whether the address can be delegate called.
     */
    function toggleWhitelistDelegate(
        address delegate,
        bool isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistDelegate(delegate, isEnabled);
    }

    /**
     * @notice Toggle whether an extension is whitelisted. An extension is any contract
     *         which can be added to a rental safe as a Safe module.
     *
     * @param extension Extension which can be added to a safe.
     * @param isEnabled Whether the extension is enabled.
     */
    function toggleWhitelistExtension(
        address extension,
        bool isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistExtension(extension, isEnabled);
    }

    /**
     * @notice Toggles whether a token can be rented.
     *
     * @param asset     Token address which can be rented via the protocol.
     * @param isEnabled Whether the token is whitelisted for rent.
     */
    function toggleWhitelistAsset(
        address asset,
        bool isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistAsset(asset, isEnabled);
    }

    /**
     * @notice Toggles whether a token can be used as a payment.
     *
     * @param payment   Token address which can be used as payment via the protocol.
     * @param isEnabled Whether the token is whitelisted for payment.
     */
    function toggleWhitelistPayment(
        address payment,
        bool isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistPayment(payment, isEnabled);
    }

    /**
     * @notice Upgrades the storage module to a newer implementation. The new
     *         implementation contract must adhere to ERC-1822.
     *
     * @param newImplementation Address of the new implemention.
     */
    function upgradeStorage(address newImplementation) external onlyRole("ADMIN_ADMIN") {
        STORE.upgrade(newImplementation);
    }

    /**
     * @notice Freezes the storage module so that no proxy upgrades can take place. This
     *         action is non-reversible.
     */
    function freezeStorage() external onlyRole("ADMIN_ADMIN") {
        STORE.freeze();
    }

    /**
     * @notice Upgrades the payment escrow module to a newer implementation.
     *         The new implementation contract must adhere to ERC-1822.
     *
     * @param newImplementation Address of the new implemention.
     */
    function upgradePaymentEscrow(
        address newImplementation
    ) external onlyRole("ADMIN_ADMIN") {
        ESCRW.upgrade(newImplementation);
    }

    /**
     * @notice Freezes the payment escrow module so that no proxy upgrades can take
     *         place. This action is non-reversible.
     */
    function freezePaymentEscrow() external onlyRole("ADMIN_ADMIN") {
        ESCRW.freeze();
    }

    /**
     * @notice Skims all protocol fees from the escrow module to the target address.
     *
     * @param token Token address which denominates the fee.
     * @param to    Destination address to send the tokens.
     */
    function skim(address token, address to) external onlyRole("ADMIN_ADMIN") {
        ESCRW.skim(token, to);
    }

    /**
     * @notice Sets the protocol fee numerator. Numerator cannot be greater than 10,000.
     *
     * @param feeNumerator Numerator for the fee.
     */
    function setFee(uint256 feeNumerator) external onlyRole("ADMIN_ADMIN") {
        ESCRW.setFee(feeNumerator);
    }

    /**
     * @notice Sets the maximum rent duration.
     *
     * @param newDuration The new maximum rent duration.
     */
    function setMaxRentDuration(uint256 newDuration) external onlyRole("ADMIN_ADMIN") {
        STORE.setMaxRentDuration(newDuration);
    }
}
