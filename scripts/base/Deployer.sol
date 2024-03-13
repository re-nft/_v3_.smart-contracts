// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "@forge-std/Script.sol";

import {Config} from "@scripts/base/Config.sol";

// Loads environment variables (if present) and sets up configuration.
contract Deployer is Script {
    // Configuration contract for the deployment
    Config internal config;

    // Chain to deploy to
    string internal chain;

    // a unique protocol version used to generate a salt
    bytes12 internal protocolVersion;

    // Deployer address
    address internal deployer;

    function run(string memory _chain) public virtual {
        // fetch the chain from the environment variables
        chain = _chain;

        // fetch the deployer private key
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY_DEPLOYER", uint256(0));

        // ensure a chain to deploy on was provided
        require(bytes(chain).length > 0, "No chain was provided in script call.");

        // ensure a private key was provided
        require(
            deployerPrivateKey > 0,
            "No deployer private key was provided (make sure $PRIVATE_KEY_DEPLOYER is set)"
        );

        // get the path to the config file
        string memory path = string.concat(
            vm.projectRoot(),
            "/scripts/config/",
            chain,
            ".json"
        );

        // create the configuration for the deployment
        config = new Config(path);

        // set the deployer address
        deployer = vm.rememberKey(deployerPrivateKey);

        // create the protocol version byte data
        protocolVersion = bytes12(
            keccak256(abi.encode(config.majorVersion(), config.minorVersion()))
        );
    }

    // Modifier to broadcast transactions
    modifier broadcast() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
