// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin-contracts/interfaces/IERC721.sol";

enum Team {
    NO_TEAM,
    RED,
    BLUE,
    GREEN
}

/// This contract represents a game contract. GameToken can be used to interact with it.
/// There are functions that:
/// - do not require holding a GameToken to interact
/// - operate on all game tokens in the wallet
contract Game {
    // the game token
    address public gameToken;

    // maps a token to its current level
    mapping(uint256 tokenId => uint256 level) private _levelCounter;

    // maps a token to its retiree status
    mapping(uint256 tokenId => bool retired) private _retiredTokens;

    // maps an EOA or contract address to a team
    mapping(address holder => Team team) private _teamMembership;

    //////// Constructor ////////

    constructor(address _gameToken) {
        gameToken = _gameToken;
    }

    //////// Modifiers ////////

    modifier onlyTokenOwner(uint256 tokenId) {
        require(msg.sender == IERC721(gameToken).ownerOf(tokenId), "not owner");
        _;
    }

    modifier onlyActive(uint256 tokenId) {
        require(!_retiredTokens[tokenId], "token is retired");
        _;
    }

    //////// View methods ////////

    // determines the team of the token
    function teamOf(uint256 tokenId) public view returns (Team) {
        address holder = IERC721(gameToken).ownerOf(tokenId);

        return _teamMembership[holder];
    }

    function levelOf(uint256 tokenId) external view returns (uint256) {
        return _levelCounter[tokenId];
    }

    function isRetired(uint256 tokenId) external view returns (bool) {
        return _retiredTokens[tokenId];
    }

    //////// External methods ////////

    // increase the abilities of the token
    function train(uint256 tokenId) external onlyTokenOwner(tokenId) onlyActive(tokenId) {
        _levelCounter[tokenId]++;
    }

    // Prevents the token from competing in the game ever again.
    // This action cannot be undone.
    function retire(uint256 tokenId) external onlyTokenOwner(tokenId) {
        _retiredTokens[tokenId] = true;
    }

    // converts all tokens held by the sender to a different team
    function changeTeam(Team newTeam) external {
        require(newTeam != _teamMembership[msg.sender], "cant change to same team");
        _teamMembership[msg.sender] = newTeam;
    }
}
