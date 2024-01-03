// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {Enum} from "@safe-contracts/common/Enum.sol";

import {ISafe} from "@src/interfaces/ISafe.sol";

library SafeUtils {
    address private constant VM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
    Vm private constant vm = Vm(VM_ADDRESS);

    /////////////////////////////////////////////////////////////////////////////////
    //                             Private Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    function _executeTransaction(
        address safe,
        Enum.Operation operation,
        address to,
        bytes memory transaction,
        bytes memory signature,
        bytes memory expectedError
    ) private {
        // expect an error if error data was provided
        if (expectedError.length != 0) {
            vm.expectRevert(expectedError);
        }

        // execute the transaction
        ISafe(safe).execTransaction(
            to,
            0 ether,
            transaction,
            operation,
            0 ether,
            0 ether,
            0 ether,
            address(0),
            payable(address(0)),
            signature
        );
    }

    // Takes a transaction to execute, hashes it according to EIP-712 for the safe,
    // and signs with owner private key
    function _signTransaction(
        address safe,
        Enum.Operation operation,
        uint256 ownerPrivateKey,
        address to,
        bytes memory transaction
    ) private view returns (bytes memory transactionSignature) {
        // get the safe nonce
        uint256 nonce = ISafe(safe).nonce();

        // get the eip712 compatible transaction hash that the safe owner will sign
        bytes32 transactionHash = ISafe(safe).getTransactionHash(
            to,
            0 ether,
            transaction,
            operation,
            0 ether,
            0 ether,
            0 ether,
            address(0),
            payable(address(0)),
            nonce
        );

        // sign the transaction
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, transactionHash);
        transactionSignature = abi.encodePacked(r, s, v);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    // Builds the safe signatures when there are multiple signers
    function buildSafeSignatures(
        bytes memory privateKeys,
        bytes32 transactionHash,
        uint256 numKeys
    ) internal pure returns (bytes memory safeSignatures) {
        uint256 i;
        for (i = 0; i < numKeys; i++) {
            uint256 privateKey;
            assembly {
                let keyPosition := mul(0x20, i)
                privateKey := mload(add(privateKeys, add(keyPosition, 0x20)))
            }

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, transactionHash);
            safeSignatures = abi.encodePacked(safeSignatures, abi.encodePacked(r, s, v));
        }
    }

    // Takes a call transaction to execute, hashes it according to EIP-712 for the safe,
    // and signs with owner private key
    function signTransaction(
        address safe,
        uint256 ownerPrivateKey,
        address to,
        bytes memory transaction
    ) internal view returns (bytes memory transactionSignature) {
        transactionSignature = _signTransaction(
            safe,
            Enum.Operation.Call,
            ownerPrivateKey,
            to,
            transaction
        );
    }

    // Takes a delegate call transaction to execute, hashes it according to EIP-712 for the safe,
    // and signs with owner private key
    function signDelegateTransaction(
        address safe,
        uint256 ownerPrivateKey,
        address to,
        bytes memory transaction
    ) internal view returns (bytes memory transactionSignature) {
        transactionSignature = _signTransaction(
            safe,
            Enum.Operation.DelegateCall,
            ownerPrivateKey,
            to,
            transaction
        );
    }

    // Helper function for executiong a call transaction
    function executeTransaction(
        address safe,
        address to,
        bytes memory transaction,
        bytes memory signature
    ) internal {
        _executeTransaction(
            safe,
            Enum.Operation.Call,
            to,
            transaction,
            signature,
            bytes("")
        );
    }

    // Helper function for executing a call transaction that accepts an expected error
    function executeTransactionWithError(
        address safe,
        address to,
        bytes memory transaction,
        bytes memory signature,
        bytes memory expectedError
    ) internal {
        _executeTransaction(
            safe,
            Enum.Operation.Call,
            to,
            transaction,
            signature,
            expectedError
        );
    }

    // Helper function for executiong a delegate call transaction
    function executeDelegateTransaction(
        address safe,
        address to,
        bytes memory transaction,
        bytes memory signature
    ) internal {
        _executeTransaction(
            safe,
            Enum.Operation.DelegateCall,
            to,
            transaction,
            signature,
            bytes("")
        );
    }

    // Helper function for executing a delegate call transaction that accepts an expected error
    function executeDelegateTransactionWithError(
        address safe,
        address to,
        bytes memory transaction,
        bytes memory signature,
        bytes memory expectedError
    ) internal {
        _executeTransaction(
            safe,
            Enum.Operation.DelegateCall,
            to,
            transaction,
            signature,
            expectedError
        );
    }
}
