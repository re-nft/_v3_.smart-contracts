// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IHook} from "@src/interfaces/IHook.sol";
import {Game} from "@src/examples/restricted-selector/Game.sol";

contract RestrictedSelectorHook is IHook {
    // privileged policy contracts
    address public createPolicy;
    address public stopPolicy;

    // target contract that will be active for this hook
    address public target;

    // token which, when held, restricts functionality of the wallet
    address public restrictedToken;

    // maps a token ID to an allowlisted function selector bitmap
    mapping(uint256 tokenId => uint256 bitmap) public functionSelectorBitmap;

    // tracks how many rentals a safe actively has
    mapping(address renter => uint256 count) public activeRentals;

    constructor(
        address _createPolicy,
        address _stopPolicy,
        address _target,
        address _restrictedToken
    ) {
        createPolicy = _createPolicy;
        stopPolicy = _stopPolicy;
        target = _target;
        restrictedToken = _restrictedToken;
    }

    modifier onlyCreatePolicy() {
        require(msg.sender == createPolicy, "not callable unless create policy");
        _;
    }

    modifier onlyStopPolicy() {
        require(msg.sender == stopPolicy, "not callable unless stop policy");
        _;
    }

    modifier onlySupportedTokens(address token) {
        require(token == restrictedToken, "token is not supported");
        _;
    }

    function _isFunctionSelectorAllowed(
        uint256 tokenId,
        uint256 selectorPosition
    ) internal view returns (bool) {
        // There are 256 bits in a uint256, so there can only be 256 positions for a function selector
        require(selectorPosition < 256, "bitmap index out of bounds");

        // shift a 1 to the bit that we're interested in
        uint256 mask = 1 << selectorPosition;

        // perform an AND operation on the mask and the bitmap. Check that it comes back as 0, meaning
        // it wasn't declared off-limits
        return (functionSelectorBitmap[tokenId] & mask) == 0;
    }

    // hook handler for when a rental has started
    function onStart(
        address safe,
        address token,
        uint256 identifier,
        uint256,
        bytes memory data
    ) external onlyCreatePolicy onlySupportedTokens(token) {
        // decode extra data as a bitmap
        uint256 bitmap = abi.decode(data, (uint256));

        // add bitmap entry for the token Id
        functionSelectorBitmap[identifier] = bitmap;

        // increment the total number of active rentals for the sender
        activeRentals[safe]++;
    }

    // hook handler for when a rental has stopped
    function onStop(
        address safe,
        address token,
        uint256 identifier,
        uint256,
        bytes memory
    ) external onlyStopPolicy onlySupportedTokens(token) {
        // remove token from mapping
        delete functionSelectorBitmap[identifier];

        // decrement the total number of active rentals for the sender
        activeRentals[safe]--;
    }

    // Triggers on each transaction from a rental safe
    function onTransaction(
        address safe,
        address to,
        uint256,
        bytes memory data
    ) external view {
        // make sure only the target contract transactions are being checked
        require(to == target, "only checking transactions to the Game contract");

        // load in the function selector
        bytes4 selector;
        assembly {
            // offset the data by 0x20 because the first 32 bytes just contains the length
            selector := mload(add(data, 0x20))
        }

        // function train(uint256 tokenId)
        if (selector == Game.train.selector) {
            uint256 tokenId;
            assembly {
                tokenId := mload(add(data, 0x24))
            }
            // perform bitmap check here for the token id and function selector 0
            require(
                _isFunctionSelectorAllowed(tokenId, 0),
                "train() not callable for this token Id"
            );
        }
        // function retire(uint256 tokenId)
        else if (selector == Game.retire.selector) {
            uint256 tokenId;
            assembly {
                tokenId := mload(add(data, 0x24))
            }
            // perform bitmap check here using token id and function selector 1
            require(
                _isFunctionSelectorAllowed(tokenId, 1),
                "retire() not callable for this token Id"
            );
        }
        // function changeTeam(Team newTeam)
        else if (selector == Game.changeTeam.selector) {
            // There is no token Id to check here, so changing teams is disabled by default,
            // but only if the safe has an active rental with a GameToken.
            require(
                activeRentals[safe] == 0,
                "changeTeam() not callable when holding a GameToken rental"
            );
        }
    }
}
