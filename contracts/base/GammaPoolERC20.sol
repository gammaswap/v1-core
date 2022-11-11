// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../libraries/storage/GammaPoolStorage.sol";

abstract contract GammaPoolERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    error ERC20Transfer();
    error ERC20Allowance();

    function name() external virtual view returns (string memory) {
        return GammaPoolStorage.store().name;
    }

    function symbol() external virtual view returns (string memory) {
        return GammaPoolStorage.store().symbol;
    }

    function decimals() external virtual view returns (uint8) {
        return GammaPoolStorage.store().decimals;
    }

    function totalSupply() public virtual view returns (uint256) {
        return GammaPoolStorage.store().totalSupply;
    }

    function balanceOf(address account) external virtual view returns (uint256) {
        return GammaPoolStorage.store().balanceOf[account];
    }

    function allowance(address owner, address spender) external virtual view returns (uint256) {
        return GammaPoolStorage.store().allowance[owner][spender];
    }

    function _transfer(GammaPoolStorage.Store storage store, address from, address to, uint value) internal virtual {
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
        GammaPoolStorage.store().allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external virtual returns (bool) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _transfer(store, msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external virtual returns (bool) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
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
