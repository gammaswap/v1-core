// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../storage/AppStorage.sol";
import "../interfaces/strategies/events/IGammaPoolERC20Events.sol";

/// @title ERC20 (GS LP) implementation of GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev The root contract in GammaPool inheritance hierarchy. Inherits AppStorage contract to implement App Storage pattern
abstract contract GammaPoolERC20 is IGammaPoolERC20Events, AppStorage {

    error ERC20Transfer();
    error ERC20Allowance();

    /// @return name - name of the token.
    string public constant name = 'GammaSwap V1';

    /// @return symbol - token symbol
    string public constant symbol = 'GS-V1';

    /// @return decimals - number of decimals used to get the user representation of GS LP token numbers.
    uint8 public constant decimals = 18;

    /// @return totalSupply - amount of GS LP tokens in existence.
    function totalSupply() public virtual view returns (uint256) {
        return s.totalSupply;
    }

    /// @dev Returns the amount of GS LP tokens owned by `account`.
    /// @param account - address whose GS LP token balance is being checked
    /// @return balance - amount of GS LP tokens held by account address
    function balanceOf(address account) external virtual view returns (uint256) {
        return s.balanceOf[account];
    }

    /// @dev Returns the remaining number of GS LP tokens that `spender` will be allowed to spend on behalf of `owner` through a transferFrom function call. Zero by default.
    /// @param owner - address which owns the GS LP tokens spender is being given permission to spend
    /// @param spender - address given permission to spend owner's GS LP tokens
    /// @return allowance - amount of GS LP tokens belonging to owner that spender is allowed to spend, changes with transferFrom or approve function calls
    function allowance(address owner, address spender) external virtual view returns (uint256) {
        return s.allowance[owner][spender];
    }

    /// @dev Moves `amount` of GS LP tokens from `from` to `to`.
    /// @param from - address sending GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @param amount - amount of GS LP tokens being sent
    function _transfer(address from, address to, uint256 amount) internal virtual {
        uint256 currentBalance = s.balanceOf[from];
        if(currentBalance < amount) revert ERC20Transfer(); // insufficient balance

        unchecked{
            s.balanceOf[from] = currentBalance - amount;
        }
        s.balanceOf[to] = s.balanceOf[to] + amount;
        emit Transfer(from, to, amount);
    }

    /// @dev Sets `amount` as the allowance of `spender` over the caller's GS LP tokens.
    /// @param spender - address given permission to spend caller's GS LP tokens
    /// @param amount - amount of GS LP tokens spender is given permission to spend
    /// @return bool - true if operation succeeded
    function approve(address spender, uint256 amount) external virtual returns (bool) {
        s.allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @dev Moves `amount` GS LP tokens from the caller's account to `to`.
    /// @param to - address receiving caller's GS LP tokens
    /// @param amount - amount of GS LP tokens caller is sending
    /// @return bool - true if operation succeeded
    function transfer(address to, uint256 amount) external virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Moves `amount` GS LP tokens from `from` to `to` using the allowance mechanism. `amount` is then deducted from the caller's allowance.
    /// @param from - address sending GS LP tokens (not necessarily caller's address)
    /// @param to - address receiving GS LP tokens
    /// @param amount - amount of GS LP tokens being sent
    /// @return bool - true if operation succeeded
    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        uint256 currentAllowance = s.allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) { // is allowance set to max uint256, then never decrease allowance
            if(currentAllowance < amount) revert ERC20Allowance(); // revert if trying to send more than allowance

            unchecked {
                s.allowance[from][msg.sender] = currentAllowance - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

}
