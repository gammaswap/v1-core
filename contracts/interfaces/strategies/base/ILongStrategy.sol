// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ILongStrategy {

    event LoanUpdated(uint256 indexed tokenId, uint256[] tokensHeld, uint256 heldLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external virtual returns(uint256[] memory refund);
    function _liquidateWithLP(uint256 tokenId) external virtual returns(uint256[] memory refund);
    function _getCFMMPrice(address cfmm, uint256 factor) external view returns(uint256);
    function _increaseCollateral(uint256 tokenId) external returns(uint256[] memory);
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint256[] memory tokensHeld);
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);
    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256[] memory amounts);
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory tokensHeld);
}
