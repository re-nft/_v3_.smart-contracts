// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {Actions} from "@src/Kernel.sol";

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

    // Tests that the Guard Policy can be deactivated by the kernel, preventing
    // any movement of assets from the safe until either the Guard Policy is
    // activated, or the owner of the rental safe upgrades to a newer Guard Policy.
    function test_Success_GuardCanBeDeactivated() public {
        // mint token to the rental wallet
        erc721s[0].mint(address(alice.safe), 5);

        // assert that the token exists in the safe
        assertEq(erc721s[0].ownerOf(5), address(alice.safe));

        // create the `transferFrom(address,address,uint256)` calldata
        bytes memory transferFromCalldata = abi.encodeWithSelector(
            ERC721.transferFrom.selector,
            address(alice.safe),
            bob.addr,
            5
        );

        // Sign the calldata
        bytes memory signature = SafeUtils.signTransaction({
            safe: address(alice.safe),
            ownerPrivateKey: alice.privateKey,
            to: address(erc721s[0]),
            transaction: transferFromCalldata
        });

        // Disable the guard policy
        vm.prank(deployer.addr);
        kernel.executeAction(Actions.DeactivatePolicy, address(guard));

        // Expect the transaction to revert because the guard is deactivated
        SafeUtils.executeTransactionWithError({
            safe: address(alice.safe),
            to: address(erc721s[0]),
            transaction: transferFromCalldata,
            signature: signature,
            expectedError: abi.encodeWithSelector(Errors.GuardPolicy_Deactivated.selector)
        });

        // Reactivate the guard policy
        vm.prank(deployer.addr);
        kernel.executeAction(Actions.ActivatePolicy, address(guard));

        // Expect the transaction to execute successfully
        SafeUtils.executeTransaction({
            safe: address(alice.safe),
            to: address(erc721s[0]),
            transaction: transferFromCalldata,
            signature: signature
        });

        // assert that the token was transferred
        assertEq(erc721s[0].ownerOf(5), bob.addr);
    }
}
