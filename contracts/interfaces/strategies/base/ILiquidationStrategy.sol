// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ILiquidationStrategy {

    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external virtual returns(uint256[] memory refund);
    function _liquidateWithLP(uint256 tokenId) external virtual returns(uint256[] memory refund);
}
