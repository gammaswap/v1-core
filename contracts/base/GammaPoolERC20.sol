// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../libraries/storage/GammaPoolStorage.sol";

abstract contract GammaPoolERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    error ERC20Transfer();
    error ERC20Allowance();

    string public constant name = 'GammaSwap V1';
    string public constant symbol = 'GAMA-V1';
    uint8 public constant decimals = 18;

    function totalSupply() public virtual view returns (uint256) {
        return GammaPoolStorage.erc20().totalSupply;
    }

    function balanceOf(address account) external virtual view returns (uint256) {
        return GammaPoolStorage.erc20().balanceOf[account];
    }

    function allowance(address owner, address spender) external virtual view returns (uint256) {
        return GammaPoolStorage.erc20().allowance[owner][spender];
    }

    function _transfer(GammaPoolStorage.ERC20 storage store, address from, address to, uint value) internal virtual {
        uint256 currentBalance = store.balanceOf[from];
        if(currentBalance < value) {
            revert ERC20Transfer();
        }
        unchecked{
            store.balanceOf[from] = currentBalance - value;
        }
        store.balanceOf[to] = store.balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external virtual returns (bool) {
        GammaPoolStorage.erc20().allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external virtual returns (bool) {
        GammaPoolStorage.ERC20 storage store = GammaPoolStorage.erc20();
        _transfer(store, msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external virtual returns (bool) {
        GammaPoolStorage.ERC20 storage store = GammaPoolStorage.erc20();
        uint256 currentAllowance = store.allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if(currentAllowance < value) {
                revert ERC20Allowance();
            }
            unchecked {
                store.allowance[from][msg.sender] = currentAllowance - value;
            }
        }
        _transfer(store, from, to, value);
        return true;
    }

}
