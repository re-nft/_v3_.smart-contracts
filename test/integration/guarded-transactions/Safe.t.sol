// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {SafeUtils} from "@test/utils/GnosisSafeUtils.sol";

contract GuardedTransactions_Safe_Integration_Test is BaseTest {
    // Tests that ETH can be successfully transferred out of a rental safe.
    function test_Success_TransferETH() public {
        // deal some ETH to the rental safe
        vm.deal(address(alice.safe), 1 ether);

        // Sign the calldata to transfer ETH to bob
        bytes memory signature = SafeUtils.signTransactionWithValue({
            safe: address(alice.safe),
            ownerPrivateKey: alice.privateKey,
            to: address(bob.safe),
            value: 1 ether,
            transaction: bytes("")
        });

        // Expect the transaction to execute successfully
        SafeUtils.executeTransactionWithValue({
            safe: address(alice.safe),
            to: address(bob.safe),
            value: 1 ether,
            transaction: bytes(""),
            signature: signature
        });

        // assert the ETH was transferred
        assertEq(address(alice.safe).balance, 0 ether);
        assertEq(address(bob.safe).balance, 1 ether);
    }
}
