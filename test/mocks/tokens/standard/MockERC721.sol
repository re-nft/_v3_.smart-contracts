// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {
    ERC721Burnable
} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract MockERC721 is ERC721Burnable {
    uint256 private _tokenIds;
    string private _tokenURI;

    constructor() payable ERC721("MockERC721", "MERC721") {
        // give the tokens a default token URI
        _tokenURI = "ipfs://QmaWwYXk4WwAX6kMRzbQfhrit2mkiw8FYixo2ChbEwwHnh/";
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds;
    }

    function mint(address to) public {
        _mint(to, _tokenIds);
        _tokenIds++;
    }

    function mint(address to, uint256 id) public {
        _mint(to, id);
        _tokenIds++;
    }

    function setTokenURI(string memory tokenURI) public {
        _tokenURI = tokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenURI;
    }
}
