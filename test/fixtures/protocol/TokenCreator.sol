// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {LibString} from "@solady/utils/LibString.sol";

import {MockERC20} from "@test/mocks/tokens/standard/MockERC20.sol";
import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";
import {MockERC1155} from "@test/mocks/tokens/standard/MockERC1155.sol";
import {BaseExternal} from "@test/fixtures/external/BaseExternal.sol";

// Creates mock tokens to interact with the V3 protocol
contract TokenCreator is BaseExternal {
    // Mock tokens for testing
    MockERC20[] public erc20s;
    MockERC721[] public erc721s;
    MockERC1155[] public erc1155s;

    function setUp() public virtual override {
        super.setUp();

        // deploy 3 erc20 tokens, 3 erc721 tokens, and 3 erc1155 tokens
        _deployTokens(3);
    }

    function _deployTokens(uint256 numTokens) internal {
        for (uint256 i; i < numTokens; i++) {
            _deployErc20Token();
            _deployErc721Token();
            _deployErc1155Token();
        }
    }

    function _deployErc20Token() internal returns (uint256 i) {
        // save the token's index
        i = erc20s.length;

        // deploy the mock token
        MockERC20 token = new MockERC20();

        // push the token to the array of mocks
        erc20s.push(token);

        // set the token label with the index
        vm.label(address(token), string.concat("MERC20_", LibString.toString(i)));
    }

    function _deployErc721Token() internal returns (uint256 i) {
        // save the token's index
        i = erc721s.length;

        // deploy the mock token
        MockERC721 token = new MockERC721();

        // push the token to the array of mocks
        erc721s.push(token);

        // set the token label with the index
        vm.label(address(token), string.concat("MERC721_", LibString.toString(i)));
    }

    function _deployErc1155Token() internal returns (uint256 i) {
        // save the token's index
        i = erc1155s.length;

        // deploy the mock token
        MockERC1155 token = new MockERC1155();

        // push the token to the array of mocks
        erc1155s.push(token);

        // set the token label with the index
        vm.label(address(token), string.concat("MERC1155_", LibString.toString(i)));
    }
}
