// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Safe} from "@safe-contracts/Safe.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";

/**
 * @title ISafe
 * @notice Interface for a multisignature wallet with support for confirmations using
 *         signed messages based on EIP-712.
 */
interface ISafe {
    /** @notice Executes a `operation` {0: Call, 1: DelegateCall}} transaction to `to`
     *          with `value` (Native Currency) and pays `gasPrice` * `gasLimit` in
     *          `gasToken` token to `refundReceiver`.
     *
     * @dev The fees are always transferred, even if the user transaction fails.
     *      This method doesn't perform any sanity check of the transaction, such as:
     *      - if the contract at `to` address has code or not
     *      - if the `gasToken` is a contract or not
     *      It is the responsibility of the caller to perform such checks.
     *
     * @param to             Destination address of Safe transaction.
     * @param value          Ether value of Safe transaction.
     * @param data           Data payload of Safe transaction.
     * @param operation      Operation type of Safe transaction.
     * @param safeTxGas      Gas that should be used for the Safe transaction.
     * @param baseGas        Gas costs that are independent of the transaction
     *                       execution(e.g. base transaction fee, signature check,
     *                       payment of the refund).
     * @param gasPrice       Gas price that should be used for the payment calculation.
     * @param gasToken       Token address (or 0 if ETH) that is used for the payment.
     * @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
     * @param signatures     Signature data that should be verified. Can be packed ECDSA
     *                       signature ({bytes32 r}{bytes32 s}{uint8 v}), contract
     *                       signature (EIP-1271) or approved hash.
     *
     * @return success Boolean indicating transaction's success.
     */
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);

    /**
     * @notice Execute `operation` (0: Call, 1: DelegateCall) to `to` with `value`
     *         (Native Token).
     *
     * @dev Function is virtual to allow overriding for L2 singleton to emit an event for
     *      indexing.
     *
     * @param to        Destination address of module transaction.
     * @param value     Ether value of module transaction.
     * @param data      Data payload of module transaction.
     * @param operation Operation type of module transaction.
     *
     * @return success  Boolean flag indicating if the call succeeded.
     */
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success);

    /**
     * @notice Replaces the owner `oldOwner` in the Safe with `newOwner`.
     *
     * @dev This can only be done via a Safe transaction.
     *
     * @param prevOwner Owner that pointed to the owner to be replaced in the linked list
     * @param oldOwner  Owner address to be replaced.
     * @param newOwner  New owner address.
     */
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;

    /**
     * @notice Enables the module `module` for the Safe.
     *
     * @dev This can only be done via a Safe transaction.
     *
     * @param module Module to be whitelisted.
     */
    function enableModule(address module) external;

    /**
     * @notice Disables the module `module` for the Safe.
     *
     * @dev This can only be done via a Safe transaction.
     *
     * @param prevModule Previous module in the modules linked list.
     * @param module     Module to be removed.
     */
    function disableModule(address prevModule, address module) external;

    /**
     * @notice Set Transaction Guard `guard` for the Safe. Make sure you trust the guard.
     *
     * @dev Set a guard that checks transactions before execution
     *      This can only be done via a Safe transaction.
     *      ⚠️ IMPORTANT: Since a guard has full power to block Safe transaction execution,
     *        a broken guard can cause a denial of service for the Safe. Make sure to
     *        carefully audit the guard code and design recovery mechanisms.
     *
     * @param guard The address of the guard to be used or the 0 address to disable the
     *              guard.
     */
    function setGuard(address guard) external;

    /**
     * @notice Set Fallback Handler to `handler` for the Safe.
     *
     * @dev Only fallback calls without value and with data will be forwarded.
     *      This can only be done via a Safe transaction.
     *      Cannot be set to the Safe itself.
     *
     * @param handler Contract to handle fallback calls.
     */
    function setFallbackHandler(address handler) external;

    /**
     * @notice Sets an initial storage of the Safe contract.
     *
     * @dev This method can only be called once. If a proxy was created without setting
     *      up, anyone can call setup and claim the proxy.
     *
     * @param _owners         List of Safe owners.
     * @param _threshold      Number of required confirmations for a Safe transaction.
     * @param to              Contract address for optional delegate call.
     * @param data            Data payload for optional delegate call.
     * @param fallbackHandler Handler for fallback calls to this contract.
     * @param paymentToken    Token that should be used for the payment (0 is ETH).
     * @param payment         Value that should be paid.
     * @param paymentReceiver Address that should receive the payment (or 0 if tx.origin).
     */
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;

    /**
     * @notice Returns if `owner` is an owner of the Safe.
     *
     * @return Boolean if owner is an owner of the Safe.
     */
    function isOwner(address owner) external view returns (bool);

    /**
     * @notice Returns transaction hash to be signed by owners.
     *
     * @param to             Destination address.
     * @param value          Ether value.
     * @param data           Data payload.
     * @param operation      Operation type.
     * @param safeTxGas      Fas that should be used for the safe transaction.
     * @param baseGas        Gas costs for data used to trigger the safe transaction.
     * @param gasPrice       Maximum gas price that should be used for this transaction.
     * @param gasToken       Token address (or 0 if ETH) that is used for the payment.
     * @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
     * @param _nonce         Transaction nonce.
     *
     * @return transactionHash Transaction hash to be signed by owners.
     */
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32 transactionHash);

    /**
     * @notice Returns the nonce of the current transaction
     *
     * @return nonce The nonce of the current transaction
     */
    function nonce() external view returns (uint256 nonce);

    /**
     * @notice Returns the hash of a message that can be signed by safe owners.
     *
     * @param safe    Safe which the message is targeted for.
     * @param message Message which will be signed.
     */
    function getMessageHashForSafe(
        Safe safe,
        bytes memory message
    ) external view returns (bytes32 messageHash);
}
