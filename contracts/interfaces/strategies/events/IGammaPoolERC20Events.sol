// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title GammaPool ERC20 Events
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Events that should be emitted by all strategy implementations (root of all strategy events interfaces)
interface IGammaPoolERC20Events {
    /// @dev Emitted when `amount` GS LP tokens are moved from account `from` to account `to`.
    /// @param from - address sending GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @param amount - amount of GS LP tokens being sent
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @dev Emitted when the allowance of a `spender` for an `owner` is set by a call to approve function. `amount` is the new allowance.
    /// @param owner - address which owns the GS LP tokens spender is being given permission to spend
    /// @param spender - address given permission to spend owner's GS LP tokens
    /// @param amount - amount of GS LP tokens spender is given permission to spend
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}
