// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

// This mock ERC20 will always revert on `transfer` and `transferFrom`
contract MockAlwaysRevertERC20 is ERC20 {
    constructor() ERC20("MockAlwaysRevertERC20", "M_AR_ERC20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public {
        _burn(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        require(false, "transfer() revert");

        return false;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override returns (bool) {
        require(false, "transferFrom() revert");

        return false;
    }
}
