// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Update the asset whitelist
contract UpdateAssetWhitelist is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // Set the asset whitelist
        _updateAssetWhitelist(config.assetWhitelist());

        // display banners
        _displayChainInfo();

        // display asset whitelist banner
        _displayAssetWhitelistBanner();
    }
}
