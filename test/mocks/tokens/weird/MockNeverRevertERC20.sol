// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

// This mock ERC20 will never revert on `transfer` and `transferFrom`, even if
// the tokens fail to send. A false boolean is sent to the caller instead
contract MockNeverRevertERC20 is ERC20 {
    constructor() ERC20("MockNeverRevertERC20", "M_NR_ERC20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public {
        _burn(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}
