// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseStrategy.sol";

interface IBaseLongStrategy is IBaseStrategy {
    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
}
