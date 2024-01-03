// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin-contracts/utils/Context.sol";
import {IERC20Errors} from "@openzeppelin-contracts/interfaces/draft-IERC6093.sol";

// This is a modified Openzeppelin implementation of an ERC20 token. It was modified
// to not return booleans on calls such `approve`, `transfer`, `transferFrom`, etc, to
// accurately mock ERC20 tokens like USDT.
contract MockWithoutReturnsERC20 is Context, IERC20Errors {
    error ERC20FailedDecreaseAllowance(
        address spender,
        uint256 currentAllowance,
        uint256 requestedDecrease
    );

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    function name() public pure returns (string memory) {
        return "MockWithoutReturnsERC20";
    }

    function symbol() public pure returns (string memory) {
        return "M_WR_ERC20";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public virtual returns (uint256) {
        return _balances[account];
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public {
        _burn(to, amount);
    }

    function transfer(address to, uint256 value) public {
        address owner = _msgSender();
        _transfer(owner, to, value);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public {
        address owner = _msgSender();
        _approve(owner, spender, value);
    }

    function transferFrom(address from, address to, uint256 value) public {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
    }

    function increaseAllowance(address spender, uint256 addedValue) public {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
    }

    function decreaseAllowance(address spender, uint256 requestedDecrease) public {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < requestedDecrease) {
            revert ERC20FailedDecreaseAllowance(
                spender,
                currentAllowance,
                requestedDecrease
            );
        }
        unchecked {
            _approve(owner, spender, currentAllowance - requestedDecrease);
        }
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool) internal {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
