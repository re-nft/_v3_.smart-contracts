// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IHook
 * @notice Interface for hook contracts which are capable of being called when a rental
 *         begins, ends, or during a transaction that involves a rented asset.
 */
interface IHook {
    /**
     * @notice Triggers this hook call during a transaction involving a rented asset with
     *         an active hook address attached to its metadata.
     *
     * @param safe  Rental wallet that initiated the call.
     * @param to    Recipient of the call.
     * @param value Value of ether sent with the call.
     * @param data  Any extra data sent along with the hook.
     */
    function onTransaction(
        address safe,
        address to,
        uint256 value,
        bytes memory data
    ) external;

    /**
     * @notice Triggers this hook call when a rental has been started.
     *
     * @param safe       Rental wallet which will receive the rented asset associated
     *                   with this hook.
     * @param token      Address of the rented asset.
     * @param identifier ID of the rented asset.
     * @param amount     Amount of the rented asset being transferred.
     * @param extraData  Any extra data sent along with the hook.
     */
    function onStart(
        address safe,
        address token,
        uint256 identifier,
        uint256 amount,
        bytes memory extraData
    ) external;

    /**
     * @notice Triggers this hook call when a rental has been stopped.
     *
     * @param safe       Rental wallet currently owning the rented asset associated with
     *                   this hook.
     * @param token      Address of the rented asset.
     * @param identifier ID of the rented asset.
     * @param amount     Amount of the rented asset being transferred.
     * @param extraData  Any extra data sent along with the hook.
     */
    function onStop(
        address safe,
        address token,
        uint256 identifier,
        uint256 amount,
        bytes memory extraData
    ) external;
}
