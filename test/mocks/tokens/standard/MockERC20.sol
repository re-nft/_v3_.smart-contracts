// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "MERC20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public {
        _burn(to, amount);
    }
}
