// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20b is ERC20 {

    address public owner;
    uint8 public _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        owner = msg.sender;
        _decimals = decimals_;
        _mint(msg.sender, 100000 * (1e18));
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }
}
