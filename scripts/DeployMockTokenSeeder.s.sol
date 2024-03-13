// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

import {MockTokenSeeder} from "@test/mocks/tokens/MockTokenSeeder.sol";

// Deploys a mock token seeder for testing
contract DeployMockTokenSeeder is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        vm.startBroadcast(deployer);

        // deploy mock token seeder
        MockTokenSeeder mockTokenSeeder = new MockTokenSeeder();

        vm.stopBroadcast();

        // display banners
        _displayChainInfo();
        _displayProtocolAddressesBanner();

        // output addresses
        console2.log("Mock Token Seeder Address:  %s", address(mockTokenSeeder));
        console2.log(
            "Mock ERC721 Address:        %s",
            address(mockTokenSeeder.mock721())
        );
        console2.log("Mock ERC20 Address:         %s", address(mockTokenSeeder.mock20()));
        console2.log(
            "Mock ERC1155 Address:       %s",
            address(mockTokenSeeder.mock1155())
        );

        // display JSON reminder
        _displayUpdatedAddressWarning();
    }
}
