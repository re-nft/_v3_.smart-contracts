// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";

// This mock ERC721 will always revert on `transferFrom` and `safeTransferFrom`
contract MockAlwaysRevertERC721 is ERC721 {
    uint256 private _tokenIds;

    constructor() payable ERC721("MockAlwaysRevertERC721", "M_AR_ERC721") {}

    function totalSupply() public view returns (uint256) {
        return _tokenIds;
    }

    function mint(address to) public {
        _mint(to, _tokenIds);
        _tokenIds++;
    }

    function burn(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: burn caller is not owner nor approved"
        );
        _burn(tokenId);
    }

    function transferFrom(address, address, uint256) public pure override {
        require(false, "transferFrom() revert");
    }

    function safeTransferFrom(address, address, uint256) public pure override {
        require(false, "safeTransferFrom() revert");
    }
}
