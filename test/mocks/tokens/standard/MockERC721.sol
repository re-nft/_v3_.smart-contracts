// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC1271} from "@openzeppelin-contracts/interfaces/IERC1271.sol";
import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {
    ERC721Burnable
} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract MockERC721 is ERC721Burnable {
    uint256 private _tokenIds;
    string private _tokenURI;

    bytes32 private _nameHash;
    bytes32 private _versionHash;

    mapping(uint256 tokenId => uint256 nonce) public tokenIdNonces;

    // keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    constructor() payable ERC721("MockERC721", "MERC721") {
        // give the tokens a default token URI
        _tokenURI = "ipfs://QmaWwYXk4WwAX6kMRzbQfhrit2mkiw8FYixo2ChbEwwHnh/";

        // set values for permit()
        _nameHash = keccak256(bytes("MockERC721"));
        _versionHash = keccak256(bytes("1.0"));
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

    function _getAndIncrementNonce(uint256 tokenId) internal returns (uint256) {
        // Get the nonce
        uint256 tokenIdNonce = tokenIdNonces[tokenId];

        // Increment it
        tokenIdNonces[tokenId] += 1;

        // Return the old nonce
        return tokenIdNonce;
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    _nameHash,
                    _versionHash,
                    block.chainid,
                    address(this)
                )
            );
    }

    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        spender,
                        tokenId,
                        _getAndIncrementNonce(tokenId),
                        deadline
                    )
                )
            )
        );
        address owner = ownerOf(tokenId);
        require(spender != owner, "ERC721Permit: approval to current owner");

        if (_isContract(owner)) {
            require(
                IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) ==
                    0x1626ba7e,
                "Unauthorized"
            );
        } else {
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress != address(0), "Invalid signature");
            require(recoveredAddress == owner, "Unauthorized");
        }

        _approve(spender, tokenId);
    }
}
