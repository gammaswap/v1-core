// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCFMM is ERC20 {

    address public token0;
    address public token1;
    uint112 public reserves0;
    uint112 public reserves1;
    uint256 public invariant;

    constructor(address _token0, address _token1, string memory name, string memory symbol) ERC20(name, symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    function sync() public virtual {
        reserves0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserves1 = uint112(IERC20(token1).balanceOf(address(this)));
    }

    function getReserves() public virtual view returns(uint112, uint112, uint32) {
        return(reserves0, reserves1, 0);
    }

    function trade(uint256 _invariant) public virtual {
        invariant += _invariant;
    }

    function convertSharesToInvariant(uint256 shares) public virtual view returns(uint256) {
        uint256 _totalSupply = totalSupply();
        return _totalSupply == 0 ? shares : invariant * shares / _totalSupply;
    }

    function mint(uint256 shares, address to) public virtual {
        invariant += convertSharesToInvariant(shares);
        _mint(to, shares);
        sync();
    }

    function burn(uint256 shares, address to) public virtual {
        uint256 _totalSupply = totalSupply();
        require(_totalSupply > 0);
        invariant -= invariant * shares / _totalSupply;
        _burn(to, shares);
        sync();
    }
}
