// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title Proxy
 * @notice Adheres to the Universal Upgradeable Proxy Standard (ERC-1822). This contract
 *         is in charge of handling delegate calls from external addresses to the
 *         implementation contract.
 */
contract Proxy {
    // This is keccak256("eip1967.proxy.implementation") subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Instantiate this contract with an inital logic implementation and
     *      data to pass on to the implementation.
     *
     * @param _implementation Address of the kernel contract.
     * @param _data           Initialization data to pass on to the
     *                        implementation contract.
     */
    constructor(address _implementation, bytes memory _data) payable {
        // Store the implementation address.
        assembly {
            sstore(IMPLEMENTATION_SLOT, _implementation)
        }

        // Perform the delegate call.
        (bool success, ) = _implementation.delegatecall(_data);

        // Require a successfull transaction.
        require(success, "Construction failed");
    }

    /**
     * @dev Delegates the call to the implementation address.
     */
    function _delegate() internal virtual {
        assembly {
            // Load the implementation contract.
            let implementation := sload(IMPLEMENTATION_SLOT)

            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // Out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            // else, return the data.
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Delegate to implementation contract always.
     */
    fallback() external payable {
        _delegate();
    }

    /**
     * @dev Delegate to implementation contract when ether is received.
     */
    receive() external payable {
        _delegate();
    }
}
