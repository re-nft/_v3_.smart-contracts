// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";
import {MockERC20} from "@test/mocks/tokens/standard/MockERC20.sol";
import {MockERC1155} from "@test/mocks/tokens/standard/MockERC1155.sol";

contract MockTokenSeeder {
    MockERC721 public mock721;
    MockERC20 public mock20;
    MockERC1155 public mock1155;

    constructor() {
        mock721 = new MockERC721();
        mock20 = new MockERC20();
        mock1155 = new MockERC1155();
    }

    function seed721(address recipient, uint256 amount) public {
        for (uint256 i = 0; i < amount; i++) {
            mock721.mint(recipient);
        }
    }

    function seed20(address recipient, uint256 amount) public {
        mock20.mint(recipient, amount);
    }

    function seed1155(address recipient, uint256 amount) public {
        mock1155.mint(recipient, amount);
    }

    function seed1155Batch(
        address recipient,
        uint256 amount,
        uint256 numberOfIds
    ) public {
        mock1155.mintBatch(recipient, amount, numberOfIds);
    }
}
