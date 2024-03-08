// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin-contracts/interfaces/IERC1155.sol";
import {BaseGuard} from "@safe-contracts/base/GuardManager.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";
import {LibString} from "@solady/utils/LibString.sol";

import {IHook} from "@src/interfaces/IHook.sol";
import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";
import {toKeycode} from "@src/libraries/KernelUtils.sol";
import {Storage} from "@src/modules/Storage.sol";
import {
    shared_set_approval_for_all_selector,
    e721_approve_selector,
    e721_safe_transfer_from_1_selector,
    e721_safe_transfer_from_2_selector,
    e721_transfer_from_selector,
    e721_burn_selector,
    e721_approve_token_id_offset,
    e721_safe_transfer_from_1_token_id_offset,
    e721_safe_transfer_from_2_token_id_offset,
    e721_transfer_from_token_id_offset,
    e721_burn_offset,
    e1155_safe_transfer_from_selector,
    e1155_safe_batch_transfer_from_selector,
    e1155_burn_selector,
    e1155_burn_batch_selector,
    e1155_safe_transfer_from_token_id_offset,
    e1155_safe_transfer_from_amount_offset,
    e1155_burn_offset,
    e1155_burn_amount_offset,
    gnosis_safe_set_guard_selector,
    gnosis_safe_enable_module_selector,
    gnosis_safe_disable_module_selector,
    gnosis_safe_set_fallback_handler_selector,
    gnosis_safe_enable_module_offset,
    gnosis_safe_disable_module_offset
} from "@src/libraries/RentalConstants.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {RentalUtils} from "@src/libraries/RentalUtils.sol";
import {RentalId} from "@src/libraries/RentalStructs.sol";

/**
 * @title Guard
 * @notice Acts as an interface for all behavior related to guarding transactions
 *         that originate from a rental wallet.
 */
