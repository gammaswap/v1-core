// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../storage/AppStorage.sol";

abstract contract GammaPoolERC20 is AppStorage {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ERC20Transfer();
    error ERC20Allowance();

    string public constant name = 'GammaSwap V1';
    string public constant symbol = 'GAMA-V1';
    uint8 public constant decimals = 18;

    function totalSupply() public virtual view returns (uint256) {
        return s.totalSupply;
    }

    function balanceOf(address account) external virtual view returns (uint256) {
        return s.balanceOf[account];
    }

    function allowance(address owner, address spender) external virtual view returns (uint256) {
        return s.allowance[owner][spender];
    }

    function _transfer(address from, address to, uint value) internal virtual {
        uint256 currentBalance = s.balanceOf[from];
        if(currentBalance < value) {
            revert ERC20Transfer();
        }
        unchecked{
            s.balanceOf[from] = currentBalance - value;
        }
        s.balanceOf[to] = s.balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external virtual returns (bool) {
        s.allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external virtual returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external virtual returns (bool) {
        uint256 currentAllowance = s.allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if(currentAllowance < value) {
                revert ERC20Allowance();
            }
            unchecked {
                s.allowance[from][msg.sender] = currentAllowance - value;
            }
        }
        _transfer(from, to, value);
        return true;
    }

}
