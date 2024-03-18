// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseDeploy} from "@scripts/base/BaseDeploy.sol";

// Update the payment whitelist
contract UpdatePaymentWhitelist is BaseDeploy {
    function run(string memory chain) public override {
        super.run(chain);

        // Set the payment whitelist
        _updatePaymentWhitelist(config.paymentWhitelist());

        // display banners
        _displayChainInfo();

        // display payment whitelist banner
        _displayPaymentWhitelistBanner();
    }
}
