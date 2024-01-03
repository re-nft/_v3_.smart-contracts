// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

/**
 * @title Create2Deployer
 * @notice Deployment contract that uses the init code and a salt to perform a deployment.
 *         There is added cross-chain safety as well because a particular salt can only be
 *         used if the sender's address is contained within that salt. This prevents a
 *         contract on one chain from being deployed by a non-admin account on
 *         another chain.
 */
contract Create2Deployer {
    // Determine if an address has already been deployed.
    mapping(address => bool) public deployed;

    // Byte used to prevent collision with CREATE.
    bytes1 constant create2_ff = 0xff;

    /**
     * @notice Deploys a contract using the given salt and init code. Prevents
     *         frontrunning of claiming a specific address by asserting that the first
     *         20 bytes of the salt matches the sender. This check is especially useful
     *         if trying to keep the same deployment addresses across chains.
     *
     * @param salt     A unique value which must contain the address of the sender.
     * @param initCode The init code of the contract to deploy.
     *
     * @return deploymentAddress The addres of the deployed contract.
     */
    function deploy(
        bytes32 salt,
        bytes memory initCode
    ) external payable returns (address deploymentAddress) {
        // Ensure the salt is valid for the sender.
        if (address(bytes20(salt)) != msg.sender) {
            revert Errors.Create2Deployer_UnauthorizedSender(msg.sender, salt);
        }

        // Determine the target address for contract deployment.
        address targetDeploymentAddress = getCreate2Address(salt, initCode);

        // Ensure that a contract hasn't been previously deployed to target address.
        if (deployed[targetDeploymentAddress]) {
            revert Errors.Create2Deployer_AlreadyDeployed(targetDeploymentAddress, salt);
        }

        // Prevent redeploys of contracts at the same address.
        deployed[targetDeploymentAddress] = true;

        // Deploy the contract.
        assembly {
            deploymentAddress := create2(
                // ETH value to pass to the call.
                callvalue(),
                // Init code data.
                add(initCode, 0x20),
                // Init code data length.
                mload(initCode),
                // Unique salt value.
                salt
            )
        }

        // Check address against target to ensure that deployment was successful.
        if (deploymentAddress != targetDeploymentAddress) {
            revert Errors.Create2Deployer_MismatchedDeploymentAddress(
                targetDeploymentAddress,
                deploymentAddress
            );
        }
    }

    /**
     * @notice Calculate the target address for contract deployment using the
     *         salt and init code.
     *
     * @param salt     A unique value which must contain the address of the sender.
     * @param initCode The init code of the contract to deploy.
     *
     * @return The address that would be generated from the deployment.
     */
    function getCreate2Address(
        bytes32 salt,
        bytes memory initCode
    ) public view returns (address) {
        // Create the address hash.
        bytes32 addressHash = keccak256(
            abi.encodePacked(create2_ff, address(this), salt, keccak256(initCode))
        );

        // Cast the hash to an address.
        return address(uint160(uint256(addressHash)));
    }

    /**
     * @notice Allows the generation of a salt using the sender address.
     *         This function ties the deployment sendder to the salt of the CREATE2
     *         address so that it cannot be frontrun on a different chain. More details
     *         about this can be found here:
     *         https://github.com/martinetlee/create2-snippets#method-1-mixing-with-salt
     *
     * @param sender The address of the deployer.
     * @param data   The added data to make the salt unique.
     */
    function generateSaltWithSender(
        address sender,
        bytes12 data
    ) public pure returns (bytes32 salt) {
        assembly {
            // Use `or` to combine the bytes20 address and bytes12 data together.
            salt := or(
                // Shift the address 12 bytes to the left.
                shl(0x60, sender),
                // Shift the extra data 20 bytes to the right.
                shr(0xA0, data)
            )
        }
    }
}
