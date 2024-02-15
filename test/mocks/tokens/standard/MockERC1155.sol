// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import {
    ERC1155Burnable
} from "@openzeppelin-contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";

contract MockERC1155 is ERC1155Burnable {
    using Strings for uint256;

    uint256 private _tokenIds;
    string private _tokenURI;

    // give the token a default token URI
    constructor() payable ERC1155("") {
        // give the tokens a default token URI
        _tokenURI = "ipfs://QmZDtxiJCvxFFAxVBUz1fxq7DUwktsnwNXEA4Jjhxq98Gc/";
    }

    function mint(address to, uint256 amount) public {
        _mint(to, _tokenIds, amount, "");
        _tokenIds++;
    }

    function mint(address to, uint256 id, uint256 amount) public {
        _mint(to, id, amount, "");
        _tokenIds++;
    }

    function mintBatch(address to, uint256 amount, uint256 numberOfIds) public {
        uint256[] memory ids = new uint256[](numberOfIds);
        uint256[] memory amounts = new uint256[](numberOfIds);

        for (uint256 i = 0; i < numberOfIds; i++) {
            ids[i] = _tokenIds + i;
            amounts[i] = amount;
        }

        _mintBatch(to, ids, amounts, "");

        _tokenIds += numberOfIds;
    }

    function setTokenURI(string memory tokenURI) public {
        _tokenURI = tokenURI;
    }

    function uri(uint256 id) public view override returns (string memory) {
        return bytes(_tokenURI).length > 0 ? string.concat(_tokenURI, id.toString()) : "";
    }
}
