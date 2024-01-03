// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IHook} from "@src/interfaces/IHook.sol";

contract WhitelistedFulfillmentHook is IHook {
    // hook handler for when a rental has started
    function onStart(
        address safe,
        address,
        uint256,
        uint256,
        bytes memory data
    ) external pure {
        // decode the data as an array of whitelisted addresses
        address[] memory whitelist = abi.decode(data, (address[]));

        // check to see if the rental wallet exists in the whitelist
        for (uint256 i = 0; i < whitelist.length; ++i) {
            if (safe == whitelist[i]) return;
        }

        revert("rental wallet is not authorized for this order");
    }

    // This function will not be used in this hook, so it is unimplemented
    function onStop(
        address safe,
        address token,
        uint256 identifier,
        uint256,
        bytes memory
    ) external {}

    // This function will not be used in this hook, so it is unimplemented
    function onTransaction(
        address safe,
        address to,
        uint256 value,
        bytes memory data
    ) external view {}
}
