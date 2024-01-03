// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    Hook,
    Item,
    OrderType,
    Role,
    Keycode,
    Actions
} from "@src/libraries/RentalStructs.sol";
import {Policy} from "@src/Kernel.sol";

/**
 * @title Events
 * @notice Contains events defined for the protocol.
 */
library Events {
    /////////////////////////////////////////////////////////////////////////////////
    //                                 Create Policy                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Emitted when a new rental order is started. PAYEE orders are excluded from
     *      emitting this event.
     *
     * @param orderHash        Hash of the rental order struct.
     * @param emittedExtraData Data passed to the order to be emitted as an event.
     * @param seaportOrderHash Order hash of the seaport order struct.
     * @param items            Items in the rental order.
     * @param hooks            Hooks defined for the rental order.
     * @param orderType        Order type of the rental.
     * @param lender           Lender EOA of the assets in the order.
     * @param renter           Renter EOA of the assets in the order.
     * @param rentalWallet     Wallet contract which holds the rented assets.
     * @param startTimestamp   Timestamp which marks the start of the rental.
     * @param endTimestamp     Timestamp which marks the end of the rental.
     */
    event RentalOrderStarted(
        bytes32 orderHash,
        bytes emittedExtraData,
        bytes32 seaportOrderHash,
        Item[] items,
        Hook[] hooks,
        OrderType orderType,
        address indexed lender,
        address indexed renter,
        address rentalWallet,
        uint256 startTimestamp,
        uint256 endTimestamp
    );

    /////////////////////////////////////////////////////////////////////////////////
    //                                  Stop Policy                                //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Emitted when a rental order is stopped.
     *
     * @param seaportOrderHash Order hash of the seaport order struct.
     * @param stopper          Address which initated the stopping of the rental.
     */
    event RentalOrderStopped(bytes32 seaportOrderHash, address stopper);

    /////////////////////////////////////////////////////////////////////////////////
    //                                Factory Policy                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Emitted when a rental safe is deployed.
     *
     * @param safe      Address of the newly deployed rental safe contract.
     * @param owners    Owner addresses of the rental safe.
     * @param threshold Number of owners required to sign a transaction to execute it.
     */
    event RentalSafeDeployment(address safe, address[] owners, uint256 threshold);

    /////////////////////////////////////////////////////////////////////////////////
    //                            Payment Escrow Module                            //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Emitted when a fee is taken.
     *
     * @param token     Token address that the fee is denominated in.
     * @param amount    Amount of the fee taken.
     */
    event FeeTaken(address token, uint256 amount);

    /////////////////////////////////////////////////////////////////////////////////
    //                                  Kernel                                     //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Emitted when the permissions change for a policy. This occurs either when
     *      the policy has been activated or when it has been deactivated.
     *
     * @param keycode_      Keycode representing a module.
     * @param policy_       Address of the policy contract.
     * @param funcSelector_ Function selector of the module.
     * @param granted_      Whether permission to access has been granted or revoked.
     */
    event PermissionsUpdated(
        Keycode indexed keycode_,
        Policy indexed policy_,
        bytes4 funcSelector_,
        bool granted_
    );

    /**
     * @dev Emitted when an address has been granted a role.
     *
     * @param role_ The role being granted.
     * @param addr_ The address receiving the role.
     */
    event RoleGranted(Role indexed role_, address indexed addr_);

    /**
     * @dev Emitted when an address has a role revoked from it.
     *
     * @param role_ The role being revoked.
     * @param addr_ The address which has its role revoked.
     */
    event RoleRevoked(Role indexed role_, address indexed addr_);

    /**
     * @dev Emitted when an action has been executed on the kernel.
     *
     * @param action_ The action which was executed.
     * @param target_ The target address for the action.
     */
    event ActionExecuted(Actions indexed action_, address indexed target_);
}
