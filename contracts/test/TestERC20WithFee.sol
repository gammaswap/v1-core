// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20WithFee is ERC20 {

    mapping(address => uint256) public _balances;
    uint256 public _totalSupply;
    address public owner;
    uint256 public fee;

    constructor(string memory name_, string memory symbol_, uint256 fee_) ERC20(name_, symbol_) {
        owner = msg.sender;
        fee = fee_;
        _mint(msg.sender, 100000 * 1e18);
    }

    function setFee(uint256 fee_) public virtual {
        fee = fee_;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        uint256 feeAmt = amount * fee / 1e18;
        amount = amount - feeAmt;
        _balances[to] += amount;
        _balances[owner] += feeAmt;

        emit Transfer(from, to, amount);
        emit Transfer(from, owner, feeAmt);

        _afterTokenTransfer(from, to, amount);
    }
}