contract Guard is Policy, BaseGuard {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    // Modules that the policy depends on.
    Storage public STORE;

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
        dependencies = new Keycode[](1);

        dependencies[0] = toKeycode("STORE");
        STORE = Storage(getModuleAddress(toKeycode("STORE")));
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
        requests = new Permissions[](2);
        requests[0] = Permissions(toKeycode("STORE"), STORE.updateHookPath.selector);
        requests[1] = Permissions(toKeycode("STORE"), STORE.updateHookStatus.selector);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Loads a `bytes32` value from calldata.
     *
     * @param data   Calldata of the transaction to execute.
     * @param offset Byte offset where the value starts.
     *
     * @return value The value retrieved from the data.
     */
    function _loadValueFromCalldata(
        bytes memory data,
        uint256 offset
    ) private pure returns (bytes32 value) {
        // Load the `uint256` from calldata at the offset.
        assembly {
            value := mload(add(data, offset))
        }
    }

    /**
     * @dev Reverts if the token is actively rented.
     *
     * @param selector Function selector which cannot be called
     * @param safe     Address of the safe that originated the call
     * @param token    Address of the token which is actively rented.
     * @param tokenId  ID of the token which is actively rented.
     */
    function _revertSelectorOnActiveRental(
        bytes4 selector,
        address safe,
        address token,
        uint256 tokenId
    ) private view {
        // Check if the selector is allowed.
        if (STORE.isRentedOut(safe, token, tokenId) > 0) {
            revert Errors.GuardPolicy_UnauthorizedSelector(selector);
        }
    }

    /**
     * @dev Reverts if the amount of tokens leaving the safe would drop the
     *      current balance of the safe below the actively rented amount.
     *
     * @param selector       Function selector which is restricted.
     * @param safe           Address of the safe that originated the call.
     * @param token          Address of the token which is actively rented.
     * @param tokenId        ID of the token which is actively rented.
     * @param amountToRemove Amount of tokens that will leave the safe.
     */
    function _revertSelectorOnValueOverflow(
        bytes4 selector,
        address safe,
        address token,
        uint256 tokenId,
        uint256 amountToRemove
    ) private view {
        // Get the total amount of currently rented assets.
        uint256 rentedAmount = STORE.isRentedOut(safe, token, tokenId);

        // Token is not actively rented, so calculating whether the amount
        // to remove is greater than the rented amount does not matter.
        if (rentedAmount == 0) return;

        // Amount of tokens that are currently in the safe.
        uint256 safeBalance = IERC1155(token).balanceOf(safe, tokenId);

        // Amount that will be remaining in the safe.
        uint256 remainingBalance = safeBalance - amountToRemove;

        // Check if the selector is allowed for the value provided.
        if (rentedAmount > remainingBalance) {
            revert Errors.GuardPolicy_UnauthorizedAssetAmount(
                selector,
                rentedAmount,
                remainingBalance
            );
        }
    }

    /**
     * @dev Forwards a gnosis safe call to a hook contract for further processing.
     *
     * @param hook  Address of the hook contract.
     * @param safe  Address of the rental wallet that originated the call.
     * @param to    Address that the call is directed to.
     * @param value Value of ether sent with the call.
     * @param data  Calldata to execute.
     */
    function _forwardToHook(
        address hook,
        address safe,
        address to,
        uint256 value,
        bytes memory data
    ) private {
        // Call the `onTransaction` hook function.
        try IHook(hook).onTransaction(safe, to, value, data) {} catch Error(
            string memory revertReason
        ) {
            // Revert with reason given.
            revert Errors.Shared_HookFailString(revertReason);
        } catch Panic(uint256 errorCode) {
            // Convert solidity panic code to string.
            string memory stringErrorCode = LibString.toString(errorCode);

            // Revert with panic code.
            revert Errors.Shared_HookFailString(
                string.concat("Hook reverted: Panic code ", stringErrorCode)
            );
        } catch (bytes memory revertData) {
            // Fallback to an error that returns the byte data.
            revert Errors.Shared_HookFailBytes(revertData);
        }
    }

    /**
     * @dev Prevent transactions that involve transferring an ERC721 or ERC1155 in any
     *      way, and prevent transactions that involve changing the modules or the
     *      guard contract.
     *
     * @param from Rental safe address that initiated the transaction.
     * @param to Address that the data is targetted to.
     * @param data Calldata of the transaction.
     */
    function _checkTransaction(address from, address to, bytes memory data) private view {
        bytes4 selector;

        // Load in the function selector.
        assembly {
            selector := mload(add(data, 0x20))
        }

        if (selector == e721_safe_transfer_from_1_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(
                _loadValueFromCalldata(data, e721_safe_transfer_from_1_token_id_offset)
            );

            // Check if the selector is allowed.
            _revertSelectorOnActiveRental(selector, from, to, tokenId);
        } else if (selector == e721_safe_transfer_from_2_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(
                _loadValueFromCalldata(data, e721_safe_transfer_from_2_token_id_offset)
            );

            // Check if the selector is allowed.
            _revertSelectorOnActiveRental(selector, from, to, tokenId);
        } else if (selector == e721_transfer_from_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(
                _loadValueFromCalldata(data, e721_transfer_from_token_id_offset)
            );

            // Check if the selector is allowed.
            _revertSelectorOnActiveRental(selector, from, to, tokenId);
        } else if (selector == e721_approve_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(
                _loadValueFromCalldata(data, e721_approve_token_id_offset)
            );

            // Check if the selector is allowed.
            _revertSelectorOnActiveRental(selector, from, to, tokenId);
        } else if (selector == e721_burn_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(_loadValueFromCalldata(data, e721_burn_offset));

            // Check if the selector is allowed.
            _revertSelectorOnActiveRental(selector, from, to, tokenId);
        } else if (selector == e1155_safe_transfer_from_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(
                _loadValueFromCalldata(data, e1155_safe_transfer_from_token_id_offset)
            );

            // Load the token amount from calldata
            uint256 amountToRemove = uint256(
                _loadValueFromCalldata(data, e1155_safe_transfer_from_amount_offset)
            );

            // Check if the amount leaving the safe is allowed.
            _revertSelectorOnValueOverflow(selector, from, to, tokenId, amountToRemove);
        } else if (selector == e1155_burn_selector) {
            // Load the token ID from calldata.
            uint256 tokenId = uint256(_loadValueFromCalldata(data, e1155_burn_offset));

            // Load the token amount from calldata
            uint256 amountToRemove = uint256(
                _loadValueFromCalldata(data, e1155_burn_amount_offset)
            );

            // Check if the amount leaving the safe is allowed.
            _revertSelectorOnValueOverflow(selector, from, to, tokenId, amountToRemove);
        } else if (selector == gnosis_safe_enable_module_selector) {
            // Load the extension address from calldata.
            address extension = address(
                uint160(
                    uint256(
                        _loadValueFromCalldata(data, gnosis_safe_enable_module_offset)
                    )
                )
            );

            // Check if the extension can be enabled.
            if (!STORE.extensionEnableAllowed(extension)) {
                revert Errors.GuardPolicy_UnauthorizedExtension(extension);
            }
        } else if (selector == gnosis_safe_disable_module_selector) {
            // Load the extension address from calldata.
            address extension = address(
                uint160(
                    uint256(
                        _loadValueFromCalldata(data, gnosis_safe_disable_module_offset)
                    )
                )
            );

            // Check if the extension can be disabled.
            if (!STORE.extensionDisableAllowed(extension)) {
                revert Errors.GuardPolicy_UnauthorizedExtension(extension);
            }
        } else {
            // Revert if the `setApprovalForAll` selector is specified. This selector is
            // shared between ERC721 and ERC1155 tokens.
            if (selector == shared_set_approval_for_all_selector) {
                revert Errors.GuardPolicy_UnauthorizedSelector(
                    shared_set_approval_for_all_selector
                );
            }

            // Revert if the `safeBatchTransferFrom` selector is specified. There's no
            // cheap way to check if individual items in the batch are rented out.
            // Each token ID would require a call to the storage contract to check
            // its rental status.
            if (selector == e1155_safe_batch_transfer_from_selector) {
                revert Errors.GuardPolicy_UnauthorizedSelector(
                    e1155_safe_batch_transfer_from_selector
                );
            }

            // Revert if the `batchBurn` selector is specified.
            if (selector == e1155_burn_batch_selector) {
                revert Errors.GuardPolicy_UnauthorizedSelector(e1155_burn_batch_selector);
            }

            // Revert if the `setGuard` selector is specified.
            if (selector == gnosis_safe_set_guard_selector) {
                revert Errors.GuardPolicy_UnauthorizedSelector(
                    gnosis_safe_set_guard_selector
                );
            }

            // Revert if the `setFallbackHandler` selector is specified.
            if (selector == gnosis_safe_set_fallback_handler_selector) {
                revert Errors.GuardPolicy_UnauthorizedSelector(
                    gnosis_safe_set_fallback_handler_selector
                );
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /** @notice Checks a transaction initiated by a rental safe to decide whether
     *          it can be allowed or not. During this check, execution control flow
     *          will be passed to an external hook contract if one exists for the
     *          target contract.
     *
     * @param to             Destination address of Safe transaction.
     * @param value          Ether value of Safe transaction.
     * @param data           Data payload of Safe transaction.
     * @param operation      Operation type of Safe transaction.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external override {
        // Check if the transaction is using delegate call.
        bool isDelegateCall = operation == Enum.Operation.DelegateCall;

        // Check if this guard is active for the protocol.
        if (isActive) {
            // Disallow transactions that use delegate call, unless explicitly
            // permitted by the protocol.
            if (isDelegateCall && !STORE.whitelistedDelegates(to)) {
                revert Errors.GuardPolicy_UnauthorizedDelegateCall(to);
            }
        }
        // If it isnt, then check if using delegate call and if the target address is
        // the guard emergency upgrade contract.
        else {
            if (!isDelegateCall || to != STORE.guardEmergencyUpgrade()) {
                revert Errors.GuardPolicy_Deactivated();
            }
        }

        // Place `to` back on top of the stack.
        address _to = to;
        uint256 _value = value;
        bytes memory _data = data;

        // Fetch the hook to interact with for this transaction.
        address hook = STORE.contractToHook(_to);
        bool hookIsActive = STORE.hookOnTransaction(hook);

        // If a hook exists and is enabled, forward the control flow to the hook.
        if (hook != address(0) && hookIsActive) {
            _forwardToHook(hook, msg.sender, _to, _value, _data);
        }
        // If no hook exists, use basic tx check.
        else {
            _checkTransaction(msg.sender, _to, _data);
        }
    }

    /**
     * @notice Performs any checks after execution. This is left unimplemented.
     *
     * @param txHash Hash of the transaction.
     * @param success Whether the transaction succeeded.
     */
    function checkAfterExecution(bytes32 txHash, bool success) external override {}

    /**
     * @notice Connects a target contract to a hook.
     *
     * @param to   The destination contract of a call.
     * @param hook The hook middleware contract to sit between the call
     *             and the destination.
     */
    function updateHookPath(address to, address hook) external onlyRole("GUARD_ADMIN") {
        STORE.updateHookPath(to, hook);
    }

    /**
     * @notice Toggle the status of a hook contract, which defines the functionality
     *         that the hook supports.
     *
     * @param hook The hook contract address.
     * @param bitmap Bitmap of the status.
     */
    function updateHookStatus(
        address hook,
        uint8 bitmap
    ) external onlyRole("GUARD_ADMIN") {
        STORE.updateHookStatus(hook, bitmap);
    }
}
