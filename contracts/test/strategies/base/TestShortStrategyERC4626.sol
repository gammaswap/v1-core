// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../strategies/ShortStrategyERC4626.sol";
import "./TestBaseShortStrategy.sol";

contract TestShortStrategyERC4626 is TestBaseShortStrategy, ShortStrategyERC4626 {

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex, uint256 utilizationRate) internal override(BaseStrategy, TestBaseShortStrategy) virtual {
    }

    function _sync() external override virtual {
    }
}
