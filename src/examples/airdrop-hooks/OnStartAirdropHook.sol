// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IHook} from "@src/interfaces/IHook.sol";
import {Game} from "@src/examples/restricted-selector/Game.sol";

import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";

contract OnStartAirdropHook is IHook {
    // privileged policy contracts
    address public createPolicy;

    // Token that can only be rented with this hook
    address public rentedToken;

    // Token to mint when a rental starts
    address public tokenToMint;

    constructor(address _createPolicy, address _rentedToken, address _tokenToMint) {
        createPolicy = _createPolicy;
        rentedToken = _rentedToken;
        tokenToMint = _tokenToMint;
    }

    modifier onlyCreatePolicy() {
        require(msg.sender == createPolicy, "not callable unless create policy");
        _;
    }

    modifier onlySupportedTokens(address token) {
        require(token == rentedToken, "token is not supported");
        _;
    }

    // hook handler for when a rental has started
    function onStart(
        address safe,
        address token,
        uint256,
        uint256,
        bytes memory
    ) external onlyCreatePolicy onlySupportedTokens(token) {
        // mint the the token for creating a new rental
        MockERC721(tokenToMint).mint(safe);
    }

    // This function will not be used in this hook, so it is unimplemented
    function onStop(
        address safe,
        address token,
        uint256 identifier,
        uint256,
        bytes memory
    ) external view {}

    // This function will not be used in this hook, so it is unimplemented
    function onTransaction(
        address safe,
        address to,
        uint256,
        bytes memory data
    ) external view {}
}
