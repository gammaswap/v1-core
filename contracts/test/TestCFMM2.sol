// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./TestCFMM.sol";

contract TestCFMM2 is TestCFMM {
    constructor(address _token0, address _token1, string memory name, string memory symbol)
        TestCFMM(_token0, _token1, name, symbol) {
    }

    function withdrawReserves(uint256 shares) public virtual returns(uint128[] memory reserves) {
        uint256 _totalSupply = totalSupply();
        reserves = new uint128[](2);
        reserves[0] = uint128(reserves0 * shares / _totalSupply);
        reserves[1] = uint128(reserves1 * shares / _totalSupply);
        IERC20(token0).transfer(msg.sender, reserves[0]);
        IERC20(token1).transfer(msg.sender, reserves[1]);
        burn(shares, msg.sender);
    }
}
