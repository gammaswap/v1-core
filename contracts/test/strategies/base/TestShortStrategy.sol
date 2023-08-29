// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./TestBaseShortStrategy.sol";

contract TestShortStrategy is TestBaseShortStrategy {

    function _deposit(uint256, address) external override pure returns (uint256){
        return 0;
    }

    function _mint(uint256, address) external override pure returns (uint256){
        return 0;
    }

    function _withdraw(uint256, address, address) external override pure returns (uint256){
        return 0;
    }

    function _redeem(uint256, address, address) external override pure returns (uint256){
        return 0;
    }

    function _sync() external override virtual {
    }
}
