// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

/**
 * @title Proxiable
 * @notice Adheres to the Universal Upgradeable Proxy Standard (ERC-1822). This contract
 *         is meant to be inherited by the logic implementation. Proxiable is in charge
 *         of implementations for upgrading the proxy, and freezing the proxy so that it
 *         can no longer be upgraded.
 */
contract Proxiable {
    // Whether this proxy has been initialized.
    bool public initialized;

    // Store the implementation contract address on deployment.
    address private immutable _self = address(this);

    // This is keccak256("eip1967.proxy.implementation") subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // This is keccak256("proxiable.freeze.slot") subtracted by 1.
    bytes32 internal constant FREEZE_SLOT =
        0xb1c430d6858c7d4aa68247671513746f811bc8a08b57cb1afc031d4c886174dc;

    /////////////////////////////////////////////////////////////////////////////////
    //                                  Modifiers                                  //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Modifier which only allows a call to be made if it is via the proxy.
     */
    modifier onlyByProxy() {
        // Makes sure the contract storage is not from address(this), and that the
        // implementation address stored in the proxy is the same as the original
        // stored address from the implementation contract.
        if (address(this) == _self || _getImplementation() != _self) {
            revert Errors.Proxy_OnlyCallByProxy();
        }

        _;
    }

    /**
     * @dev Modifier which only allows a call if the proxy is uninitialized.
     */
    modifier onlyUninitialized() {
        if (initialized) revert Errors.Proxy_AlreadyInitialized();
        _;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Checks if the proxy contract is frozen.
     *
     * @return isFrozen Whether the proxy is frozen.
     */
    function _isFrozen() internal view returns (bool isFrozen) {
        assembly {
            // Load the implementation contract.
            isFrozen := sload(FREEZE_SLOT)
        }
    }

    /**
     * @dev Gets the implementation address.
     *
     * @return implementation Address of the implementation.
     */
    function _getImplementation() internal view returns (address implementation) {
        assembly {
            // Load the implementation contract.
            implementation := sload(IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Upgrades the implementation contract.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _upgrade(address newImplementation) internal {
        // Assert that the contract has not been frozen.
        if (_isFrozen()) {
            revert Errors.Proxy_Frozen();
        }

        // Assert that the contract to upgrade to is also a `Proxiable`.
        try Proxiable(newImplementation).proxiableUUID() returns (bytes32 uuid) {
            if (IMPLEMENTATION_SLOT != uuid)
                revert Errors.Proxy_NotCompatible(newImplementation);
        } catch {
            revert Errors.Proxy_NotCompatible(newImplementation);
        }

        // Update the implementation address.
        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    /**
     * @dev Freezes the contract. Warning: This permanently prevents future upgrades.
     */
    function _freeze() internal {
        // Update the freeze slot address.
        assembly {
            sstore(FREEZE_SLOT, 1)
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns the ID of this `Proxiable` contract.
     *
     * @return ID of the proxiable contract.
     */
    function proxiableUUID() public pure returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }
}
