// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Deploys the entire protocol
contract DeployProtocol is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // deploy the create2 deployer
        _deployCreate2Deployer();

        // generate the salt
        bytes32 salt = _generateSaltWithSender(deployer, protocolVersion);

        // deploy the conduit controller
        _deployConduitController();

        // deploy seaport
        _deploySeaport();

        // deploy conduit
        _deployConduit(salt);

        // deploy the kernel
        _deployKernel(salt);

        // deploy the modules
        _deployStorageModule(salt);
        _deployPaymentEscrowModule(salt);

        // set up the modules
        _setUpModule(address(STORE));
        _setUpModule(address(ESCRW));

        // deploy the policies
        _deployAdminPolicy(salt);
        _deployCreatePolicy(salt);
        _deployStopPolicy(salt);
        _deployGuardPolicy(salt);
        _deployFallbackPolicy(salt);
        _deployFactoryPolicy(
            salt,
            address(fallbackPolicy),
            config.safeProxyFactory(),
            config.safeSingleton()
        );

        // set up the policies
        _setUpPolicy(address(factory));
        _setUpPolicy(address(admin));
        _setUpPolicy(address(stop));
        _setUpPolicy(address(guard));
        _setUpPolicy(address(create));
        _setUpPolicy(address(fallbackPolicy));

        // Grant role for privileged access
        _grantRole("ADMIN_ADMIN", deployer);
        _grantRole("STOP_ADMIN", deployer);
        _grantRole("GUARD_ADMIN", deployer);
        _grantRole("CREATE_SIGNER", config.serverSideSigner());
        _grantRole("SEAPORT", address(seaport));

        // Set max rent duration
        _setMaxRentDuration(30 days);

        // Set max offer items
        _setMaxOfferItems(10);

        // Set max consideration items
        _setMaxConsiderationItems(10);

        // Set the asset whitelist
        _updateAssetWhitelist(config.assetWhitelist());

        // Set the payment whitelist
        _updatePaymentWhitelist(config.paymentWhitelist());

        // Display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // Output addresses
        console2.log("Create2 Deployer:     %s", address(create2Deployer));
        console2.log("Kernel:               %s", address(kernel));
        console2.log("STORE Module:         %s", address(STORE));
        console2.log("STORE logic contract: %s", address(STORE_IMPL));
        console2.log("ESCRW Module:         %s", address(ESCRW));
        console2.log("ESCRW logic contract: %s", address(ESCRW_IMPL));
        console2.log("Create Policy:        %s", address(create));
        console2.log("Stop Policy:          %s", address(stop));
        console2.log("Guard Policy:         %s", address(guard));
        console2.log("Admin Policy:         %s", address(admin));
        console2.log("Fallback Policy:      %s", address(fallbackPolicy));
        console2.log("Factory Policy:       %s", address(factory));
        console2.log("Seaport:              %s", address(seaport));
        console2.log("Conduit Controller:   %s", address(conduitController));
        console2.log("Conduit:              %s", address(conduit));
        console2.log("Conduit Key:          %s", _bytes32ToString(conduitKey));
        console2.log("");

        // Display asset whitelist banner
        _displayAssetWhitelistBanner();

        // Display payment whitelist banner
        _displayPaymentWhitelistBanner();

        // Display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
