// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";

import {SafeL2} from "@safe-contracts/SafeL2.sol";
import {SafeProxyFactory} from "@safe-contracts/proxies/SafeProxyFactory.sol";
import {TokenCallbackHandler} from "@safe-contracts/handler/TokenCallbackHandler.sol";

// Deploys all Gnosis Safe protocol contracts
contract External_Safe is Test {
    SafeL2 public safeSingleton;
    SafeProxyFactory public safeProxyFactory;

    function setUp() public virtual {
        // Deploy safe singleton contract
        safeSingleton = new SafeL2();

        // Deploy safe proxy factory
        safeProxyFactory = new SafeProxyFactory();

        // Label the contracts
        vm.label(address(safeSingleton), "SafeSingleton");
        vm.label(address(safeProxyFactory), "SafeProxyFactory");
    }
}
